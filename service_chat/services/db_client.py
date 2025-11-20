"""HTTP client for communicating with service_db_api."""
import httpx
from typing import Dict, Any

from service_chat.config import settings


class PatientNotFoundError(Exception):
    """Raised when a patient is not found in the database."""
    pass


class DBAPIError(Exception):
    """Raised when there's an error communicating with the DB API."""
    pass


async def get_patient_summary(mrn: str) -> Dict[str, Any]:
    """
    Fetch patient summary from service_db_api.

    Args:
        mrn: Patient Medical Record Number

    Returns:
        dict: Patient summary including demographics, encounters, claims, and documents

    Raises:
        PatientNotFoundError: If patient with given MRN is not found
        DBAPIError: If there's an error communicating with the DB API
    """
    url = f"{settings.DB_API_BASE_URL}/patients/{mrn}/summary"

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url)

            if response.status_code == 404:
                raise PatientNotFoundError(f"Patient with MRN {mrn} not found")

            if response.status_code != 200:
                raise DBAPIError(
                    f"DB API returned status {response.status_code}: {response.text}"
                )

            return response.json()

    except httpx.RequestError as e:
        raise DBAPIError(f"Error communicating with DB API: {str(e)}")
