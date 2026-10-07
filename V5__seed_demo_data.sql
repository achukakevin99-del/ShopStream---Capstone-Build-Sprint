-- V5: small, deterministic demo data (2 tenants). Bulk data for performance
-- testing lives in db/dev/bulk_seed.sql and is NOT a migration.
INSERT INTO tenants (id, name, slug) VALUES
 (1, 'Nairobi Gadgets',    'nairobi-gadgets'),
 (2, 'Mombasa Home Goods', 'mombasa-home');

INSERT INTO users (id, tenant_id, email, password_hash, full_name, role) VALUES
 (1, 1, 'owner@nairobigadgets.test', crypt('Demo#Passw0rd', gen_salt('bf', 8)), 'Amina Owner',  'owner'),
 (2, 1, 'staff@nairobigadgets.test', crypt('Demo#Passw0rd', gen_salt('bf', 8)), 'Brian Staff',  'staff'),
 (3, 1, 'wanjiru@example.test',      crypt('Demo#Passw0rd', gen_salt('bf', 8)), 'Wanjiru Kamau','customer'),
 (4, 1, 'otieno@example.test',       crypt('Demo#Passw0rd', gen_salt('bf', 8)), 'Otieno Odhiambo','customer'),
 (5, 2, 'owner@mombasahome.test',    crypt('Demo#Passw0rd', gen_salt('bf', 8)), 'Fatma Owner',  'owner'),
 (6, 2, 'zawadi@example.test',       crypt('Demo#Passw0rd', gen_salt('bf', 8)), 'Zawadi Mwinyi','customer'),
 (7, 2, 'juma@example.test',         crypt('Demo#Passw0rd', gen_salt('bf', 8)), 'Juma Hassan',  'customer');

INSERT INTO categories (id, tenant_id, parent_id, name) VALUES
 (1, 1, NULL, 'Electronics'), (2, 1, 1, 'Accessories'), (3, 1, NULL, 'Home'), (4, 1, NULL, 'Books'),
 (5, 2, NULL, 'Electronics'), (6, 2, 5, 'Accessories'), (7, 2, NULL, 'Home'), (8, 2, NULL, 'Books');

INSERT INTO products (id, tenant_id, category_id, sku, name, description, price_cents, stock) VALUES
 (1, 1, 1, 'NG-PHN-001', 'Smartphone X1', '6.5 inch, 128GB',      2500000, 40),
 (2, 1, 2, 'NG-ACC-001', 'Phone Case',    'Shock-proof case',       150000, 200),
 (3, 1, 2, 'NG-ACC-002', 'USB-C Cable',   '1m braided cable',        80000, 500),
 (4, 1, 3, 'NG-HOM-001', 'Desk Lamp',     'LED, dimmable',          320000, 75),
 (5, 2, 7, 'MH-HOM-001', 'Ceramic Mug Set','Set of 4 mugs',         120000, 120),
 (6, 2, 7, 'MH-HOM-002', 'Bamboo Tray',   'Serving tray',            90000, 60),
 (7, 2, 8, 'MH-BK-001',  'Swahili Cookbook','Coastal recipes',      180000, 80),
 (8, 2, 7, 'MH-HOM-003', 'Electric Kettle','1.7L stainless',        450000, 35);

INSERT INTO orders (id, tenant_id, user_id, status, total_cents, placed_at) VALUES
 (1, 1, 3, 'delivered', 2800000, now() - interval '40 days'),
 (2, 1, 4, 'paid',       560000, now() - interval '5 days'),
 (3, 1, 3, 'pending',    150000, now() - interval '1 day'),
 (4, 2, 6, 'shipped',    690000, now() - interval '3 days'),
 (5, 2, 7, 'delivered',  180000, now() - interval '20 days');

INSERT INTO order_items (tenant_id, order_id, product_id, quantity, unit_price_cents) VALUES
 (1, 1, 1, 1, 2500000), (1, 1, 2, 2, 150000),
 (1, 2, 3, 3,   80000), (1, 2, 4, 1, 320000),
 (1, 3, 2, 1,  150000),
 (2, 4, 5, 2,  120000), (2, 4, 8, 1, 450000),
 (2, 5, 7, 1,  180000);

INSERT INTO payments (tenant_id, order_id, method, status, amount_cents, provider_ref, paid_at) VALUES
 (1, 1, 'mpesa', 'paid', 2800000, 'MPESA-TOKEN-0001', now() - interval '40 days'),
 (1, 2, 'card',  'paid',  560000, 'CARD-TOKEN-0002',  now() - interval '5 days'),
 (2, 4, 'mpesa', 'paid',  690000, 'MPESA-TOKEN-0003', now() - interval '3 days'),
 (2, 5, 'card',  'paid',  180000, 'CARD-TOKEN-0004',  now() - interval '20 days');

-- Explicit ids were used above: move every identity sequence past them.
SELECT setval(pg_get_serial_sequence('tenants',     'id'), (SELECT max(id) FROM tenants));
SELECT setval(pg_get_serial_sequence('users',       'id'), (SELECT max(id) FROM users));
SELECT setval(pg_get_serial_sequence('categories',  'id'), (SELECT max(id) FROM categories));
SELECT setval(pg_get_serial_sequence('products',    'id'), (SELECT max(id) FROM products));
SELECT setval(pg_get_serial_sequence('orders',      'id'), (SELECT max(id) FROM orders));
