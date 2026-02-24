"""
SRE Tool Definitions
This module defines the function schemas that Gemini uses to interact with Google Cloud.
These definitions are passed to the Gemini Live API to enable Tool Use (Function Calling).
"""

from typing import List, Dict, Any

def get_sre_tools_spec() -> List[Dict[str, Any]]:
    """
    Returns the list of function specifications for Gemini.
    :return: A list of tool definitions in OpenAI-compatible/Gemini format.
    """
    return [
        {
            "name": "get_service_latency",
            "description": "Get the real-time p95 latency of a specific Cloud Run service to diagnose slowness.",
            "parameters": {
                "type": "object",
                "properties": {
                    "service_name": {
                        "type": "string",
                        "description": "The name of the Cloud Run service, e.g., 'payment-gateway'."
                    },
                    "minutes": {
                        "type": "integer",
                        "description": "The lookback window in minutes. Default is 15."
                    }
                },
                "required": ["service_name"]
            }
        },
        {
            "name": "fetch_recent_errors",
            "description": "Retrieve the latest error logs from Cloud Logging to identify root causes of failures.",
            "parameters": {
                "type": "object",
                "properties": {
                    "service_name": {
                        "type": "string",
                        "description": "The name of the Cloud Run service."
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Number of error entries to fetch. Default is 5."
                    }
                },
                "required": ["service_name"]
            }
        }
    ]