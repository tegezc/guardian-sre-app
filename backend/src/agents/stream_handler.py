"""
Gemini Live Stream Handler - Final Vertex AI Fix
Cleaned from API Key conflicts and forced to correct regional endpoint.
"""

import os
import asyncio
from fastapi import WebSocket, WebSocketDisconnect
from google import genai
from google.genai import types
from src.services.gcp_service import GCPService
from src.tools.sre_tools import get_sre_tools_spec

class GeminiLiveAgent:
    def __init__(self):
        self.client = genai.Client(
            vertexai=True,
            project=os.getenv("GOOGLE_CLOUD_PROJECT"),
            location="us-central1"
        )
        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        self.gcp_service = GCPService(self.project_id)
        self.model_id = "gemini-live-2.5-flash-native-audio"

    async def run_session(self, websocket: WebSocket):
        """
        Main loop handling bi-directional communication between Flutter and Gemini.
        """
        config = {
            "system_instruction": (
                "You are 'The Guardian', a professional SRE Voice Assistant. "
                "Analyze Google Cloud infrastructure metrics."
            ),
            "tools": [{"function_declarations": get_sre_tools_spec()}]
        }

        # Buka koneksi ke Google Gemini Live
        async with self.client.aio.live.connect(model=self.model_id, config=config) as gemini_session:
            print("🚀 STATUS: Guardian SRE is Online & Listening!")

            try:
                # Task 1: Menerima suara dari Flutter dan mengirimkannya ke Gemini
                client_to_gemini_task = asyncio.create_task(
                    self._receive_from_client(websocket, gemini_session)
                )

                # Task 2: Menerima respons dari Gemini dan mengelolanya
                gemini_to_client_task = asyncio.create_task(
                    self._receive_from_gemini(gemini_session, websocket)
                )

                # Jalankan kedua task secara bersamaan sampai salah satu terputus
                await asyncio.gather(client_to_gemini_task, gemini_to_client_task)

            except asyncio.CancelledError:
                print("⚠️ Stream cancelled.")
            except Exception as e:
                print(f"❌ Stream error: {e}")
            finally:
                # Pastikan task dibatalkan jika terjadi error
                client_to_gemini_task.cancel()
                gemini_to_client_task.cancel()

    async def _receive_from_client(self, websocket: WebSocket, gemini_session):
        """
        Task 1: Continuously read raw audio bytes from Flutter and stream them to Gemini.
        Uses the strict 'LiveClientRealtimeInput' type required by the new google-genai SDK.
        """
        try:
            while True:
                # Wait for the 2560 bytes audio chunk sent by Flutter
                audio_bytes = await websocket.receive_bytes()

                # Send the audio bytes using the strictly typed SDK classes
                await gemini_session.send(
                    input=types.LiveClientRealtimeInput(
                        media_chunks=[
                            types.Blob(
                                mime_type="audio/pcm;rate=16000",
                                data=audio_bytes
                            )
                        ]
                    )
                )
        except WebSocketDisconnect:
            print("Frontend client stopped sending audio.")
        except Exception as e:
            print(f"Error receiving from client: {e}")
    async def _receive_from_gemini(self, gemini_session, websocket: WebSocket):
        """
        Task 2: Continuously listen for Gemini's responses and process them.
        """
        try:
            async for message in gemini_session.receive():
                if message:
                    await self._handle_incoming_message(gemini_session, message, websocket)
        except Exception as e:
            print(f"Error receiving from Gemini: {e}")

    async def _handle_incoming_message(self, session, message, websocket: WebSocket):
        """
        Processes messages from Gemini: handles audio/text responses and tool calls.
        """
        # 1. Handle Regular Model Responses (Text and Audio from Gemini)
        if message.server_content is not None:
            model_turn = message.server_content.model_turn
            if model_turn is not None:
                for part in model_turn.parts:
                    # Print the text transcript to our FastAPI terminal
                    if part.text:
                        print(f"🤖 Guardian: {part.text}")

                    # Forward the raw audio bytes back to the Flutter UI
                    if part.inline_data:
                        await websocket.send_bytes(part.inline_data.data)

        # 2. Handle Tool Calls (Function Calling / SRE Actions)
        if message.tool_call is not None:
            for call in message.tool_call.function_calls:
                print(f"🛠️ Executing SRE Tool: {call.name}")

                if hasattr(self.gcp_service, call.name):
                    method = getattr(self.gcp_service, call.name)
                    # Execute the tool (mocked or real GCP call)
                    result = method()

                    # Use strict typing for Tool Responses as well
                    await session.send(
                        input=types.LiveClientToolResponse(
                            function_responses=[
                                types.FunctionResponse(
                                    name=call.name,
                                    response={"result": result}
                                )
                            ]
                        )
                    )
