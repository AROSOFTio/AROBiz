# AROBiz → multi-business SaaS: production audit & implementation plan

Status: **NOT READY FOR STORE SUBMISSION**. This plan does not imply a completed build or security audit. Naming is provisional pending owner approval and trademark/app-store clearance.

## Verified implementation (main @ 2a6689c)
- Flutter Android/iOS/Web/Desktop project; AROBill application title.
- Screens: login, registration, dashboard, create invoice, invoice list/preview, settings.
- DocumentType enum: invoice, quotation, receipt. Invoice PDF/print/share packages installed.
- Local SQLite database for user authentication, SharedPreferences for business profiles/invoices.
- Account categories include retail, salon, hotel and services.

## Blocking deficiencies
1. SharedPreferences keys `business_profile` and `invoices` are **global per installation**, not partitioned by authenticated user/tenant; login reuses currentProfile logo and services, logout only clears an in-memory profile. Account crossover risk.
2. `is_logged_in` is a single local boolean, no server session. No email/phone verification, recovery, or server-side account.
3. SHA256(password) without salt/work factor in local SQLite. Replace with managed cloud identity; never synchronize password hashes.
4. No cloud backend / tenant-scoped server authorization, therefore not SaaS and no multi-device sync.
5. Android applicationId/namespace `com.example.arosoft`, and release signing uses debug keys. Not eligible for trustworthy Play release.
6. Document model lacks tenant ID, due dates, payment allocations, currency, explicit status, revision/conversion lineage, audit timestamps. Invoice numbers cannot safely be assigned across devices as-is.
7. README and pubspec description are starter Flutter text. No verified automated build/test and no signed AAB.

## Target architecture
- Flutter single codebase; Android launch first; iOS support retained.
- Managed auth (e.g. Supabase Auth) and PostgreSQL business-scoped tables. Business memberships and role permissions enforced in the **database with RLS**, not only filtered in app code.
- Core entities: users, businesses, memberships, branding, contacts, catalog_items, documents, document_lines, payments, payment_allocations, counters, audit_events, sync_outbox.
- Every tenant-owned table has `business_id`. RLS checks authenticated membership for read/write. Use server-side privileged endpoints for subscription/admin operations and immutable issued document numbering.
- Per-business locally encrypted SQLite with offline-created UUIDs, outbox queue, retries/idempotency and explicit sync/error indicator. Switching or signing out wipes cached decrypted context, closes db, and reopens only the selected business. Do not move existing global SharedPreferences content into a tenant without explicit ownership verification.
- PDF document templates including logo, color, legal address, contact, taxes, terms, currency, payment details and QR where appropriate.
- Document lifecycle: quotation -> accepted -> invoice -> partial/fully paid -> receipt; credit notes for adjustments; pro-forma and delivery notes later.
- Document IDs globally UUID; visible numbers assigned with server-side tenant sequence when online (offline document can have a **draft/provisional** number, never a final irreversible invoice number).
- Offline access after first successful online sign-in; new signup and cloud account recovery require connection.
- Automated integration tests: two businesses cannot see or modify each other's data even by forged API request; logout/account switch; offline queue/reconnect conflict; duplicate payments; PDF total calculations.
- Backup/export, deletion requests, privacy policy, data-safety declarations, encryption at rest/in transit, role review, abuse protection, observability and incident response.

## Release gates
1. Confirm brand/product name and unique Android application ID before publishing.
2. Replace unsafe session and storage, migrate with explicit safeguards.
3. Implement backend schema/migrations and RLS tests.
4. Build functional cross-device sync and offline operation; test device switching and conflict recovery.
5. Verify Android Gradle target SDK/permissions, configure upload keystore and Play App Signing (never commit keys).
6. Run Flutter analyze, unit/widget/integration tests, device QA and release smoke tests.
7. Produce signed release AAB, upload to internal testing, confirm Play Console prelaunch report and policy/privacy compliance.
8. Once stable, generate app icon, feature graphic and genuine screenshots taken from the tested build; prepare iOS signing later.

## Current code and data caution
Existing user data is stored on-device. Do not delete or reinstall app before export and verified migration. No product renaming, backend or release configuration is applied by this planning document.
