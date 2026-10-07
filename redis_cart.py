"""Redis: shopping cart + hot-product cache.

Why Redis (see docs/03_nosql_justification.md):
  * Carts are temporary, write-heavy, per-session -> TTL + hash ops beat INSERT/UPDATE/DELETE rows.
  * Product cache-aside removes repeated catalogue reads from PostgreSQL.
"""
import json, os
import redis

r = redis.Redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379/0"), decode_responses=True)
CART_TTL = 7 * 24 * 3600     # abandoned carts vanish by themselves
CACHE_TTL = 300


def _key(tenant_id: int, user_id: int) -> str:
    return f"cart:{tenant_id}:{user_id}"          # tenant in the key = no cross-tenant leakage


def add_item(tenant_id, user_id, product_id, qty=1):
    k = _key(tenant_id, user_id)
    pipe = r.pipeline()
    pipe.hincrby(k, str(product_id), qty)          # atomic increment
    pipe.expire(k, CART_TTL)
    pipe.execute()


def set_quantity(tenant_id, user_id, product_id, qty):
    k = _key(tenant_id, user_id)
    if qty <= 0:
        r.hdel(k, str(product_id))
    else:
        r.hset(k, str(product_id), qty)
        r.expire(k, CART_TTL)


def get_cart(tenant_id, user_id) -> dict[int, int]:
    return {int(p): int(q) for p, q in r.hgetall(_key(tenant_id, user_id)).items()}


def clear_cart(tenant_id, user_id):
    r.delete(_key(tenant_id, user_id))


def cached_product(tenant_id, product_id, loader):
    """Cache-aside: `loader(tenant_id, product_id)` reads PostgreSQL on a miss."""
    k = f"cache:product:{tenant_id}:{product_id}"
    hit = r.get(k)
    if hit:
        return json.loads(hit)
    row = loader(tenant_id, product_id)
    if row:
        r.setex(k, CACHE_TTL, json.dumps(row, default=str))
    return row


def invalidate_product(tenant_id, product_id):
    r.delete(f"cache:product:{tenant_id}:{product_id}")
