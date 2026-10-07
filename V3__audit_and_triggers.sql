-- V3: generic audit trigger. SECURITY DEFINER so the low-privilege app role can
-- cause audit rows without having INSERT rights on audit_log itself.
CREATE OR REPLACE FUNCTION audit_row() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_old  jsonb;
    v_new  jsonb;
    v_row  jsonb;
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN v_old := to_jsonb(OLD); END IF;
    IF TG_OP IN ('INSERT','UPDATE') THEN v_new := to_jsonb(NEW); END IF;
    v_row := COALESCE(v_new, v_old);

    -- never store password hashes in the audit trail
    IF TG_TABLE_NAME = 'users' THEN
        v_old := v_old - 'password_hash';
        v_new := v_new - 'password_hash';
    END IF;

    INSERT INTO audit_log (tenant_id, table_name, record_id, action, old_data, new_data, changed_by)
    VALUES ((v_row->>'tenant_id')::bigint,
            TG_TABLE_NAME,
            (v_row->>'id')::bigint,
            TG_OP,
            v_old,
            v_new,
            NULLIF(current_setting('app.user_id', true), '')::bigint);
    RETURN NULL;   -- AFTER trigger: return value ignored
END;
$$;

CREATE TRIGGER trg_audit_users    AFTER INSERT OR UPDATE OR DELETE ON users    FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit_products AFTER INSERT OR UPDATE OR DELETE ON products FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit_orders   AFTER INSERT OR UPDATE OR DELETE ON orders   FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit_payments AFTER INSERT OR UPDATE OR DELETE ON payments FOR EACH ROW EXECUTE FUNCTION audit_row();
