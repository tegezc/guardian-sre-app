"""
API Entry Point - FastAPI Server
This module acts as the bridge between the Flutter mobile client and the Gemini Live API.
It handles WebSocket connections for real-time bidirectional audio streaming.
"""

import os
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from dotenv import load_dotenv
from src.agents.stream_handler import GeminiLiveAgent

# Load environment variables from .env file
load_dotenv()

app = FastAPI(title="The Guardian SRE - Gemini Live Backend")

@app.get("/")
async def health_check():
    """
    Standard health check endpoint for Cloud Run.
    """
    return {"status": "online", "agent": "The Guardian SRE"}

@app.websocket("/ws/live")
async def websocket_endpoint(websocket: WebSocket):
    """
    Main WebSocket handler for real-time audio and metadata.
    """
    await websocket.accept()
    print("Client connected to SRE Voice Stream")
    
    agent = GeminiLiveAgent()
    
    try:
        # We start the Gemini session and bridge it with the client WebSocket
        # In a full implementation, we would pass the websocket instance
        # to the agent to forward audio bytes and UI metadata.
        await agent.run_session()
        
    except WebSocketDisconnect:
        print("Client disconnected from SRE Voice Stream")
    except Exception as e:
        print(f"Unexpected error in stream: {e}")
    finally:
        if not websocket.client_state.name == "DISCONNECTED":
            await websocket.close()

if __name__ == "__main__":
    import uvicorn
    # Use port 8080 as required by Cloud Run default configuration
    uvicorn.run(app, host="0.0.0.0", port=8080)
