"""
Gemini Live Stream Handler - Final Vertex AI Fix
Cleaned from API Key conflicts and forced to correct regional endpoint.
"""
import os
from google import genai
from google.genai import types
from src.services.gcp_service import GCPService
from src.tools.sre_tools import get_sre_tools_spec

class GeminiLiveAgent:
    def __init__(self):
        # 1. Pastikan HANYA menggunakan Vertex AI mode.
        # Jangan masukkan api_key di sini. SDK akan otomatis menggunakan ADC.
        self.client = genai.Client(
            vertexai=True,
            project=os.getenv("GOOGLE_CLOUD_PROJECT"),
            location="us-central1" # Region us-central1 adalah syarat utama Live API saat ini
        )

        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        self.gcp_service = GCPService(self.project_id)

        # 2. Gunakan ID model yang sudah terbukti ada di list_models Anda tadi
        # self.model_id = "gemini-live-2.5-flash-native-audio"
        self.model_id = "gemini-live-2.5-flash-native-audio"

    async def run_session(self):
        """
        Main loop for the Live API session.
        Explicitly receiving messages using the receive() method.
        """
        config = {
            "system_instruction": (
                "You are 'The Guardian', a professional SRE Voice Assistant. "
                "Analyze Google Cloud infrastructure metrics."
            ),
            "tools": [{"function_declarations": get_sre_tools_spec()}]
        }

        async with self.client.aio.live.connect(model=self.model_id, config=config) as session:
            print("🚀 STATUS: Guardian SRE is Online & Listening!")

            try:
                # Perbaikan Utama: session.receive() mengembalikan async generator
                # Kita harus menggunakan 'async for' untuk mengonsumsi setiap pesan di dalamnya
                async for message in session.receive():
                    if message:
                        await self._handle_incoming_message(session, message)
            except Exception as e:
                print(f"❌ Stream error: {e}")

    async def _handle_incoming_message(self, session, message):
        """
        Processes messages from Gemini: tool calls or model turns.
        """
        # 1. Handle Tool Calls (Function Calling)
        if message.tool_call:
            for call in message.tool_call.function_calls:
                print(f" Executing: {call.name}")

                if hasattr(self.gcp_service, call.name):
                    method = getattr(self.gcp_service, call.name)
                    result = method(**call.args)
                    print(dir(types))
                    await session.send(
                        types.LiveClientMessage(
                            tool_response={
                                "name": call.name,
                                "response": result
                            }
                        )
                    )