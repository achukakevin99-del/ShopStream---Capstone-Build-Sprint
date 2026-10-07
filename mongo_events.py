"""MongoDB: clickstream / behaviour-event ingestion buffer.

Why MongoDB (see docs/03_nosql_justification.md):
  * Event payloads vary (view, search, add_to_cart...) -> flexible documents, no migrations.
  * Very high insert rate, append-only, expendable after 30 days -> TTL index.
"""
import os
from datetime import datetime, timezone
from pymongo import MongoClient, ASCENDING, DESCENDING

db = MongoClient(os.getenv("MONGO_URL", "mongodb://localhost:27017"))["shopstream"]
events = db["events"]


def ensure_indexes():
    events.create_index([("ts", ASCENDING)], expireAfterSeconds=30 * 24 * 3600)   # TTL
    events.create_index([("tenant_id", ASCENDING), ("type", ASCENDING), ("ts", DESCENDING)])


def track(tenant_id: int, user_id: int | None, event_type: str, **payload):
    events.insert_one({"tenant_id": tenant_id, "user_id": user_id, "type": event_type,
                       "ts": datetime.now(timezone.utc), "payload": payload})


def top_viewed_products(tenant_id: int, limit: int = 5):
    pipeline = [
        {"$match": {"tenant_id": tenant_id, "type": "product_view"}},
        {"$group": {"_id": "$payload.product_id", "views": {"$sum": 1}}},
        {"$sort": {"views": -1}},
        {"$limit": limit},
    ]
    return list(events.aggregate(pipeline))
