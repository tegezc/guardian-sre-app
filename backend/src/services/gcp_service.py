import requests
from google.cloud import logging as cloud_logging

# THE SERVICE REGISTRY: Ganti URL di bawah dengan URL Cloud Run asli Anda
SERVICE_REGISTRY = {
    "locasentiment-api": "https://locasentiment-api-102863217534.asia-southeast2.run.app/",
    "umkm-go-ai-api": "https://umkm-go-ai-api-102863217534.asia-southeast1.run.app/",
}

class GCPService:
    def __init__(self, project_id):
        self.project_id = project_id
        try:
            self.logging_client = cloud_logging.Client(project=project_id)
            self.has_gcp_access = True
            print(f"✅ REAL GCP Connected: Project {project_id}")
        except Exception as e:
            print(f"⚠️ GCP Auth Error: {e}")
            self.has_gcp_access = False

    def check_cloud_run_status(self, service_name: str) -> dict:
        if not self.has_gcp_access:
            return {"error": "GCP credentials not found."}

        try:
            # Memastikan nama layanan ditulis huruf kecil agar tidak miss-match
            safe_service_name = service_name.lower()
            filter_str = f'resource.type="cloud_run_revision" AND resource.labels.service_name="{safe_service_name}" AND severity>=WARNING'

            entries = list(self.logging_client.list_entries(filter_=filter_str, max_results=3))

            if not entries:
                return {
                    "service": safe_service_name,
                    "status": "HEALTHY / SCALED TO ZERO",
                    "message": "Real Google Cloud logs checked. No errors found in the last hour. The service is dormant (scaled to zero)."
                }

            error_details = [entry.payload for entry in entries if entry.payload]

            return {
                "service": safe_service_name,
                "status": "DEGRADED",
                "active_errors": len(entries),
                "latest_error_logs": error_details,
                "message": "WARNING: Found recent error logs in Google Cloud."
            }
        except Exception as e:
            return {"error": str(e)}

    # CRITICAL FIX: Parameter sekarang adalah 'service_name', bukan 'service_url'
    def wake_up_service(self, service_name: str) -> dict:
        """Tool SRE untuk membangunkan layanan hanya dengan menyebut namanya"""
        safe_service_name = service_name.lower()
        service_url = SERVICE_REGISTRY.get(safe_service_name)
        
        if not service_url:
            available_services = ", ".join(SERVICE_REGISTRY.keys())
            return {
                "error": f"Layanan '{safe_service_name}' tidak terdaftar di buku alamat SRE. Layanan yang tersedia hanya: {available_services}"
            }

        try:
            response = requests.get(service_url, timeout=15)
            latency_ms = round(response.elapsed.total_seconds() * 1000, 2)
            
            return {
                "action": "Wake Up Ping (Cold Start)",
                "target_service": safe_service_name,
                "http_status_code": response.status_code,
                "cold_start_latency_ms": latency_ms,
                "message": f"Service {safe_service_name} successfully awakened. Cold start latency: {latency_ms} ms."
            }
        except Exception as e:
            return {"error": f"Failed to wake up {safe_service_name}: {str(e)}"}