# Requirements Summary: ShopStream (Multi-Tenant E-Commerce Backend)

**Track chosen:** Multi-tenant online store platform (SaaS). Many independent shops
(tenants) share one PostgreSQL database; each shop sells products to its own customers.

## 1. Problem & Goals
Small merchants need an inexpensive hosted store backend. ShopStream must keep every
merchant's data strictly isolated, handle bursts of shopping traffic (carts, product
views), and give owners reliable sales analytics.

## 2. Users / Roles
| Role | Needs |
|------|-------|
| Shop owner | Manage catalogue, see orders and revenue reports |
| Staff | Update products, fulfil orders |
| Customer | Browse, build a cart, check out, view own order history |
| Platform admin (DBA) | Migrations, backups, monitoring (never used by the app) |

## 3. Functional Requirements
- FR1 Tenants (shops) with users in roles owner / staff / customer.
- FR2 Hierarchical product categories (e.g. Electronics -> Accessories).
- FR3 Products with SKU (unique per shop), price (integer cents), stock, active flag.
- FR4 Shopping cart that is fast, temporary and survives page reloads.
- FR5 Checkout converts a cart into an order + order items + payment record.
- FR6 Order lifecycle: pending -> paid -> shipped -> delivered (or cancelled).
- FR7 Payments store a provider token/reference only, never card numbers.
- FR8 Audit trail of every change to users, products, orders, payments.
- FR9 Product search by partial name; customer order history; top-seller and
  monthly revenue reports.
- FR10 Behaviour/event tracking (product views, add-to-cart) at high write volume.

## 4. Non-Functional Requirements
| Area | Requirement |
|------|-------------|
| Isolation | A tenant must never read or write another tenant's rows (RLS + composite FKs) |
| Security | Least-privilege roles, hashed passwords (bcrypt), parameterized SQL only |
| Performance | Order history < 50 ms, search < 100 ms, tenant reports < 1 s at 300k orders |
| Recoverability | Daily `pg_dump -Fc`, tested restore, RPO 24h |
| Repeatability | Empty database -> full schema + demo data with `flyway clean migrate` |
| Auditability | Who/what/when for critical tables, tamper-resistant from the app role |

## 5. Data Volume Assumptions (drives index choices)
- 2 demo tenants -> scaled to 2 tenants x 10k customers x 15 orders = **300k orders**, ~900k items
- Read-heavy catalogue; write-heavy carts and events.

## 6. Why PostgreSQL + Redis + MongoDB
- **PostgreSQL**: transactional core (orders, money, stock, tenancy, RLS, audit).
- **Redis**: carts and hot-product cache (TTL, atomic hash ops, sub-ms).
- **MongoDB**: schema-flexible, high-volume event ingestion buffer with TTL.
See `docs/03_nosql_justification.md`.

## 7. Out of Scope
Payment gateway integration, shipping, front-end UI.
