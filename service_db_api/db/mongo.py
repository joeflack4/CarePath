"""MongoDB connection and database management."""
import time
from typing import Optional

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo.errors import ConnectionFailure

from service_db_api.config import settings


class MongoConnection:
    """MongoDB connection manager."""

    def __init__(self):
        self.client: Optional[AsyncIOMotorClient] = None
        self.db: Optional[AsyncIOMotorDatabase] = None

    async def connect(self):
        """Establish connection to MongoDB."""
        if self.client is None:
            self.client = AsyncIOMotorClient(settings.MONGODB_URI)
            self.db = self.client[settings.MONGODB_DB_NAME]
            await self._create_indexes()

    async def close(self):
        """Close MongoDB connection."""
        if self.client:
            self.client.close()
            self.client = None
            self.db = None

    def get_database(self) -> AsyncIOMotorDatabase:
        """Get the database instance."""
        if self.db is None:
            raise RuntimeError("Database not connected. Call connect() first.")
        return self.db

    async def ping(self) -> dict:
        """Ping MongoDB to check connectivity and measure latency."""
        if self.db is None:
            return {"success": False, "error": "Database not connected", "latency_ms": 0}

        try:
            start = time.time()
            await self.db.command("ping")
            latency_ms = round((time.time() - start) * 1000, 2)
            return {"success": True, "latency_ms": latency_ms}
        except ConnectionFailure as e:
            return {"success": False, "error": str(e), "latency_ms": 0}

    async def _create_indexes(self):
        """Create indexes for all collections."""
        if self.db is None:
            return

        # patients collection
        await self.db.patients.create_index("mrn", unique=True)

        # encounters collection
        await self.db.encounters.create_index("patient_mrn")
        await self.db.encounters.create_index("encounter_id", unique=True)

        # claims collection
        await self.db.claims.create_index("patient_mrn")
        await self.db.claims.create_index("claim_id", unique=True)

        # documents collection
        await self.db.documents.create_index("doc_id", unique=True)
        await self.db.documents.create_index("patient_mrn")

        # chat_logs collection
        await self.db.chat_logs.create_index("conversation_id", unique=True)
        await self.db.chat_logs.create_index("patient_mrn")

        # providers collection (optional)
        await self.db.providers.create_index("provider_id", unique=True)

        # audit_logs collection (optional)
        await self.db.audit_logs.create_index("event_id", unique=True)


# Global connection instance
mongo = MongoConnection()


async def get_database() -> AsyncIOMotorDatabase:
    """Dependency to get database instance."""
    return mongo.get_database()
