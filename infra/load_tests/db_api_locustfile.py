"""
Load test for CarePath DB API (service_db_api).

Endpoints tested:
- GET /health
- GET /health/db
- GET /patients
- GET /patients/{mrn}
- GET /patients/{mrn}/summary
- GET /encounters
- GET /claims
- GET /documents

Usage:
    locust -f db_api_locustfile.py --host=http://localhost:8001
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
    "P000010",
    "P000020",
    "P000050",
    "P000100",
]


class DbApiUser(HttpUser):
    """Simulates a user making requests to the DB API."""

    # Wait between 0.5 and 2 seconds between tasks
    wait_time = between(0.5, 2)

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

    @task(1)
    def health_db_check(self):
        """Test database health endpoint."""
        with self.client.get("/health/db", catch_response=True) as response:
            if response.status_code == 200:
                data = response.json()
                if data.get("database") == "connected":
                    response.success()
                else:
                    response.failure(f"DB not connected: {data}")
            else:
                response.failure(f"DB health check failed: {response.status_code}")

    @task(3)
    def list_patients(self):
        """Test patient list endpoint with pagination."""
        skip = random.randint(0, 50)
        limit = random.choice([10, 20, 50])
        with self.client.get(
            f"/patients?skip={skip}&limit={limit}",
            name="/patients",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list):
                    response.success()
                else:
                    response.failure(f"Invalid response format: {type(data)}")
            else:
                response.failure(f"List patients failed: {response.status_code}")

    @task(5)
    def get_patient_by_mrn(self):
        """Test single patient lookup by MRN."""
        mrn = random.choice(SAMPLE_MRNS)
        with self.client.get(
            f"/patients/{mrn}",
            name="/patients/{mrn}",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                data = response.json()
                if data.get("mrn") == mrn:
                    response.success()
                else:
                    response.failure(f"MRN mismatch: expected {mrn}")
            elif response.status_code == 404:
                # Patient not found is acceptable for random MRNs
                response.success()
            else:
                response.failure(f"Get patient failed: {response.status_code}")

    @task(10)
    def get_patient_summary(self):
        """Test patient summary endpoint - most used by Chat API."""
        mrn = random.choice(SAMPLE_MRNS)
        with self.client.get(
            f"/patients/{mrn}/summary",
            name="/patients/{mrn}/summary",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                data = response.json()
                # Verify expected structure
                if "patient" in data and "encounters" in data:
                    response.success()
                else:
                    response.failure(f"Invalid summary structure: {data.keys()}")
            elif response.status_code == 404:
                response.success()  # Patient not found is acceptable
            else:
                response.failure(f"Get summary failed: {response.status_code}")

    @task(2)
    def list_encounters(self):
        """Test encounters list endpoint."""
        skip = random.randint(0, 20)
        limit = random.choice([10, 20])
        with self.client.get(
            f"/encounters?skip={skip}&limit={limit}",
            name="/encounters",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list):
                    response.success()
                else:
                    response.failure(f"Invalid response format: {type(data)}")
            else:
                response.failure(f"List encounters failed: {response.status_code}")

    @task(2)
    def list_claims(self):
        """Test claims list endpoint."""
        skip = random.randint(0, 20)
        limit = random.choice([10, 20])
        with self.client.get(
            f"/claims?skip={skip}&limit={limit}",
            name="/claims",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list):
                    response.success()
                else:
                    response.failure(f"Invalid response format: {type(data)}")
            else:
                response.failure(f"List claims failed: {response.status_code}")

    @task(2)
    def list_documents(self):
        """Test documents list endpoint."""
        skip = random.randint(0, 20)
        limit = random.choice([10, 20])
        with self.client.get(
            f"/documents?skip={skip}&limit={limit}",
            name="/documents",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list):
                    response.success()
                else:
                    response.failure(f"Invalid response format: {type(data)}")
            else:
                response.failure(f"List documents failed: {response.status_code}")
