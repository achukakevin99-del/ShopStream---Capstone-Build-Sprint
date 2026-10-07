-- Performance-test data (NOT a migration). Run as the owner/superuser after migrate.
-- ~20k customers, 10k products, 300k orders, ~900k order items.
-- Triggers (audit + FK checks) are bypassed for speed; data is generated consistently.
\set ON_ERROR_STOP on
SET session_replication_role = replica;

INSERT INTO products (tenant_id, category_id, sku, name, description, price_cents, stock)
SELECT t.id,
       (SELECT (array_agg(c.id ORDER BY c.id))[1 + g % 3] FROM categories c WHERE c.tenant_id = t.id),
       'BULK-' || g,
       (ARRAY['Wireless','Compact','Premium','Eco','Smart','Classic'])[1 + g % 6] || ' ' ||
       (ARRAY['Speaker','Lamp','Kettle','Charger','Backpack','Notebook','Headset'])[1 + g % 7] || ' ' || g,
       'Bulk generated product ' || g,
       50000 + (g % 400) * 5000,
       100
FROM tenants t CROSS JOIN generate_series(1, 5000) g;

WITH h AS (SELECT crypt('bulk-demo', gen_salt('bf', 4)) AS p)
INSERT INTO users (tenant_id, email, password_hash, full_name, role)
SELECT t.id, 'cust' || g || '@tenant' || t.id || '.test', h.p, 'Customer ' || g, 'customer'
FROM tenants t CROSS JOIN generate_series(1, 10000) g CROSS JOIN h;

INSERT INTO orders (tenant_id, user_id, status, total_cents, placed_at)
SELECT u.tenant_id, u.id,
       (ARRAY['pending','paid','shipped','delivered','cancelled'])[1 + floor(random()*5)::int],
       0,
       now() - (random() * 730) * interval '1 day'
FROM users u CROSS JOIN generate_series(1, 15) s
WHERE u.role = 'customer' AND u.email LIKE 'cust%';

CREATE TEMP TABLE tp AS
SELECT tenant_id, array_agg(id) AS ids, array_agg(price_cents) AS prices, count(*)::int AS n
FROM products GROUP BY tenant_id;

INSERT INTO order_items (tenant_id, order_id, product_id, quantity, unit_price_cents)
SELECT o.tenant_id, o.id, tp.ids[r.k], 1 + floor(random()*3)::int, tp.prices[r.k]
FROM orders o
JOIN tp ON tp.tenant_id = o.tenant_id
CROSS JOIN generate_series(1, 3) s
CROSS JOIN LATERAL (SELECT 1 + floor(random() * tp.n)::int AS k) r
WHERE o.total_cents = 0;

UPDATE orders o SET total_cents = s.t
FROM (SELECT order_id, sum(quantity::bigint * unit_price_cents) AS t FROM order_items GROUP BY order_id) s
WHERE s.order_id = o.id AND o.total_cents = 0;

SET session_replication_role = DEFAULT;
ANALYZE;
SELECT 'orders' AS t, count(*) FROM orders UNION ALL
SELECT 'order_items', count(*) FROM order_items UNION ALL
SELECT 'products', count(*) FROM products;
