"""Generate synthetic data JSONL files based on data-snippets.md."""
import json
import os
from pathlib import Path


def generate_synthetic_data():
    """Generate synthetic data files matching the shapes from data-snippets.md."""

    # Create output directory
    output_dir = Path("data/synthetic")
    output_dir.mkdir(parents=True, exist_ok=True)

    # Patient data
    patients = [
        {
            "_id": {"$oid": "675000000000000000000001"},
            "mrn": "P000123",
            "name": {"first": "Alice", "last": "Nguyen"},
            "dob": "1984-03-12",
            "sex": "F",
            "address": {
                "line1": "123 Elm St",
                "city": "Raleigh",
                "state": "NC",
                "zip": "27601"
            },
            "conditions": [
                {
                    "code": "E11.9",
                    "system": "ICD-10",
                    "display": "Type 2 diabetes mellitus",
                    "onset_date": "2015-06-01"
                }
            ],
            "medications": [
                {
                    "drug_code": "860975",
                    "name": "Metformin 500mg",
                    "start_date": "2020-01-10",
                    "end_date": None,
                    "sig": "Take 1 tablet twice daily with meals"
                }
            ],
            "allergies": [
                {
                    "substance": "Penicillin",
                    "reaction": "Rash",
                    "severity": "mild"
                }
            ],
            "primary_care_provider_id": "PROV-1001",
            "risk_score": 0.72
        }
    ]

    # Encounter data
    encounters = [
        {
            "_id": {"$oid": "675000000000000000000010"},
            "patient_mrn": "P000123",
            "encounter_id": "ENC-2024-09-15-01",
            "type": "outpatient",
            "location": "Raleigh Primary Care Clinic",
            "start": "2024-09-15T09:30:00Z",
            "end": "2024-09-15T09:55:00Z",
            "diagnoses": [
                {"code": "E11.9", "system": "ICD-10", "display": "Type 2 diabetes mellitus"}
            ],
            "vitals": {
                "bp_systolic": 130,
                "bp_diastolic": 82,
                "heart_rate": 72,
                "weight_kg": 82.5
            },
            "labs": [
                {
                    "name": "Hemoglobin A1c",
                    "loinc": "4548-4",
                    "value": 7.4,
                    "unit": "%",
                    "collected_at": "2024-09-14T08:00:00Z"
                }
            ],
            "notes": "Discussed diet, exercise, and medication adherence."
        }
    ]

    # Claim data
    claims = [
        {
            "_id": {"$oid": "675000000000000000000020"},
            "claim_id": "CLM-2024-0001",
            "patient_mrn": "P000123",
            "payer": "Acme Health Plan",
            "service_date": "2024-09-15",
            "cpt_codes": ["99213"],
            "icd10_codes": ["E11.9"],
            "billed_amount": 180.0,
            "allowed_amount": 120.0,
            "patient_responsibility": 30.0,
            "status": "paid"
        }
    ]

    # Document data
    documents = [
        {
            "_id": {"$oid": "675000000000000000000030"},
            "doc_id": "DOC-CAREPLAN-P000123-2024",
            "patient_mrn": "P000123",
            "source_type": "care_plan",
            "title": "Diabetes Care Plan 2024",
            "text": "Your personalized diabetes care plan focuses on A1c control, daily walking, and medication adherence...",
            "tags": ["diabetes", "care_plan", "education"],
            "metadata": {
                "author_provider_id": "PROV-1001",
                "created_at": "2024-09-15T09:40:00Z",
                "encounter_id": "ENC-2024-09-15-01"
            }
        }
    ]

    # Chat log data
    chat_logs = [
        {
            "_id": {"$oid": "675000000000000000000040"},
            "conversation_id": "CONV-2024-09-15-P000123-01",
            "patient_mrn": "P000123",
            "channel": "web",
            "started_at": "2024-09-15T10:10:00Z",
            "ended_at": "2024-09-15T10:18:30Z",
            "messages": [
                {
                    "role": "user",
                    "content": "Why did my doctor change my diabetes medication?",
                    "timestamp": "2024-09-15T10:10:05Z"
                },
                {
                    "role": "assistant",
                    "content": "It looks like your recent A1c was 7.4%, slightly above your target...",
                    "timestamp": "2024-09-15T10:10:07Z",
                    "model_name": "gpt-4o-mini",
                    "latency_ms": 230
                }
            ],
            "retrieval_events": [
                {
                    "step_id": 1,
                    "query": "reason for medication change",
                    "top_k": 3,
                    "retrieval_latency_ms": 42,
                    "total_documents_searched": 12,
                    "results": [
                        {"doc_id": "DOC-CAREPLAN-P000123-2024", "score": 0.91},
                        {"doc_id": "DOC-VISITNOTE-ENC-2024-09-15-01", "score": 0.84}
                    ]
                }
            ]
        }
    ]

    # Provider data (optional)
    providers = [
        {
            "_id": {"$oid": "675000000000000000000050"},
            "provider_id": "PROV-1001",
            "npi": "1234567890",
            "name": {"first": "Jordan", "last": "Patel"},
            "specialty": "Internal Medicine",
            "location": "Raleigh Primary Care Clinic"
        }
    ]

    # Audit log data (optional)
    audit_logs = [
        {
            "_id": {"$oid": "675000000000000000000060"},
            "event_id": "EVT-2024-09-15-TRIAGE-001",
            "event_type": "triage_inference",
            "actor_type": "service",
            "actor_id": "triage-api",
            "patient_mrn": "P000123",
            "model_name": "carepath-gpt-triage-v1",
            "request_id": "REQ-2024-09-15-10-10-05",
            "created_at": "2024-09-15T10:10:06Z",
            "input_summary": "User asked about change in diabetes medication.",
            "output_summary": "Explained A1c result and intensification of therapy.",
            "latency_ms": 420,
            "status": "success"
        }
    ]

    # Write JSONL files
    collections = {
        "patients.jsonl": patients,
        "encounters.jsonl": encounters,
        "claims.jsonl": claims,
        "documents.jsonl": documents,
        "chat_logs.jsonl": chat_logs,
        "providers.jsonl": providers,
        "audit_logs.jsonl": audit_logs
    }

    for filename, data in collections.items():
        output_path = output_dir / filename
        with open(output_path, 'w') as f:
            for record in data:
                f.write(json.dumps(record) + '\n')
        print(f" Generated {output_path} ({len(data)} records)")

    print(f"\n All synthetic data files generated in {output_dir}")


if __name__ == "__main__":
    generate_synthetic_data()
