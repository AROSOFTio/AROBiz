# ARODesk Android / Google Play release readiness

Status: **pre-submission candidate**, not yet approved by Google Play. This checklist must be completed inside the Google Play Console and on Android devices before requesting production review.

## Implemented and code-tested
- Android app signs and builds APK and AAB via GitHub Actions.
- Login and signup support email, first/middle/last name, business name, and country.
- Business records are tenant-scoped; access roles use Supabase RLS and RPC.
- New staff are required to change temporary passwords before business access.
- Settings and Account & Privacy offer an authenticated deletion request path.
- Web privacy and deletion instructions are publicly accessible at:
  https://github.com/AROSOFTio/AROBiz/blob/main/play-compliance/README.md
- Offline debtor repayments are encrypted on-device, have distinct pending status, and use idempotent server replay.
- Camera/gallery product photos are resized, JPEG-compressed and limited to 1 MB.
- Business accounting currency is displayed from the authoritative business record.

## Required before Play submission (not confirmed)
1. **Play Console → App content → Privacy policy:** submit public URL.
2. **Play Console → App content → Data safety:** accurately declare account names/emails, business contacts, customer names/addresses/phone numbers, payment and sales records, product images, and local/on-device data. Do not claim no data is collected.
3. **Play Console → Data deletion:** add the functioning public deletion URL. The linked public README includes a deletion request email; enable the dedicated GitHub Pages privacy site for a richer direct form.
4. **App access:** provide a functioning confirmed reviewer email/password for a seeded test tenant, with sales, products, debtor records and ability to explore the app; place credentials only in Play Console's private reviewer instructions, never in source control.
5. **Google Play listing:** images/screenshots, contact email, app category, age target, ads declaration, permissions declaration, Data safety form.
6. **Real-device testing:** new owner signup, email confirmation, logout/login, forced temporary password reset, password recovery email deep links, role checks, permanent data continuity, delete request, camera/photo picker, Android back navigation, A5 and 80 mm PDF, product image upload, currency consistency.
7. **Offline tests:** record debtor payment in airplane mode, force-close and reopen, reconnect, verify only one remote payment, clear pending flag and reconcile debt. Test two-device conflicts and rejected overpayments.
8. **Privacy review:** product images are currently public URLs. Do not upload sensitive photographs. Device-local standalone documents are not cloud-synced or encrypted; confirm whether the financial scope requires migration.
9. **Operational deletion:** verify deletion-request notification, identity verification, processing steps, and retention policy. A recorded request is not completed deletion.
10. **Crash reporting:** configure a privacy-conscious crash reporting workflow before asserting crash-free operation. Static analysis and successful AAB build do not replace tests.

## Pending infrastructure setup
GitHub Pages publish workflow is at `.github/workflows/privacy-pages.yml`. It currently fails until GitHub Pages is enabled at **Repository Settings → Pages → Build and deployment → Source: GitHub Actions**.

Once enabled, verify:
https://arosoftio.github.io/AROBiz/

Then, after verification, update the in-app policy/deletion links and Play Console deletion URL to the fully rendered page.

Never include production Supabase service-role secrets, user passwords, or reviewer credentials in this repository.
