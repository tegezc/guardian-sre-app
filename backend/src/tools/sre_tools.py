from google.genai import types

def get_sre_tools_spec():
    return [
        types.FunctionDeclaration(
            name="check_cloud_run_status",
            description="Checks the real-time health and error logs of a Google Cloud Run service.",
            parameters={
                "type": "object",
                "properties": {
                    "service_name": {
                        "type": "string",
                        "description": "The exact name of the Cloud Run service (e.g., locasentiment-api, umkm-go-ai-api)"
                    }
                },
                "required": ["service_name"]
            }
        ),
        types.FunctionDeclaration(
            name="wake_up_service",
            description="Sends an HTTP ping to a dormant service to trigger a cold start using ONLY its short name.",
            parameters={
                "type": "object",
                "properties": {
                    "service_name": {
                        "type": "string",
                        "description": "The short name of the service to wake up (e.g., locasentiment-api, umkm-go-ai-api). DO NOT USE URLs."
                    }
                },
                "required": ["service_name"]
            }
        )
    ]