import os
import asyncio
import threading
import base64
import logging
from flask import Flask, request
from flask_cors import CORS
from flask_socketio import SocketIO, emit
from google import genai
from google.genai import types

from src.services.gcp_service import GCPService
from src.tools.sre_tools import get_sre_tools_spec

# --- CONFIGURATION ---
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
app = Flask(__name__)
CORS(app)

# SocketIO with very loose ping timeout to prevent disconnections (1011)
socketio = SocketIO(
    app,
    cors_allowed_origins="*",
    async_mode="threading",
    ping_timeout=300,
    ping_interval=60
)

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
MODEL_ID = "gemini-live-2.5-flash-native-audio"

# Global State
live_sessions = {}
bridges = {}
gcp_service = GCPService(PROJECT_ID)

class SessionBridge:
    """Queue Bridge between Flask (Sync) and Gemini (Async)"""
    def __init__(self, loop):
        self.loop = loop
        self.queue = asyncio.Queue(maxsize=1000)
        self.dropped_frames = 0

    def put_nowait(self, item):
        if not self.loop.is_closed():
            try:
                self.loop.call_soon_threadsafe(self.queue.put_nowait, item)
            except asyncio.QueueFull:
                self.dropped_frames += 1
                # If buffer is full, drop oldest data (FIFO drop) to make room
                try:
                    self.queue.get_nowait()
                    self.loop.call_soon_threadsafe(self.queue.put_nowait, item)
                except Exception:
                    pass

async def run_live_session(session_id, sid):
    """Main event loop to communicate with Gemini"""
    loop = asyncio.get_event_loop()
    bridge = SessionBridge(loop)
    bridges[session_id] = bridge

    client = genai.Client(vertexai=True, project=PROJECT_ID, location="us-central1")
    
    config = types.LiveConnectConfig(
        response_modalities=["AUDIO"],
        system_instruction=types.Content(
            parts=[types.Part(text="You are 'The Guardian', an SRE Voice Assistant. You MUST ALWAYS speak your responses aloud. The services you manage are: locasentiment-api, umkm-go-ai-api. Keep your SRE reports concise and natural.")]
        ),
        tools=[types.Tool(function_declarations=get_sre_tools_spec())],
        speech_config=types.SpeechConfig(
            voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name="Aoede")
            )
        )
    )

    try:
        async with client.aio.live.connect(model=MODEL_ID, config=config) as session:
            live_sessions[session_id] = {"active": True, "sid": sid}
            socketio.emit("system_status", {"message": "Guardian SRE is Online!"}, room=sid)

            async def sender_loop():
                while live_sessions.get(session_id, {}).get("active"):
                    try:
                        item = await asyncio.wait_for(bridge.queue.get(), timeout=0.5)
                        if item["type"] == "audio":
                            await session.send_realtime_input(
                                audio=types.Blob(mime_type="audio/pcm;rate=16000", data=item["data"])
                            )
                        elif item["type"] == "tool_response":
                            await session.send_tool_response(function_responses=item["data"])
                    except asyncio.TimeoutError:
                        continue
                    except Exception as e:
                        logging.error(f"Sender Loop Error: {e}")

            async def receiver_loop():
                while live_sessions.get(session_id, {}).get("active"):
                    try:
                        async for response in session.receive():
                            current_sid = live_sessions[session_id]["sid"]
                            
                            # 1. Forward Audio to Flutter via SocketIO
                            if response.server_content and response.server_content.model_turn:
                                for part in response.server_content.model_turn.parts:
                                    if part.inline_data:
                                        audio_b64 = base64.b64encode(part.inline_data.data).decode("utf-8")
                                        socketio.emit("audio_response", {"audio": audio_b64}, room=current_sid)
                                    if part.text:
                                        logging.info(f"🤖 Guardian: {part.text}")

                            # 2. Handle Tool Calls
                            if response.tool_call:
                                batch_responses = []
                                for call in response.tool_call.function_calls:
                                    logging.info(f"🛠️ Executing SRE Tool: {call.name}")
                                    result = {"error": "Tool not found"}
                                    
                                    if hasattr(gcp_service, call.name):
                                        method = getattr(gcp_service, call.name)
                                        kwargs = call.args if call.args else {}
                                        if not isinstance(kwargs, dict) and hasattr(kwargs, 'to_dict'):
                                            kwargs = kwargs.to_dict()
                                        
                                        raw_result = method(**kwargs)
                                        result = {"status": "success", "data": str(raw_result),"instruction": "Speak the result naturally to the user."}
                                        logging.info("✅ Tool execution success.")
                                    
                                    batch_responses.append(
                                        types.FunctionResponse(id=call.id, name=call.name, response=result)
                                    )

                                    # Insert result into queue to be sent by sender_loop
                                    # tool_resp = [types.FunctionResponse(id=call.id, name=call.name, response=result)]
                                if batch_responses:
                                    bridges[session_id].put_nowait({"type": "tool_response", "data": batch_responses})
                                    logging.info(f"🚀 BATCH Tool Responses ({len(batch_responses)} tools) queued for sending!")

                    except Exception as e:
                        logging.error(f"Receiver Loop Error: {e}")
                        break

            # Run both loops in parallel
            await asyncio.gather(sender_loop(), receiver_loop())

    except Exception as e:
        logging.error(f"Session Error: {e}")
    finally:
        if session_id in bridges: del bridges[session_id]
        if session_id in live_sessions: del live_sessions[session_id]


def start_background_loop(session_id, sid):
    """Run async event loop in a separate thread"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(run_live_session(session_id, sid))
    finally:
        loop.close()


# --- SOCKET.IO EVENT HANDLERS ---
@socketio.on("connect")
def handle_connect():
    logging.info(f"Client connected: {request.sid}")

@socketio.on("start_session")
def handle_start_session():
    session_id = request.sid # Use SID as temporary Session ID
    threading.Thread(target=start_background_loop, args=(session_id, request.sid), daemon=True).start()

@socketio.on("send_audio")
def handle_audio(data):
    session_id = request.sid
    if session_id in bridges:
        try:
            # Decode audio sent in Base64 format from Flutter
            audio_bytes = base64.b64decode(data.get("audio"))
            bridges[session_id].put_nowait({"type": "audio", "data": audio_bytes})
        except Exception as e:
            logging.error(f"Audio processing error: {e}")

@socketio.on("disconnect")
def handle_disconnect():
    session_id = request.sid
    if session_id in live_sessions:
        live_sessions[session_id]["active"] = False
    logging.info(f"Client disconnected: {request.sid}")


if __name__ == "__main__":
    print("=========================================")
    print("🛡️ The Guardian SRE Backend (Socket.IO) 🛡️")
    print("=========================================")
    # Run server using SocketIO (not Uvicorn)
    socketio.run(app, host="0.0.0.0", port=8080, debug=False)