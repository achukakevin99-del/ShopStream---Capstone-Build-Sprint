"""End-to-end demo: login -> view -> cart (Redis) -> checkout (PostgreSQL) -> events (Mongo).
Run after `make migrate roles` with the seed data (tenant 1, customer id 3)."""
from app import db, checkout
from nosql import redis_cart, mongo_events

T, U = 1, 3
mongo_events.ensure_indexes()

print("login:", db.login_lookup(T, "wanjiru@example.test", "Demo#Passw0rd"))
p = redis_cart.cached_product(T, 2, db.get_product); print("product (cached):", p)
mongo_events.track(T, U, "product_view", product_id=2)

redis_cart.add_item(T, U, 2, 2); redis_cart.add_item(T, U, 3, 1)
print("cart:", redis_cart.get_cart(T, U))
mongo_events.track(T, U, "add_to_cart", product_id=2, qty=2)

oid = checkout.checkout(T, U)
print("created order id:", oid)
print("top viewed:", mongo_events.top_viewed_products(T))

# RLS proof: tenant 2 cannot see tenant 1's order
with db.tenant_session(2) as conn:
    print("tenant 2 sees order", oid, "->", conn.execute("SELECT id FROM orders WHERE id=%s", (oid,)).fetchone())
