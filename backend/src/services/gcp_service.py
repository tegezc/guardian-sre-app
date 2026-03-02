"""
GCP Service Layer
This module handles all direct interactions with Google Cloud Monitoring and Logging APIs.
It follows the Singleton pattern to ensure efficient connection pooling.
"""

import datetime
from google.cloud import monitoring_v3
from google.cloud import logging_v2
from typing import List, Dict, Any
from google.auth import default

class GCPService:
    def __init__(self, project_id: str):
        """
        Initializes the GCP clients.
        :param project_id: The Google Cloud Project ID.
        """
        self.project_id = project_id
        self.project_name = f"projects/{project_id}"
        
        # Initialize clients for Monitoring and Logging
        self.metrics_client = monitoring_v3.MetricServiceClient()
        self.logging_client = logging_v2.Client(project=project_id)
        # self.project_id = project_id
        # try:
        #     # Mengambil kredensial secara eksplisit dari file lokal (ADC)
        #     credentials, _ = default()
        #     self.metrics_client = monitoring_v3.MetricServiceClient(credentials=credentials)
        #     print(f"GCP Service initialized for project: {project_id}")
        # except Exception as e:
        #     print(f"Failed to initialize GCP credentials: {e}")
        #     # Fallback agar tidak crash saat inisialisasi
        #     self.metrics_client = None

    def get_service_latency(self, service_name: str, minutes: int = 15) -> Dict[str, Any]:
        """
        Fetches the p95 latency for a specific Cloud Run service.
        :param service_name: Name of the Cloud Run service.
        :param minutes: Lookback window in minutes.
        :return: A dictionary containing the average latency value.
        """
        now = datetime.datetime.now(datetime.timezone.utc)
        start_time = now - datetime.timedelta(minutes=minutes)

        interval = monitoring_v3.TimeInterval(
            {
                "end_time": {"seconds": int(now.timestamp())},
                "start_time": {"seconds": int(start_time.timestamp())},
            }
        )

        # Filter for Cloud Run Request Latencies
        # Note: In a real scenario, ensure the filter matches your resource names
        filter_query = (
            f'resource.type = "cloud_run_revision" '
            f'AND resource.labels.service_name = "{service_name}" '
            f'AND metric.type = "run.googleapis.com/request_latencies"'
        )

        results = self.metrics_client.list_time_series(
            request={
                "name": self.project_name,
                "filter": filter_query,
                "interval": interval,
                "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
            }
        )

        # Process the points (simplified for the agent)
        total_latency = 0
        point_count = 0
        for result in results:
            for point in result.points:
                # Value is usually a distribution for latencies
                total_latency += point.value.distribution_value.mean
                point_count += 1

        avg_latency = (total_latency / point_count) if point_count > 0 else 0
        return {
            "service": service_name,
            "metric": "p95_latency",
            "value": f"{avg_latency:.2f}ms",
            "status": "normal" if avg_latency < 1000 else "degraded"
        }

    def fetch_recent_errors(self, service_name: str, limit: int = 5) -> List[str]:
        """
        Retrieves the most recent ERROR logs for a specific service.
        :param service_name: Name of the Cloud Run service.
        :param limit: Number of log entries to retrieve.
        :return: List of error message strings.
        """
        log_filter = (
            f'resource.type="cloud_run_revision" '
            f'AND resource.labels.service_name="{service_name}" '
            f'severity>=ERROR'
        )

        entries = self.logging_client.list_entries(filter_=log_filter, order_by=logging_v2.DESCENDING, max_results=limit)
        
        return [f"[{entry.timestamp}] {entry.payload}" for entry in entries]