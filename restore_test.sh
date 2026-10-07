#!/usr/bin/env bash
# Proves the backup works: restore into a scratch DB and compare row counts.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${PGDATABASE:-capstone}"; TMP="${SRC}_restore_test"
DUMP=$(ls -t backups/capstone_*.dump | head -1)
echo "restoring $DUMP into $TMP"
dropdb --if-exists "$TMP"; createdb "$TMP"
pg_restore --no-owner --exit-on-error -d "$TMP" "$DUMP"
FAIL=0
for t in tenants users categories products orders order_items payments audit_log; do
  a=$(psql -Atc "SELECT count(*) FROM $t" "$SRC"); b=$(psql -Atc "SELECT count(*) FROM $t" "$TMP")
  [ "$a" = "$b" ] && s=OK || { s=MISMATCH; FAIL=1; }
  printf "%-12s source=%-8s restored=%-8s %s\n" "$t" "$a" "$b" "$s"
done
dropdb "$TMP"
[ $FAIL = 0 ] && echo "RESTORE TEST PASSED" || { echo "RESTORE TEST FAILED"; exit 1; }
