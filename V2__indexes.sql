-- V2: indexes. Baseline FK/lookup indexes first, then the four "optimization"
-- indexes proven in optimization/ (the run script drops and recreates them to
-- capture BEFORE/AFTER plans).

-- Baseline
CREATE INDEX idx_products_tenant_category ON products (tenant_id, category_id);
CREATE INDEX idx_order_items_order        ON order_items (order_id);
CREATE INDEX idx_payments_order           ON payments (order_id);
CREATE INDEX idx_audit_lookup             ON audit_log (tenant_id, table_name, record_id, changed_at DESC);

-- Optimization indexes
CREATE INDEX idx_orders_tenant_placed ON orders (tenant_id, placed_at DESC);   -- Q1, Q4
CREATE INDEX idx_orders_user_placed   ON orders (user_id, placed_at DESC);     -- Q2
CREATE INDEX idx_products_name_trgm   ON products USING gin (name gin_trgm_ops); -- Q3
CREATE INDEX idx_order_items_product  ON order_items (product_id);             -- product sales lookups
