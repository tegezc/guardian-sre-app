from google.genai import types

def get_sre_tools_spec() -> list:
    """
    Returns a list of Tool specifications (Function Declarations) using STRICT TYPING.
    """
    return [
        types.FunctionDeclaration(
            name="check_service_health",
            description="Checks the current health status and uptime of a specific Google Cloud service.",
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "service_name": types.Schema(
                        type=types.Type.STRING,
                        description="The exact name of the service, e.g., 'payment-api', 'frontend-web'."
                    ),
                    "environment": types.Schema(
                        type=types.Type.STRING,
                        description="The deployment environment, typically 'production', 'staging', or 'development'."
                    )
                },
                required=["service_name", "environment"]
            )
        ),
        types.FunctionDeclaration(
            name="get_infrastructure_metrics",
            description="Retrieves specific performance metrics for a given service over a specified time window.",
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "service_name": types.Schema(
                        type=types.Type.STRING,
                        description="The name of the service, e.g., 'payment-api'."
                    ),
                    "metric_type": types.Schema(
                        type=types.Type.STRING,
                        description="The type of metric to fetch. Allowed values: 'latency', 'cpu_usage', 'memory_usage', 'error_rate'."
                    ),
                    "time_window_minutes": types.Schema(
                        type=types.Type.INTEGER,
                        description="The time window in minutes to look back."
                    )
                },
                required=["service_name", "metric_type"]
            )
        )
    ]