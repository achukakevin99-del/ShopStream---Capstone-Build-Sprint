-- Run as capstone_app:  psql -U capstone_app -h localhost capstone -f tests/rls_demo.sql
\echo '--- no tenant set: expect 0 rows'
SELECT count(*) FROM orders;
\echo '--- tenant 1'
SELECT set_config('app.tenant_id', '1', false);
SELECT id, user_id, status FROM orders ORDER BY id;
\echo '--- tenant 2'
SELECT set_config('app.tenant_id', '2', false);
SELECT id, user_id, status FROM orders ORDER BY id;
\echo '--- tenant 2 tries to write into tenant 1: expect ERROR'
INSERT INTO categories (tenant_id, name) VALUES (1, 'intruder');
