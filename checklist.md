# Day 5 - Security Checklist (with evidence)

Run `./scripts/verify_security.sh` for the automated items.

| # | Control | Status | Evidence |
|---|---------|--------|----------|
| 1 | Least-privilege roles, no app superuser | [x] | V4 creates `capstone_app` (NOSUPERUSER, NOBYPASSRLS; SELECT/INSERT/UPDATE only, no DELETE, audit_log read-only) and `capstone_readonly` (no `password_hash` column). Checks 1a-1d. |
| 2 | RLS on every multi-tenant / sensitive table | [x] | V4 enables RLS + `tenant_isolation` policies on all 8 tables (policy uses `app_tenant_id()`). Checks 2, 2a-2c; `tests/rls_demo.sql`. |
| 3 | Sensitive fields hashed/encrypted | [x] | Passwords: bcrypt via `pgcrypto crypt(..., gen_salt('bf'))`; verified in-DB by `app/db.py:login_lookup`. Payments store gateway tokens only. Audit trigger strips `password_hash`. Check 3, 4b. |
| 4 | Audit log on critical tables | [x] | V3 trigger on users, products, orders, payments; `changed_by` from `app.user_id`. Check 4. |
| 5 | Parameterized queries only | [x] | `app/` uses psycopg `%s` placeholders with a separate parameters tuple; no string building. Review: `grep -rnE "f\"|f'|\+ " app/`. |
| 6 | Backups taken AND test restore performed | [ ] | Run `scripts/backup.sh` then `scripts/restore_test.sh`; paste its output below and tick the box. |

## Test restore output (paste yours)
```
(run ./scripts/restore_test.sh and paste here)
```

## Residual risks / next steps
- Table owner bypasses RLS: migrations must use a separate admin account, never the app.
- Transport encryption (TLS) and secret storage (vault/env) are deployment concerns, not covered here.
- Customers-see-only-own-orders can be added as a second RLS policy keyed on `app.user_id`.
