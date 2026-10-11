# ARODesk — Email signup, verification and branded sender deployment

## Intended sender
- **From name:** ARODesk Security
- **From email:** arodesk@arosoftlabs.com
- A real mailbox must be created in the existing BillionMail instance.
- Use that mailbox's SMTP password in Supabase **Authentication > SMTP Settings** (not in Flutter, GitHub, or source control).

## Current cause of localhost confirmation redirects
Supabase authentication's **Site URL** or redirect allowlist contains a localhost development URL.
Changing the sender email does not fix a redirect.
New ARODesk signup requests `https://arosoftlabs.com/` as its `emailRedirectTo`, but Supabase must allow this target, otherwise it may use the configured Site URL.

## Operator actions in Supabase (production project)
1. Authentication > URL Configuration:
   - **Site URL:** `https://arosoftlabs.com/` (replace previous `http://localhost:3000`).
   - **Redirect URLs:** add `https://arosoftlabs.com/`.
2. Authentication > Providers > Email: ensure email verification is enabled and configured as desired.
3. Authentication > SMTP Settings (custom SMTP):
   - enable custom SMTP
   - **Sender email:** `arodesk@arosoftlabs.com`
   - **Sender name:** `ARODesk Security`
   - **Host:** use the hostname provided by your BillionMail SMTP configuration (typically `mail.arofi.net` on the currently observed mail network)
   - **Port:** 587 with STARTTLS (or 465 with implicit TLS if explicitly supported)
   - **Username:** `arodesk@arosoftlabs.com`
   - **Password:** the mailbox password you created in BillionMail.
4. Save settings. Send an actual confirmation email to a new test account, follow the URL and log in. Confirm sender name, TLS, and delivery. Inspect spam if needed.

## Operator actions in BillionMail
1. Log into your BillionMail admin console; ensure `arosoftlabs.com` exists as a mail domain.
2. Create mailbox `arodesk@arosoftlabs.com` using a strong random password. Record it in a password manager.
3. Confirm the domain's MX/SPF/DKIM/DMARC and use a valid SMTP TLS certificate.
4. Verify the account can send authenticated SMTP from the configured host and receive email.
5. Do not share the mailbox password, any Supabase `sb_secret_` API key, service-role credentials, or SMTP password in tickets, screenshots, commits or chat.

## User experience
In the registration screen, successful signup with pending email confirmation now opens a blocking **Registration successful** message explaining the check-email step; it returns to login after acknowledgement.

## Testing / exit criteria
- Brand-new user sees registration success dialog with email destination.
- Email comes from `ARODesk Security <arodesk@arosoftlabs.com>`.
- Confirmation link points to Supabase for verification then redirects to `https://arosoftlabs.com/`, not localhost.
- Confirmed user can log into ARODesk on Android.
- Unconfirmed user receives a clear prompt, not generic invalid password.
- Build Android APK/AAB on GitHub Actions, install the APK on a physical phone and repeat.
- For existing pending registrations, use fresh confirmation resend; already issued emails can still contain the old localhost URL.
- Supabase project authorization settings are external to the Flutter repository and must be verified there.

## Notes
The current homepage is not a custom confirmation UI. A future dedicated route on the actual live frontend can display a branded success message; do not add a URL redirect to a path that the live frontend does not serve.
