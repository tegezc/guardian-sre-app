import requests
from google.cloud import logging as cloud_logging
import logging

# THE SERVICE REGISTRY
SERVICE_REGISTRY = {
    "locasentiment-api": "https://locasentiment-api-102863217534.asia-southeast2.run.app/",
    "umkm-go-ai-api": "https://umkm-go-ai-api-102863217534.asia-southeast1.run.app/",
}

class GCPService:
    # 🌟 CHANGE 1: Adding socketio parameter in initialization
    def __init__(self, project_id, socketio=None):
        self.project_id = project_id
        self.socketio = socketio  # Save socketio object in class memory
        try:
            self.logging_client = cloud_logging.Client(project=project_id)
            self.has_gcp_access = True
            logging.info(f"✅ REAL GCP Connected: Project {project_id}")
        except Exception as e:
            logging.error(f"⚠️ GCP Auth Error: {e}")
            self.has_gcp_access = False

    def check_cloud_run_status(self, service_name: str) -> dict:
        if not self.has_gcp_access:
            return {"error": "GCP credentials not found."}

        try:
            # Ensuring the service name is written in lowercase to avoid mismatch
            safe_service_name = service_name.lower()
            filter_str = f'resource.type="cloud_run_revision" AND resource.labels.service_name="{safe_service_name}" AND severity>=WARNING'

            entries = list(self.logging_client.list_entries(filter_=filter_str, max_results=3))
            logging.info(f"🚀 [SRE HUD] PREPARING METRICS FOR SERVICE: {safe_service_name}")

            if not entries:
                # ==========================================
                # 📡 THE BULLETPROOF EMIT (DORMANT)
                # ==========================================
                if self.socketio:
                    try:
                        self.socketio.emit('ui_update', {
                            "service": safe_service_name,
                            "health": "DORMANT (SCALED TO ZERO)",
                            "errors": "0 Errors (1h)",
                            "action_latency": None
                        })
                        logging.info("✅ [SRE HUD] SUCCESSFULLY FIRED TO FLUTTER!")
                    except Exception as emit_err:
                        logging.error(f"❌ [SRE HUD] ERROR SOCKET: {emit_err}")
                else:
                    logging.warning("⚠️ [SRE HUD] SocketIO object not found!")
                # ==========================================
                
                return {
                    "service": safe_service_name,
                    "status": "HEALTHY / SCALED TO ZERO",
                    "message": "Real Google Cloud logs checked. No errors found in the last hour. The service is dormant (scaled to zero)."
                }

            error_details = [entry.payload for entry in entries if entry.payload]

            # ==========================================
            # 📡 THE BULLETPROOF EMIT (CRITICAL)
            # ==========================================
            if self.socketio:
                try:
                    self.socketio.emit('ui_update', {
                        "service": safe_service_name,
                        "health": "CRITICAL",
                        "errors": f"{len(entries)} Errors (1h)",
                        "action_latency": None
                    })
                    logging.info("✅ [SRE HUD] SUCCESSFULLY FIRED TO FLUTTER!")
                except Exception as emit_err:
                    logging.error(f"❌ [SRE HUD] ERROR SOCKET: {emit_err}")
            else:
                logging.warning("⚠️ [SRE HUD] SocketIO object not found!")
            # ==========================================
            
            return {
                "service": safe_service_name,
                "status": "DEGRADED",
                "active_errors": len(entries),
                "latest_error_logs": error_details,
                "message": "WARNING: Found recent error logs in Google Cloud."
            }
        except Exception as e:
            return {"error": str(e)}

    def wake_up_service(self, service_name: str) -> dict:
        """SRE tool to wake up the service just by mentioning its name"""
        safe_service_name = service_name.lower()
        service_url = SERVICE_REGISTRY.get(safe_service_name)
        
        if not service_url:
            available_services = ", ".join(SERVICE_REGISTRY.keys())
            return {
                "error": f"Service '{safe_service_name}' is not registered in the SRE address book. Available services only: {available_services}"
            }

        try:
            response = requests.get(service_url, timeout=15)
            latency_ms = round(response.elapsed.total_seconds() * 1000, 2)
            
            # ==========================================
            # 📡 THE BULLETPROOF EMIT (ACTION RESULT)
            # ==========================================
            if self.socketio:
                try:
                    self.socketio.emit('ui_update', {
                        "service": safe_service_name,
                        "health": "AWAKE & HEALTHY",
                        "errors": "0 Errors (1h)",
                        "action_latency": f"{latency_ms} ms"
                    })
                    logging.info("✅ [SRE HUD] SUCCESSFULLY FIRED TO FLUTTER!")
                except Exception as emit_err:
                    logging.error(f"❌ [SRE HUD] ERROR SOCKET: {emit_err}")
            else:
                logging.warning("⚠️ [SRE HUD] SocketIO object not found!")
            # ==========================================
            
            return {
                "action": "Wake Up Ping (Cold Start)",
                "target_service": safe_service_name,
                "http_status_code": response.status_code,
                "cold_start_latency_ms": latency_ms,
                "message": f"Service {safe_service_name} successfully awakened. Cold start latency: {latency_ms} ms."
            }
        except Exception as e:
            return {"error": f"Failed to wake up {safe_service_name}: {str(e)}"}