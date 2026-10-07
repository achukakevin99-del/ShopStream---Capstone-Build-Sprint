# ShopStream Capstone - Walkthrough (8-10 min)

> One slide per `---`. Speaker notes follow each slide. Paste into Marp/Google Slides/PowerPoint.

## 1. Title
**ShopStream: a secure, multi-tenant e-commerce database**
Your name - PLP Capstone Build Sprint
*Notes:* One sentence: many shops share one database, safely and fast.

---
## 2. Problem & requirements
- Isolated data per shop - fast carts - reliable reports - recoverable
- Roles: owner, staff, customer, DBA
*Notes:* Refer to docs/01_requirements.md; stress isolation as the #1 requirement.

---
## 3. ER design
Show `er_diagram.dbml` export. 8 tables, `tenant_id` everywhere, composite FKs.
*Notes:* Cardinalities: tenant 1:N everything; order 1:N items; products N:M orders via order_items. Mention the design review feedback you received.

---
## 4. Schema as migrations
V1 tables - V2 indexes - V3 audit - V4 RLS - V5 seed. `flyway clean migrate` from empty.
*Notes:* Demo it live. Explain repeatability and why seed data is separate from bulk data.

---
## 5. Architecture
```
App -> PostgreSQL (orders, money, tenancy)
    -> Redis (cart, cache)
    -> MongoDB (events)
```
*Notes:* Checkout is the only bridge, one transaction. Redis/Mongo are not systems of record.

---
## 6. Why Redis & MongoDB
Cart = temporary + hot -> Redis. Events = flexible + high volume + expendable -> Mongo.
*Notes:* Use the table in docs/03_nosql_justification.md.

---
## 7. Optimization evidence
Table of Q1-Q4: before ms -> after ms, scan type change (from YOUR optimization_report.md).
*Notes:* Pick the most dramatic one and show both plans. Explain sargability for Q4 and trigram for Q3.

---
## 8. Security
Roles - RLS - bcrypt - audit - parameterized SQL. Show `verify_security.sh` output.
*Notes:* Live: tenant 2 cannot see tenant 1's orders; app cannot delete audit rows.

---
## 9. Backup & recovery
`pg_dump -Fc` daily; `restore_test.sh` proves it; RPO 24h.
*Notes:* A backup never restored is a hope, not a backup.

---
## 10. Lessons & next steps
Replication/PITR, TLS, customer-level RLS, partitioning `orders` by month.
