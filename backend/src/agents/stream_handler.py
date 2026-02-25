"""
Gemini Live Stream Handler
This module manages the bidirectional streaming session with Gemini Live API.
It handles real-time audio, interruption (barge-in), and function execution.
"""

import os
from google import genai
from google.genai import types
from src.services.gcp_service import GCPService
from src.tools.sre_tools import get_sre_tools_spec

class GeminiLiveAgent:
    def __init__(self):
        """
        Initializes the Gemini client and SRE context.
        """
        self.client = genai.Client(
            api_key=os.getenv("GEMINI_API_KEY"),
            http_options={'api_version': 'v1alpha'}
        )
        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        self.gcp_service = GCPService(self.project_id)
        self.model_id = "gemini-2.0-flash-exp" # Recommended for Live API low latency

    async def run_session(self):
        """
        Main loop for the Live API session.
        Handles the bidirectional stream.
        """
        # System Instruction for the SRE Persona
        config = {
            "system_instruction": (
                "You are 'The Guardian', a professional SRE Voice Assistant. "
                "Your tone is calm, analytical, and direct. You monitor Google Cloud infrastructure. "
                "Use the provided tools to get real-time data. If an incident is detected, "
                "be proactive. Handle interruptions gracefully."
            ),
            "tools": [{"function_declarations": get_sre_tools_spec()}]
        }

        async with self.client.aio.live.connect(model=self.model_id, config=config) as session:
            print("Connected to Gemini Live API...")
            
            # This task handles incoming messages from Gemini (Audio or Tool Calls)
            async for message in session:
                await self._handle_incoming_message(session, message)

    async def _handle_incoming_message(self, session, message):
        """
        Processes messages from Gemini: can be audio frames or function calls.
        """
        # 1. Handle Tool Calls (Function Calling)
        if message.tool_call:
            for call in message.tool_call.function_calls:
                print(f"Executing tool: {call.name} with args: {call.args}")
                
                # Dynamic dispatch to GCP Service
                if hasattr(self.gcp_service, call.name):
                    method = getattr(self.gcp_service, call.name)
                    result = method(**call.args)
                    
                    # Send result back to Gemini for grounding
                    await session.send(
                        types.FunctionResponse(
                            name=call.name,
                            response=result,
                        )
                    )

        # 2. Handle Audio Output (sent to Flutter/Client)
        if message.server_content and message.server_content.model_turn:
            parts = message.server_content.model_turn.parts
            for part in parts:
                if part.inline_data:
                    # In a real app, send these bytes to the Flutter frontend via WebSocket
                    pass