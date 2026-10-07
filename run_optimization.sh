#!/usr/bin/env bash
# Day 4: generate REAL before/after EXPLAIN ANALYZE evidence and the final report.
# Usage: PGHOST=localhost PGUSER=postgres PGPASSWORD=... ./optimization/run_optimization.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${PGDATABASE:-capstone}"
EV=optimization/evidence
REPORT=optimization/optimization_report.md
P="psql -X -q -v ON_ERROR_STOP=1 -d $DB"

echo ">> dropping optimization indexes, loading bulk data (a few minutes)"
$P -c "DROP INDEX IF EXISTS idx_orders_tenant_placed, idx_orders_user_placed, idx_products_name_trgm, idx_order_items_product;"
if [ "$($P -Atc 'SELECT count(*) FROM orders')" -lt 100000 ]; then $P -f db/dev/bulk_seed.sql; fi
$P -c "ANALYZE;"

explain() {  # name label sql
  echo "-- $3" > "$EV/$1_$2.txt"
  $P -c "EXPLAIN (ANALYZE, BUFFERS) $3" >> "$EV/$1_$2.txt"
}
exec_ms() { grep -oE 'Execution Time: [0-9.]+ ms' "$EV/$1_$2.txt" | grep -oE '[0-9.]+'; }
scan_kinds() { grep -oE '(Seq Scan|Index Scan|Index Only Scan|Bitmap Index Scan|Bitmap Heap Scan)' "$EV/$1_$2.txt" | sort -u | paste -sd, -; }

: > "$REPORT"
cat >> "$REPORT" <<HDR
# Query Optimization Report (generated $(date -u +%F\ %T) UTC)
Dataset: $($P -Atc 'SELECT count(*) FROM orders') orders, $($P -Atc 'SELECT count(*) FROM order_items') order items, $($P -Atc 'SELECT count(*) FROM products') products.
Plans are real \`EXPLAIN (ANALYZE, BUFFERS)\` output captured by \`run_optimization.sh\`.

HDR

case_run() {  # id title question before_sql change_desc why drop_sql create_sql after_sql
  local id="$1" title="$2" question="$3" before="$4" change="$5" why="$6" drop="$7" create="$8" after="$9"
  [ -n "$drop" ] && $P -c "$drop"
  $P -c "ANALYZE;"
  explain "$id" before "$before"
  $P -c "$create"
  $P -c "ANALYZE;"
  explain "$id" after "$after"
  local b a; b=$(exec_ms "$id" before); a=$(exec_ms "$id" after)
  cat >> "$REPORT" <<SEC
## $id - $title
**1. QUERY:** $question

**2. BEFORE PLAN:**
\`\`\`
$(cat "$EV/${id}_before.txt")
\`\`\`
**3. CHANGE:** $change
*Why:* $why

\`\`\`sql
$create
\`\`\`
**4. AFTER PLAN:**
\`\`\`
$(cat "$EV/${id}_after.txt")
\`\`\`
**5. RESULT:** ${b} ms -> ${a} ms ($(scan_kinds "$id" before) -> $(scan_kinds "$id" after))

SEC
}

Q1="SELECT p.id, p.name, sum(oi.quantity * oi.unit_price_cents) AS revenue_cents FROM orders o JOIN order_items oi ON oi.order_id = o.id JOIN products p ON p.id = oi.product_id WHERE o.tenant_id = 1 AND o.status <> 'cancelled' AND o.placed_at >= now() - interval '90 days' GROUP BY p.id, p.name ORDER BY revenue_cents DESC LIMIT 10"
Q2="SELECT id, status, total_cents, placed_at FROM orders WHERE user_id = 5000 ORDER BY placed_at DESC LIMIT 20"
Q3="SELECT id, name, price_cents FROM products WHERE tenant_id = 1 AND name ILIKE '%speaker%' LIMIT 50"
Q4B="SELECT count(*), sum(total_cents) FROM orders WHERE tenant_id = 1 AND status <> 'cancelled' AND date_trunc('month', placed_at) = DATE '2026-09-01'"
Q4A="SELECT count(*), sum(total_cents) FROM orders WHERE tenant_id = 1 AND status <> 'cancelled' AND placed_at >= DATE '2026-09-01' AND placed_at < DATE '2026-10-01'"

case_run Q1 "Top products by revenue (90 days)" "Which 10 products earned the most revenue for a shop in the last 90 days?" "$Q1" \
  "Composite index on orders (tenant_id, placed_at DESC)." \
  "The planner can read only one tenant's recent orders instead of scanning every order." \
  "" "CREATE INDEX idx_orders_tenant_placed ON orders (tenant_id, placed_at DESC);" "$Q1"
case_run Q2 "Customer order history" "What are a customer's 20 latest orders?" "$Q2" \
  "Index on orders (user_id, placed_at DESC)." \
  "Matches the filter and the ORDER BY, so no sort is needed and LIMIT stops early." \
  "" "CREATE INDEX idx_orders_user_placed ON orders (user_id, placed_at DESC);" "$Q2"
case_run Q3 "Partial-name product search" "Which products have 'speaker' in the name?" "$Q3" \
  "GIN trigram index on products.name." \
  "A b-tree cannot serve ILIKE '%x%'; pg_trgm indexes 3-letter fragments." \
  "" "CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);" "$Q3"
# Q4: index already needed -> first show the NON-SARGABLE form WITH the index present
$P -c "CREATE INDEX IF NOT EXISTS idx_orders_tenant_placed ON orders (tenant_id, placed_at DESC);"
case_run Q4 "Monthly revenue" "What was one shop's revenue in September 2026?" "$Q4B" \
  "Query rewrite: replace date_trunc('month', placed_at) = ... with a half-open date range." \
  "Wrapping the column in a function hides it from the index; a range predicate is sargable." \
  "" "SELECT 'rewrite only - no DDL';" "$Q4A"

# leave all optimization indexes in place
$P -c "CREATE INDEX IF NOT EXISTS idx_orders_tenant_placed ON orders (tenant_id, placed_at DESC);
       CREATE INDEX IF NOT EXISTS idx_orders_user_placed   ON orders (user_id, placed_at DESC);
       CREATE INDEX IF NOT EXISTS idx_products_name_trgm   ON products USING gin (name gin_trgm_ops);
       CREATE INDEX IF NOT EXISTS idx_order_items_product  ON order_items (product_id);"
echo ">> done. Report: $REPORT   Raw plans: $EV/"
