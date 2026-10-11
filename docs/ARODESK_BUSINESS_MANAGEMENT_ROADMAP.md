# ARODesk: Modular Business Management Platform Roadmap

**Status:** Approved product direction; implementation backlog (not a claim that modules are built).  
**Product:** ARODesk, by AROSOFT Innovations Ltd  
**Existing foundation:** Flutter Android app, invoicing, local storage, Supabase authentication integration, GitHub Actions Android release.  
**Guiding rule:** Preserve and test the existing production app before introducing breaking changes.

## Vision and positioning
**ARODesk — One Platform. Every Business.**

Evolve ARODesk from invoicing into a multi-tenant, offline-capable business management and ERP platform for retail, wholesale, services, hospitality, manufacturing, construction, agriculture, education, healthcare, NGOs, and other enterprises. Do not pretend one generic form covers every industry's regulations or operations. Use a shared core plus opt-in industry packs.

## Non-negotiable platform principles
1. **Tenant isolation:** Every business has a unique tenant ID; all server-side tables and queries enforce tenant scoping through Supabase RLS, tested with two unrelated accounts. Never use client filtering as a security boundary.
2. **Roles and branches:** Owner, manager, accountant, salesperson, storekeeper, cashier, technician; custom permissions and branch access.
3. **Modularity:** SaaS admin can enable/disable modules and set per-tenant limits, trials, subscription plans, and feature flags without hiding or destroying data.
4. **Offline first:** Reliable local transaction queue, idempotent sync, explicit conflict resolution, retry logic, user-visible sync status, and safe backups. Financial and stock changes must not double-post.
5. **Accounting-grade audit trail:** Immutable ledger events, stock movement history, approval events, reversals and timestamps. Avoid deleting posted financial transactions.
6. **Flexible localization:** Tenant-selectable currency, taxes, timezone, date format, languages, and configurable numbering. Never hardcode UGX.
7. **Extensible builders:** Custom fields, forms, registers, reports and approval workflows with schema validation, authorization and versioning.
8. **Security and privacy:** No privileged Supabase service-role keys in the app, signed Android releases, encrypted local sensitive data where suitable, least privilege, migration tests, privacy policy and data deletion procedures.

## Shared master data
Tenant / organization; branch; warehouse; user / membership / role; customer and supplier; product or service; unit of measure; category; price list; tax rule; chart of accounts; payment method; currency; asset; project. All business records carry tenant and applicable branch identity.

## Modules and functional scope
| Module | Initial scope | Advanced scope |
| --- | --- | --- |
| Sales and POS | quotations, invoices, receipts, returns, discounts, payment splits | barcode POS, credit control, multi-location sales, loyalty |
| Inventory and warehousing | products, stock movements, opening balances, adjustments, transfers, reorder alerts | batch/lot/serial tracking, expiries, costing, stock counts |
| Purchases | vendors, purchase requisitions, orders, goods received, vendor bills, returns | approval thresholds, landed costs, supplier scorecards |
| Finance | cash/bank books, receivables, payables, expense tracking | double-entry GL, journals, reconciliations, P&L, balance sheet, VAT/tax reports |
| Manufacturing | bills of materials, raw material issue, production orders, finished stock receipt | routing, work centers, wastage, byproducts, WIP costing, quality |
| CRM | leads, contact history, opportunities, follow-up tasks | pipeline automations, campaigns |
| HR | staff profiles, attendance, leave | payroll, statutory rules by country |
| Projects and services | work orders, assignments, timesheets, contracts, service invoices | profitability and resource planning |
| Fixed assets | asset register, movements, maintenance | depreciation, verification, disposals |
| Analytics | dashboard and exportable sales/stock reports | configurable report builder and role-based BI |
| Administration | tenancy, branches, permissions, onboarding | SaaS subscriptions, trials, quotas and feature toggles |
| Integrations | CSV/Excel import/export, receipt PDF | payments, e-invoicing, API/webhooks, accounting integrations |

## Industry packs (enabled only when needed)
- **Retail/wholesale:** POS, price tiers, inventory, distributors, customer credit.
- **Restaurants/hotels:** menus, tables, kitchen orders, recipes, raw-material consumption, reservations and accommodation only when explicitly developed.
- **Manufacturing:** BOM, production, conversion of raw materials into finished goods, yield and costing.
- **Professional services:** projects, appointments, retainers, task/time billing.
- **Construction:** job costing, materials issues, site inventory, subcontractors.
- **Agriculture:** inputs, harvest batches, farm projects, produce traceability.
- **Schools/NGOs/healthcare:** specialized modules designed separately with regulatory/privacy review; not supported by default merely because platform is modular.

## Delivery milestones and acceptance criteria
### Phase 0 — Stabilize existing release (mandatory before architecture work)
- Install current signed APK; test real Supabase sign-up, email/phone verification, sign-in, logout and account recovery.
- Confirm the Android application ID, signing identity and version code appropriate for Play Console.
- Verify two test businesses never see each other's customers, invoices, profile or attachments.
- Inventory current SQLite/SharedPreferences data and define migration/rollback plan.
- Run Flutter tests, static analysis and clean Android AAB build with **no debug-signing fallback**.
- Prepare Play Console privacy policy, Data safety form, account deletion flow, screenshots and release notes.
**Exit:** repeatable green CI, device smoke test, privacy compliance review and working recovery path.

### Phase 1 — Business core MVP
- Tenant/org onboarding and branch management.
- Members/invitations, role permissions and RLS.
- Customer/supplier masters; product/service catalog, units and pricing.
- Stock movement engine and inventory locations.
- Sales invoices, POS basics, payments, purchases, expenses and operational dashboards.
- Offline-safe local storage and synchronization with transaction IDs.
**Exit:** a retail business can purchase, receive stock, sell, collect, track stock and report across two users with no cross-tenant leakage.

### Phase 2 — Financial controls
- Double-entry accounting framework and event-to-ledger posting.
- Cash/bank and accounts receivable/payable; audit trails; financial reports.
- Taxes as configurable rules, country-specific compliance explicitly validated.
**Exit:** sales/purchases balance in ledger and reconcile to stock, cash and receivables; reversals are auditable.

### Phase 3 — Industry extensions
- Manufacturing BOM → material issue → work order → finished goods → cost analysis.
- Restaurant recipe and kitchen workflows; services/project operations.
- Industry-specific data builders and templates.
**Exit:** end-to-end pilot for each launched industry with documented exception handling.

### Phase 4 — SaaS monetization and ecosystem
- SaaS operator console, per-tenant module toggles, trials, subscriptions, limits and billing.
- Custom fields/forms/registers/report builders with validations and permission inheritance.
- Integrations and secure developer APIs/webhooks.
**Exit:** operator can provision and manage tenants without code changes; module switches do not corrupt data.

## Architecture decision records to resolve before Phase 1
- Choose source of truth and sync pattern for offline writes; plan migrations from current SharedPreferences/SQLite data.
- Design PostgreSQL schema with tenant_id, branch_id, foreign keys, unique numbering and RLS policies.
- Establish document numbering, inventory valuation method (e.g., weighted average/FIFO), negative-stock policy, reversals and accounting event mapping.
- Decide pricing/tenant subscription model and feature-entitlement enforcement on the server.
- Finalize Play Store package name and upgrade/signing policy; never casually change applicationId after launch.

## Proposed repository organization (future, not created yet)
```
lib/
  core/             # auth, tenant context, sync, database, permissions, design system
  features/
    sales/
    inventory/
    purchasing/
    accounting/
    manufacturing/
    crm/
    hr/
    projects/
    assets/
    administration/
    reports/
docs/
  roadmap/
test/
  unit/
  integration/
```

## Next execution backlog (priority order)
- [ ] Release verification: APK real-device test, AAB Play Console preflight, sign-up/login and privacy checklist.
- [ ] Write current architecture and migration inventory.
- [ ] Tenant and membership schema plus RLS tests.
- [ ] Roles/permissions and branch model.
- [ ] Product and services master, supplier/customer masters.
- [ ] Stock movement model with concurrency and idempotency tests.
- [ ] Sales and purchase lifecycle.
- [ ] Offline sync proof of concept with conflict cases.
- [ ] Financial posting design and reconciliation test suite.
- [ ] First retail MVP pilot, then expand by sector.

## Release discipline
Develop major architecture on feature branches with migration tests; use pull requests and staged deployments. Keep the existing signed ARODesk release downloadable until a fully tested replacement is ready. Roadmap publication is planning work only and does not constitute implementation of its modules.
