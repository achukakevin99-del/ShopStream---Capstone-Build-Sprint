# Day 3 - NoSQL Layer: What and Why

| Concern | Store | Why not just PostgreSQL? |
|---------|-------|--------------------------|
| Shopping cart | **Redis** hash `cart:{tenant}:{user}` with 7-day TTL | A cart is temporary, rewritten on every click and often abandoned. In PostgreSQL that is constant INSERT/UPDATE/DELETE churn, dead tuples and vacuum load for data we never report on. Redis gives atomic `HINCRBY`, sub-millisecond latency and automatic expiry. |
| Product cache | **Redis** key `cache:product:{tenant}:{id}` (TTL 5 min, cache-aside) | The catalogue is read far more than written. Serving hot rows from memory removes repeated identical queries; invalidation is a single `DEL` on stock/price change. |
| Behaviour events (views, searches, add-to-cart) | **MongoDB** collection `events` with 30-day TTL index | Event shapes differ per type and evolve; documents avoid schema migrations. Write volume is far higher than orders, data is append-only and expendable, and TTL deletes old events with no batch job. |

## What stays in PostgreSQL (and why)
Orders, order items, payments, stock, users, tenancy and audit: they need ACID transactions,
foreign keys, RLS, and auditing. **Checkout is the bridge**: it reads the Redis cart, then in ONE
PostgreSQL transaction locks product rows (`FOR UPDATE`), checks stock, writes order, items and
payment, and only after COMMIT clears the cart. If PostgreSQL fails, the cart is untouched.

## Failure behaviour
- Redis down: browsing still works (cache miss -> PostgreSQL); carts unavailable (acceptable degradation).
- MongoDB down: events dropped or queued by the app; no impact on orders.
- Neither Redis nor MongoDB is a system of record. Everything that must survive is in PostgreSQL.

## Trade-offs considered
- Cart in a PostgreSQL table: simpler stack, but write churn and manual cleanup.
- Events in PostgreSQL JSONB: possible, but would bloat the OLTP database and its backups.
- Chose two small, purpose-built stores over one multipurpose one.

Code: `nosql/redis_cart.py`, `nosql/mongo_events.py`, `app/checkout.py`.
