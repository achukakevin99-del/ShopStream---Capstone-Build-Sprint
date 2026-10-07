"""PostgreSQL access: least-privilege role, tenant context, parameterized SQL only."""
import os
from contextlib import contextmanager
import psycopg
from psycopg.rows import dict_row

DSN = os.getenv("APP_DATABASE_URL",
                "postgresql://capstone_app:change_me_app_pw@localhost:5432/capstone")


@contextmanager
def tenant_session(tenant_id: int, user_id: int | None = None):
    """One transaction with RLS context. set_config(..., true) is transaction-local,
    so the tenant can never leak to the next user of a pooled connection."""
    with psycopg.connect(DSN, row_factory=dict_row) as conn:
        with conn.transaction():
            conn.execute(
                "SELECT set_config('app.tenant_id', %s, true), set_config('app.user_id', %s, true)",
                (str(tenant_id), "" if user_id is None else str(user_id)),
            )
            yield conn


def get_product(tenant_id: int, product_id: int):
    with tenant_session(tenant_id) as conn:
        return conn.execute(
            "SELECT id, sku, name, price_cents, stock FROM products WHERE id = %s AND active",
            (product_id,),                      # values are bound, never concatenated
        ).fetchone()


def login_lookup(tenant_id: int, email: str, password: str):
    """Verify the password inside PostgreSQL (bcrypt via pgcrypto); hash never leaves the DB."""
    with tenant_session(tenant_id) as conn:
        return conn.execute(
            "SELECT id, full_name, role FROM users "
            "WHERE email = %s AND password_hash = crypt(%s, password_hash)",
            (email, password),
        ).fetchone()
