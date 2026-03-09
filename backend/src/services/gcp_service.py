import random
from datetime import datetime, timezone

class GCPService:
    """
    Simulates Google Cloud Platform infrastructure interactions.
    For a production environment, replace these mock returns with 
    actual calls to google-cloud-monitoring or google-cloud-logging SDKs.
    """

    def __init__(self, project_id: str):
        self.project_id = project_id

    def check_service_health(self, service_name: str, environment: str) -> dict:
        """
        Simulates checking the health of a specific GCP service.
        """
        print(f"[GCP Mock] Checking health for {service_name} in {environment}...")

        # Simulate a realistic scenario: 'payment-api' is currently struggling
        if service_name.lower() == "payment-api":
            status = "DEGRADED"
            uptime = "98.5%"
            active_alerts = 2
        else:
            status = "HEALTHY"
            uptime = "99.99%"
            active_alerts = 0

        return {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "service": service_name,
            "environment": environment,
            "status": status,
            "uptime_30d": uptime,
            "active_alerts": active_alerts,
            "message": f"Service is currently {status}."
        }

    def get_infrastructure_metrics(self, service_name: str, metric_type: str, time_window_minutes: int = 15) -> dict:
        """
        Simulates retrieving specific performance metrics for a service.
        """
        print(f"[GCP Mock] Fetching {metric_type} for {service_name} over last {time_window_minutes} mins...")

        metric_value = "Unknown"
        unit = ""

        # Generate realistic mock data based on the requested metric
        if metric_type == "latency":
            # High latency if it's payment-api, normal otherwise
            base_latency = 850 if service_name.lower() == "payment-api" else 45
            variance = random.randint(-10, 50)
            metric_value = f"{base_latency + variance}"
            unit = "ms"
        elif metric_type == "cpu_usage":
            metric_value = f"{random.randint(40, 95)}"
            unit = "%"
        elif metric_type == "error_rate":
            metric_value = "5.2" if service_name.lower() == "payment-api" else "0.01"
            unit = "%"
        elif metric_type == "memory_usage":
            metric_value = f"{random.randint(60, 85)}"
            unit = "%"

        return {
            "service": service_name,
            "metric": metric_type,
            "time_window": f"{time_window_minutes} minutes",
            "average_value": f"{metric_value}{unit}",
            "trend": "increasing" if int(float(metric_value)) > 80 else "stable"
        }