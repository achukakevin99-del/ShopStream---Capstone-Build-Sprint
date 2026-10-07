#!/usr/bin/env bash
# Automated evidence for the Day 5 security checklist. Run on a freshly migrated DB.
set -uo pipefail
DB="${PGDATABASE:-capstone}"; PASS=0; FAILN=0
A="psql -X -Atq -d $DB"
check() { if [ "$2" = "$3" ]; then echo "[PASS] $1"; PASS=$((PASS+1)); else echo "[FAIL] $1 (got '$2', want '$3')"; FAILN=$((FAILN+1)); fi; }

check "1a app role is not superuser / cannot bypass RLS" \
  "$($A -c "SELECT rolsuper OR rolbypassrls OR rolcreaterole OR rolcreatedb FROM pg_roles WHERE rolname='capstone_app'")" "f"
check "1b readonly role is not superuser / cannot bypass RLS" \
  "$($A -c "SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname='capstone_readonly'")" "f"
check "2  every table with tenant_id (or tenants) has RLS enabled (excluding flyway history)" \
  "$($A -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname='public' AND c.relkind='r' AND c.relname <> 'flyway_schema_history' AND NOT c.relrowsecurity")" "0"
check "3  all user password hashes are bcrypt" \
  "$($A -c "SELECT count(*) FROM users WHERE password_hash NOT LIKE '\$2%'")" "0"
check "4  audit log has rows for critical tables" \
  "$($A -c "SELECT count(DISTINCT table_name) >= 3 FROM audit_log")" "t"
check "4b audit log never stores password hashes" \
  "$($A -c "SELECT count(*) FROM audit_log WHERE new_data ? 'password_hash' OR old_data ? 'password_hash'")" "0"

# RLS behaviour as the real app role
export PGPASSWORD="${APP_PASSWORD:-}"
AP="psql -X -Atq -h ${PGHOST:-localhost} -U capstone_app -d $DB"
check "2a tenant 1 sees no foreign orders" \
  "$($AP -c "SELECT set_config('app.tenant_id','1',false); SELECT count(*) FROM orders WHERE tenant_id <> 1" | tail -1)" "0"
check "2b no tenant context => zero rows" \
  "$($AP -c "SELECT count(*) FROM orders" | tail -1)" "0"
check "2c cross-tenant INSERT is rejected" \
  "$($AP -c "SELECT set_config('app.tenant_id','1',false); INSERT INTO categories (tenant_id,name) VALUES (2,'evil')" 2>&1 | grep -c 'row-level security')" "1"
check "1c app cannot DELETE audit rows" \
  "$($AP -c "DELETE FROM audit_log" 2>&1 | grep -c 'permission denied')" "1"
check "1d app cannot DROP tables" \
  "$($AP -c "DROP TABLE orders" 2>&1 | grep -c 'must be owner')" "1"

echo "---- $PASS passed, $FAILN failed"
echo "Manual items: 5 (parameterized queries: grep -rnE 'f\"|\\+ ' app/ shows no SQL built from input), 6 (run scripts/backup.sh then restore_test.sh)"
exit $FAILN
