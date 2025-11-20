"""Load synthetic data from JSONL files into MongoDB."""
import json
import os
import sys
from pathlib import Path
from pymongo import MongoClient
from bson import ObjectId


def convert_objectid(data):
    """Convert $oid format to ObjectId."""
    if isinstance(data, dict):
        if "_id" in data and isinstance(data["_id"], dict) and "$oid" in data["_id"]:
            data["_id"] = ObjectId(data["_id"]["$oid"])
        for key, value in data.items():
            data[key] = convert_objectid(value)
    elif isinstance(data, list):
        return [convert_objectid(item) for item in data]
    return data


def load_synthetic_data(mongodb_uri=None, db_name=None, drop_collections=False):
    """Load synthetic data into MongoDB."""

    # Get connection info from environment or use defaults
    mongodb_uri = mongodb_uri or os.getenv("MONGODB_URI", "mongodb://localhost:27017")
    db_name = db_name or os.getenv("MONGODB_DB_NAME", "carepath")

    print(f"Connecting to MongoDB at {mongodb_uri}")
    print(f"Database: {db_name}")

    try:
        client = MongoClient(mongodb_uri)
        db = client[db_name]

        # Test connection
        client.server_info()
        print(" Connected to MongoDB")

    except Exception as e:
        print(f" Failed to connect to MongoDB: {e}")
        sys.exit(1)

    # Define collections and their JSONL files
    data_dir = Path("data/synthetic")
    collections_map = {
        "patients": "patients.jsonl",
        "encounters": "encounters.jsonl",
        "claims": "claims.jsonl",
        "documents": "documents.jsonl",
        "chat_logs": "chat_logs.jsonl",
        "providers": "providers.jsonl",
        "audit_logs": "audit_logs.jsonl"
    }

    for collection_name, filename in collections_map.items():
        file_path = data_dir / filename

        if not file_path.exists():
            print(f"˜ Skipping {collection_name}: file not found ({file_path})")
            continue

        # Optionally drop collection
        if drop_collections:
            db[collection_name].drop()
            print(f" Dropped collection: {collection_name}")

        # Read JSONL file
        documents = []
        with open(file_path, 'r') as f:
            for line in f:
                if line.strip():
                    doc = json.loads(line)
                    doc = convert_objectid(doc)
                    documents.append(doc)

        if documents:
            # Bulk insert
            try:
                result = db[collection_name].insert_many(documents, ordered=False)
                print(f" Loaded {len(result.inserted_ids)} documents into {collection_name}")
            except Exception as e:
                print(f"  Error loading {collection_name}: {e}")
        else:
            print(f"˜ No documents found in {filename}")

    # Create indexes
    print("\nCreating indexes...")

    try:
        db.patients.create_index("mrn", unique=True)
        print(" Created index: patients.mrn")

        db.encounters.create_index("patient_mrn")
        db.encounters.create_index("encounter_id", unique=True)
        print(" Created indexes: encounters.patient_mrn, encounters.encounter_id")

        db.claims.create_index("patient_mrn")
        db.claims.create_index("claim_id", unique=True)
        print(" Created indexes: claims.patient_mrn, claims.claim_id")

        db.documents.create_index("doc_id", unique=True)
        db.documents.create_index("patient_mrn")
        print(" Created indexes: documents.doc_id, documents.patient_mrn")

        db.chat_logs.create_index("conversation_id", unique=True)
        db.chat_logs.create_index("patient_mrn")
        print(" Created indexes: chat_logs.conversation_id, chat_logs.patient_mrn")

        db.providers.create_index("provider_id", unique=True)
        print(" Created index: providers.provider_id")

        db.audit_logs.create_index("event_id", unique=True)
        print(" Created index: audit_logs.event_id")

    except Exception as e:
        print(f"  Error creating indexes: {e}")

    print("\n Synthetic data loaded successfully!")
    client.close()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Load synthetic data into MongoDB")
    parser.add_argument("--drop", action="store_true", help="Drop collections before loading")
    parser.add_argument("--uri", help="MongoDB URI")
    parser.add_argument("--db", help="Database name")

    args = parser.parse_args()

    load_synthetic_data(
        mongodb_uri=args.uri,
        db_name=args.db,
        drop_collections=args.drop
    )
