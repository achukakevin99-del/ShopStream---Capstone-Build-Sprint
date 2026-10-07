-- V4: least-privilege roles + Row Level Security.
-- Roles are cluster-wide so creation is guarded (flyway clean does not drop roles).
-- Passwords are set OUTSIDE migrations by scripts/setup_roles.sh.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'capstone_app') THEN
        CREATE ROLE capstone_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'capstone_readonly') THEN
        CREATE ROLE capstone_readonly LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
    END IF;
END $$;

-- Helper: current tenant from the session (NULL when unset => sees nothing)
CREATE OR REPLACE FUNCTION app_tenant_id() RETURNS bigint
LANGUAGE sql STABLE AS $$ SELECT NULLIF(current_setting('app.tenant_id', true), '')::bigint $$;

-- Table privileges (no DELETE anywhere, audit_log read-only)
GRANT USAGE ON SCHEMA public TO capstone_app, capstone_readonly;
GRANT SELECT                 ON tenants, audit_log          TO capstone_app;
GRANT SELECT, INSERT, UPDATE ON users, categories, products,
                                orders, order_items, payments TO capstone_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO capstone_app;

GRANT SELECT ON tenants, categories, products, orders, order_items, payments TO capstone_readonly;
GRANT SELECT (id, tenant_id, email, full_name, role, created_at) ON users TO capstone_readonly; -- no password_hash

-- RLS on every tenant-scoped table
ALTER TABLE tenants     ENABLE ROW LEVEL SECURITY;
ALTER TABLE users       ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories  ENABLE ROW LEVEL SECURITY;
ALTER TABLE products    ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log   ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_self ON tenants USING (id = app_tenant_id());

CREATE POLICY tenant_isolation ON users       USING (tenant_id = app_tenant_id()) WITH CHECK (tenant_id = app_tenant_id());
CREATE POLICY tenant_isolation ON categories  USING (tenant_id = app_tenant_id()) WITH CHECK (tenant_id = app_tenant_id());
CREATE POLICY tenant_isolation ON products    USING (tenant_id = app_tenant_id()) WITH CHECK (tenant_id = app_tenant_id());
CREATE POLICY tenant_isolation ON orders      USING (tenant_id = app_tenant_id()) WITH CHECK (tenant_id = app_tenant_id());
CREATE POLICY tenant_isolation ON order_items USING (tenant_id = app_tenant_id()) WITH CHECK (tenant_id = app_tenant_id());
CREATE POLICY tenant_isolation ON payments    USING (tenant_id = app_tenant_id()) WITH CHECK (tenant_id = app_tenant_id());
CREATE POLICY tenant_read_audit ON audit_log FOR SELECT USING (tenant_id = app_tenant_id());

-- The table owner (migration user) bypasses RLS by design; the app roles never do.
