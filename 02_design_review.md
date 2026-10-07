# Day 1 Design Review (do this BEFORE running any SQL)

Send `er_diagram.dbml` (dbdiagram.io link or PNG export) to a mentor/peer and record the feedback here.

## Review checklist
- [ ] Every table has a primary key
- [ ] Every relationship has a stated cardinality (see `er_diagram.mmd`)
- [ ] Every tenant-owned table carries `tenant_id`
- [ ] Money stored as integer cents (no floats)
- [ ] Sensitive data (passwords, payment tokens) identified
- [ ] Many-to-many relationships resolved with a junction table (orders <-> products via order_items)

## Design decisions to defend
1. **Composite foreign keys `(tenant_id, x_id)`** - the database itself rejects an order pointing at another shop's user or product.
2. **Price snapshot in `order_items.unit_price_cents`** - later price changes must not rewrite history.
3. **`audit_log` is generic JSONB** - one table and one trigger function cover all critical tables.
4. **Payments hold a gateway reference only** - keeps card data out of scope (PCI).

## Feedback received
| Reviewer | Date | Comment | Action taken |
|----------|------|---------|--------------|
|          |      |         |              |
