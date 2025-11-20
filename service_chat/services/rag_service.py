"""RAG (Retrieval Augmented Generation) service for building LLM prompts."""
import json
from typing import Dict, Any


def build_prompt(query: str, patient_summary: Dict[str, Any]) -> str:
    """
    Build a prompt for the LLM by combining patient summary and user query.

    This function is the only place where patient data and query are combined
    into a prompt string for the LLM.

    For MVP, we use the patient summary from service_db_api directly.
    In future phases, this could be enhanced with:
    - Vector search results from Pinecone
    - Relevant document excerpts
    - Additional context from knowledge base

    Args:
        query: User's question
        patient_summary: Patient data from service_db_api

    Returns:
        str: Formatted prompt for LLM
    """
    # Extract key patient information
    patient = patient_summary.get("patient", {})
    mrn = patient.get("mrn", "Unknown")
    name = patient.get("name", {})
    patient_name = f"{name.get('first', '')} {name.get('last', '')}".strip()

    # Get recent encounters
    encounters = patient_summary.get("recent_encounters", [])
    encounter_count = len(encounters)

    # Get conditions
    conditions = patient.get("conditions", [])
    condition_list = [c.get("display", "") for c in conditions if c.get("display")]

    # Build the prompt
    prompt = f"""You are a helpful AI healthcare assistant for CarePath.

PATIENT INFORMATION:
- MRN: {mrn}
- Name: {patient_name}
- Date of Birth: {patient.get('dob', 'Unknown')}
- Medical Conditions: {', '.join(condition_list) if condition_list else 'None recorded'}
- Recent Encounters: {encounter_count}

PATIENT SUMMARY DATA:
{json.dumps(patient_summary, indent=2)}

USER QUESTION:
{query}

Please provide a helpful, empathetic response to the patient's question based on the information above.
Keep your response clear, concise, and patient-friendly.
"""

    return prompt
