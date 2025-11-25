"""
Load test for CarePath Chat API (service_chat).

Endpoints tested:
- GET /health
- POST /triage

Note: The /triage endpoint uses actual LLM inference which can take 6-7 minutes
on CPU. High RPS tests (100, 1000) will likely result in timeouts or queue buildup.
This is expected and reflects real-world infrastructure capacity.

Usage:
    locust -f chat_api_locustfile.py --host=http://localhost:8002
"""

import random
from locust import HttpUser, task, between


# Sample patient MRNs for testing (from synthetic data)
SAMPLE_MRNS = [
    "P000123",
    "P000001",
    "P000002",
    "P000003",
    "P000004",
    "P000005",
]

# Sample patient queries for realistic testing
SAMPLE_QUERIES = [
    "What are my current medications?",
    "When was my last appointment?",
    "Can you summarize my recent lab results?",
    "What diagnoses do I have?",
    "Tell me about my recent visits",
    "What should I know about my health history?",
    "Do I have any upcoming appointments?",
    "What procedures have I had?",
    "Can you explain my latest test results?",
    "What is my treatment plan?",
]


class ChatApiUser(HttpUser):
    """Simulates a user making requests to the Chat API."""

    # Wait between 1 and 5 seconds between tasks
    # Longer wait time due to LLM inference duration
    wait_time = between(1, 5)

    # Extended timeout for LLM inference (10 minutes)
    # Default Locust timeout is 60 seconds which is too short for LLM
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Set longer timeout for HTTP client
        self.client.timeout = 600  # 10 minutes

    def on_start(self):
        """Called when a user starts. Verify API is healthy."""
        response = self.client.get("/health")
        if response.status_code != 200:
            raise Exception(f"API health check failed: {response.status_code}")

    @task(1)
    def health_check(self):
        """Test basic health endpoint."""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")

    @task(10)
    def triage_query(self):
        """Test triage endpoint with patient query - main Chat API endpoint."""
        mrn = random.choice(SAMPLE_MRNS)
        query = random.choice(SAMPLE_QUERIES)

        payload = {
            "patient_mrn": mrn,
            "query": query,
        }

        with self.client.post(
            "/triage",
            json=payload,
            name="/triage",
            catch_response=True,
            timeout=600,  # 10 minute timeout for LLM inference
        ) as response:
            if response.status_code == 200:
                data = response.json()
                # Verify expected response structure
                required_fields = ["response", "trace_id", "patient_mrn"]
                missing_fields = [f for f in required_fields if f not in data]
                if missing_fields:
                    response.failure(f"Missing fields: {missing_fields}")
                elif data.get("patient_mrn") != mrn:
                    response.failure(f"MRN mismatch: expected {mrn}, got {data.get('patient_mrn')}")
                elif not data.get("response"):
                    response.failure("Empty response from LLM")
                else:
                    response.success()
            elif response.status_code == 404:
                # Patient not found - acceptable for test MRNs
                response.success()
            elif response.status_code == 504:
                # Gateway timeout - expected for long LLM inference
                response.failure("Gateway timeout (LLM inference too slow)")
            else:
                response.failure(f"Triage failed: {response.status_code} - {response.text[:200]}")


class ChatApiLightUser(HttpUser):
    """
    Lighter load test user that only tests health endpoint.
    Use this for testing infrastructure without LLM overhead.
    """

    wait_time = between(0.5, 1)
    weight = 0  # Disabled by default, set weight > 0 to enable

    @task
    def health_check(self):
        """Test basic health endpoint only."""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")
