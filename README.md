# Crown Business Docs

Free offline-first Android business document generator, previously ARODesk.

Create invoices, receipts, quotations, proforma invoices, purchase orders, delivery notes, credit notes, debit notes, payment vouchers, account statements and business letters. Preview A4 PDFs, save editable records, share and print. No account, product catalogue, inventory, POS, Supabase or payment integration is required. All generation and record storage run on-device regardless of connectivity; sharing to an online service is a user choice. There is no automatic cloud sync.

Storage: compact JSON in local SharedPreferences using new versioned keys, with PDF regeneration on demand. This is not cloud backup. The Android package ID and existing signing configuration are preserved for upgrades. Legacy account-scoped records are not imported into the new anonymous workspace or deleted. The previous code is preserved on archive/arodesk-pos-before-docs.

Development: flutter pub get; flutter analyze --no-fatal-infos; flutter test.
Android release: the workflow tests, builds and publishes signed APK and AAB using existing repository signing secrets. No Supabase credentials are required.
