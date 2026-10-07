-- Analytical queries used in Day 4. Tenant 1 is used for every test.
-- Q1  Top 10 products by revenue, last 90 days (shop owner dashboard)
SELECT p.id, p.name, sum(oi.quantity * oi.unit_price_cents) AS revenue_cents
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p     ON p.id = oi.product_id
WHERE o.tenant_id = 1
  AND o.status <> 'cancelled'
  AND o.placed_at >= now() - interval '90 days'
GROUP BY p.id, p.name
ORDER BY revenue_cents DESC
LIMIT 10;

-- Q2  A customer's 20 most recent orders (customer "My orders" page)
SELECT id, status, total_cents, placed_at
FROM orders
WHERE user_id = 5000
ORDER BY placed_at DESC
LIMIT 20;

-- Q3  Product search by partial name (storefront search box)
SELECT id, name, price_cents
FROM products
WHERE tenant_id = 1 AND name ILIKE '%speaker%'
LIMIT 50;

-- Q4  Revenue for September 2026 (monthly report)
--     BEFORE form (non-sargable):   WHERE date_trunc('month', placed_at) = DATE '2026-09-01'
--     AFTER  form (range, sargable): WHERE placed_at >= '2026-09-01' AND placed_at < '2026-10-01'
SELECT count(*) AS orders, sum(total_cents) AS revenue_cents
FROM orders
WHERE tenant_id = 1
  AND status <> 'cancelled'
  AND placed_at >= DATE '2026-09-01' AND placed_at < DATE '2026-10-01';
