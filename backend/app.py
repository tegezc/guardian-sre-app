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

log = logging.getLogger('werkzeug')
log.setLevel(logging.CRITICAL)  ## Only show critical/fatal level errors

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

gcp_service = GCPService(project_id=PROJECT_ID, socketio=socketio)

class SessionBridge:
    def __init__(self, loop):
        self.loop = loop
        self.queue = asyncio.Queue(maxsize=1000)

    def put_nowait(self, item):
        if not self.loop.is_closed():
            try:
                self.loop.call_soon_threadsafe(self.queue.put_nowait, item)
            except asyncio.QueueFull:
                try:
                    self.queue.get_nowait()
                    self.loop.call_soon_threadsafe(self.queue.put_nowait, item)
                except Exception:
                    pass

async def run_live_session(session_id, sid):
    loop = asyncio.get_running_loop()
    bridge = SessionBridge(loop)
    bridges[session_id] = bridge

    client = genai.Client(vertexai=True, project=PROJECT_ID, location="us-central1")
    
    config = types.LiveConnectConfig(
        response_modalities=["AUDIO"],
        system_instruction=types.Content(
            parts=[types.Part(text="You are 'The Guardian', an SRE Voice Assistant. You MUST ALWAYS speak your responses aloud. The services you manage are: locasentiment-api, and umkm-go-ai-api. Keep your SRE reports concise and natural.")]
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
                # WATER TANK (BUFFER): To prevent sending odd/corrupted packets to Gemini
                audio_buffer = bytearray()
                CHUNK_SIZE = 4096  # Definitely even size (4KB). Perfect for 16-bit PCM.

                while live_sessions.get(session_id, {}).get("active"):
                    try:
                        item = await asyncio.wait_for(bridge.queue.get(), timeout=0.5)
                        
                        if item["type"] == "stop":
                            # Drain remaining water in the tank before closing
                            if len(audio_buffer) % 2 != 0:
                                audio_buffer = audio_buffer[:-1] # Discard the last 1 byte to make it even
                            if len(audio_buffer) > 0:
                                await session.send_realtime_input(
                                    audio=types.Blob(mime_type="audio/pcm;rate=16000", data=bytes(audio_buffer))
                                )
                            break
                            
                        elif item["type"] == "audio":
                            # Store water (bytes) from Flutter to the tank
                            audio_buffer.extend(item["data"])
                            
                            # If the tank is full (>= 4KB), print even blocks then send!
                            while len(audio_buffer) >= CHUNK_SIZE:
                                chunk_to_send = bytes(audio_buffer[:CHUNK_SIZE])
                                del audio_buffer[:CHUNK_SIZE] # Delete what has been sent
                                
                                await session.send_realtime_input(
                                    audio=types.Blob(mime_type="audio/pcm;rate=16000", data=chunk_to_send)
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
                            if not live_sessions.get(session_id, {}).get("active"):
                                break
                                
                            current_sid = live_sessions[session_id]["sid"]
                            
                            if response.server_content and response.server_content.model_turn:
                                for part in response.server_content.model_turn.parts:
                                    if part.inline_data:
                                        audio_b64 = base64.b64encode(part.inline_data.data).decode("utf-8")
                                        socketio.emit("audio_response", {"audio": audio_b64}, room=current_sid)
                                    if part.text:
                                        logging.info(f"🤖 Guardian: {part.text}")

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
                                        result = {
                                            "status": "success", 
                                            "data": str(raw_result),
                                            "instruction": "Speak the result naturally to the user."
                                        }
                                    
                                    batch_responses.append(
                                        types.FunctionResponse(id=call.id, name=call.name, response=result)
                                    )
                                    
                                if batch_responses:
                                    bridges[session_id].put_nowait({"type": "tool_response", "data": batch_responses})

                    except asyncio.CancelledError:
                        break
                    except Exception as e:
                        logging.error(f"Receiver Loop Error: {e}")
                        break

            await asyncio.gather(sender_loop(), receiver_loop())

    except Exception as e:
        logging.error(f"Session Error: {e}")
    finally:
        if session_id in bridges: del bridges[session_id]
        if session_id in live_sessions: del live_sessions[session_id]

def start_background_loop(session_id, sid):
    # 3. FIX: Use asyncio.run so that memory cleanup (aclose) is handled automatically by Python
    try:
        asyncio.run(run_live_session(session_id, sid))
    except Exception as e:
        logging.error(f"Background thread ended: {e}")


@socketio.on("connect")
def handle_connect():
    logging.info(f"Client connected: {request.sid}")

@socketio.on("start_session")
def handle_start_session():
    session_id = request.sid
    threading.Thread(target=start_background_loop, args=(session_id, request.sid), daemon=True).start()

@socketio.on("send_audio")
def handle_audio(data):
    session_id = request.sid
    if session_id in bridges:
        try:
            audio_bytes = base64.b64decode(data.get("audio"))
            bridges[session_id].put_nowait({"type": "audio", "data": audio_bytes})
        except Exception as e:
            pass

@socketio.on("disconnect")
def handle_disconnect():
    session_id = request.sid
    if session_id in live_sessions:
        live_sessions[session_id]["active"] = False
        # 4. FIX: Inject death signal so sender_loop doesn't hang (blocking)
        if session_id in bridges:
            bridges[session_id].put_nowait({"type": "stop"})
            
    logging.info(f"Client disconnected: {request.sid}")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    socketio.run(app, host="0.0.0.0", port=port, debug=False, allow_unsafe_werkzeug=True)