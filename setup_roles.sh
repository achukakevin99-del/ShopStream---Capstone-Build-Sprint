#!/usr/bin/env bash
# Sets passwords for the least-privilege roles created by V4. Run once after migrate.
set -euo pipefail
: "${APP_PASSWORD:?set APP_PASSWORD}" "${READONLY_PASSWORD:?set READONLY_PASSWORD}"
psql -X -v ON_ERROR_STOP=1 -v app_pw="$APP_PASSWORD" -v ro_pw="$READONLY_PASSWORD" -d "${PGDATABASE:-capstone}" <<'SQL'
ALTER ROLE capstone_app      PASSWORD :'app_pw';
ALTER ROLE capstone_readonly PASSWORD :'ro_pw';
SQL
echo "roles ready"
