"""Checkout: Redis cart -> PostgreSQL order (one ACID transaction)."""
from nosql import redis_cart
from app.db import tenant_session


def checkout(tenant_id: int, user_id: int, method: str = "mpesa") -> int:
    cart = redis_cart.get_cart(tenant_id, user_id)
    if not cart:
        raise ValueError("cart is empty")

    with tenant_session(tenant_id, user_id) as conn:
        # Lock the product rows so concurrent checkouts cannot oversell stock
        prods = conn.execute(
            "SELECT id, price_cents, stock FROM products "
            "WHERE id = ANY(%s) AND active FOR UPDATE", (list(cart),)
        ).fetchall()
        by_id = {p["id"]: p for p in prods}
        missing = set(cart) - set(by_id)
        if missing:
            raise ValueError(f"unavailable products: {sorted(missing)}")
        for pid, qty in cart.items():
            if by_id[pid]["stock"] < qty:
                raise ValueError(f"not enough stock for product {pid}")

        total = sum(by_id[pid]["price_cents"] * qty for pid, qty in cart.items())
        order_id = conn.execute(
            "INSERT INTO orders (tenant_id, user_id, status, total_cents) "
            "VALUES (%s, %s, 'pending', %s) RETURNING id",
            (tenant_id, user_id, total),
        ).fetchone()["id"]

        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO order_items (tenant_id, order_id, product_id, quantity, unit_price_cents) "
                "VALUES (%s, %s, %s, %s, %s)",
                [(tenant_id, order_id, pid, qty, by_id[pid]["price_cents"]) for pid, qty in cart.items()],
            )
            cur.executemany(
                "UPDATE products SET stock = stock - %s WHERE id = %s",
                [(qty, pid) for pid, qty in cart.items()],
            )
        conn.execute(
            "INSERT INTO payments (tenant_id, order_id, method, status, amount_cents) "
            "VALUES (%s, %s, %s, 'pending', %s)", (tenant_id, order_id, method, total),
        )
    # only after COMMIT do we discard the cart
    redis_cart.clear_cart(tenant_id, user_id)
    for pid in cart:
        redis_cart.invalidate_product(tenant_id, pid)     # stock changed
    return order_id
