# Authentication email: password reset, email verification, password change

Branch `feature/auth-recovery-verification` (21 Oct 2026, merged 23 Oct); required verification since branch
`feature/verification-navigation` (23 Oct 2026, section 10; not merged or deployed). Local verification uses
**captured** mail only; the owner reports real registration emails arrive from the hosted API (section 8 is theirs).

## 1. What the person sees

**Forgot password** (sign-in › *Forgot password?*, under the password field):

1. The email field, filled in from sign-in. *Send code*. The answer is the same for every address: "If an account
   uses {email}, we've sent it an 8-digit code. It's valid for 10 minutes."
2. One code field: paste or one-time-code autofill, a numbers keyboard, always left to right (also in Arabic);
   Arabic-Indic and Eastern Arabic digits and words around a pasted code are accepted, leading zeros kept. *Resend code*
   shows its countdown; *Use a different email* goes back.
3. New password and its confirmation (show/hide, the rule beside them). *Set new password*.
4. Back to sign-in with the address filled in and "Your password was changed. Sign in with your new password…".
   A reset never signs anyone in.

States said in words: wrong code, expired code, too many tries (ask for a new code), wait N s, no connection ("the
server cannot be reached", never "wrong code"), "Email recovery isn't available yet" (before anything is promised,
when the server has no sender), an older server ("doesn't offer this yet", no retry). If the new password was sent
but no answer came back, the screen says the change could not be confirmed, offers *Go to sign in*, and never resends
by itself. Back goes to the email step (the code is spent once accepted). The authorization lives only in the screen;
after the app is closed the person asks for a fresh code.

**Change password** (Me › Account › *Password*): current password, new password, confirmation, password-manager
hints, show/hide. A warning that it signs out every device; a confirmation dialog. Disabled with a reason while the
account is unreachable. On success this phone signs out *non-destructively* and the sign-in screen shows the same
address: signing in again (same account) finds its local data, pending changes, open workout, drafts, timers and saved
run where they were. A different account stays strictly separate (unchanged). An unconfirmed answer says so, discards
nothing and does not retry; if the change did happen the next request is refused and the app asks to sign in.

**Verify email** (Me › Account › *Email*: the address and *Verified* / *Not verified*, from the server only, with the
deadline or "Syncing paused until verified" when that applies; a server from before verification shows no row). The
same code field. Verification proves ownership of the account's current address and changes nothing else (no password,
session or address change, no sign-in).

**Verification is required** (since branch `feature/verification-navigation`, 23 Oct 2026; section 10):

- **New accounts** verify before anything else: *Create account* → *Verify your email* (the code registration sent;
  Resend with the server's cooldown; *Check again*; *Sign out or use another account*; no Later, no Back) → coach
  setup → Today. A restart, an expired token or no connection brings a waiting account back to this step.
- **Accounts that existed unverified at the rollout** get **14 days** (persisted, server-owned) to verify. Today shows a
  compact notice with the real deadline and one *Verify*; Me shows the same. No popup, no bulk email.
- **After that deadline** the app stays usable on the phone (saved data, an open workout or run, timers, local saves),
  uploads wait with a notice, and verifying sends the waiting changes once. Signing in works and says what is needed.
- **Verified accounts** are unaffected.

## 2. API, storage, limits, sessions

| Route (`/api/v1`) | Body | Answers |
|---|---|---|
| `POST /auth/password-reset/request` | `email`, `language?` | 202 `{cooldownSeconds}` for **every** well-formed address; 400 `INVALID_EMAIL`; 429 `EMAIL_COOLDOWN` `{retryAfterSeconds}`; 503 `EMAIL_UNAVAILABLE` / `EMAIL_BUSY` |
| `POST /auth/password-reset/verify` | `email`, `code` | 200 `{resetToken, expiresAtUtc}`; 400 `INVALID_CODE` / `CODE_EXPIRED`; 429 `TOO_MANY_ATTEMPTS` |
| `POST /auth/password-reset/complete` | `resetToken`, `newPassword`, `language?` | 204; 400 `INVALID_RESET_TOKEN` / `WEAK_PASSWORD` / `PASSWORD_TOO_LONG` |
| `POST /account/email-verification/request` † | `language?` | 202; 409 `ALREADY_VERIFIED`; 429 / 503 as above |
| `POST /account/email-verification/confirm` † | `code` | 200 profile; 400 / 429 as above |
| `POST /account/password` † | `currentPassword`, `newPassword`, `language?` | 204; 400 `WRONG_PASSWORD` / `WEAK_PASSWORD` / `PASSWORD_TOO_LONG` |

† signed in. `POST /auth/register` takes an optional `language`. `ProfileDto` gains `emailVerified` (server-owned;
`PUT /me` never reads it, so an older app neither clears nor grants it). Capabilities: `account.security` (these routes
exist) and `account.email` (a sender is configured; absent = "not available yet" in the app).

**Migration `AddAccountEmail`** (additive only): `Users.EmailVerifiedAtUtc` (null for everyone), `RefreshTokens.SecurityStamp`
(null on old rows), tables `AuthChallenges` and `MailMessages`, both cascading with the account (erasure removes codes
and unsent mail). Hosted deploy needs the usual pre-deploy `migrate`.

**Codes.** 8 digits = HMAC-SHA256(`Email:CodeSecret`, challenge id) mod 10^8, leading zeros kept. Nothing about a code
is stored (no raw code, no hash an attacker could enumerate offline without the secret); it is re-derived to send and
to check (constant-time). Addresses in `AuthChallenges` are a keyed hash. Each challenge has a purpose
(`password-reset` / `email-verification`), the account (null for an unknown address), the account's security stamp,
expiry, attempts, sends, verified/consumed/invalidated times and, for a reset, the SHA-256 of the one-time reset
authorization (32 random bytes, 10 minutes, accepted only by `/password-reset/complete`; it is not a JWT and opens no
other route).

| Limit (initial product setting, configurable) | Value |
|---|---|
| Code lifetime / attempts per code | 10 min / 5 (the 5th wrong one locks it) |
| Cooldown between sends to one address / sends per address per hour | 60 s / 5 |
| Reset authorization lifetime | 10 min, single use |
| Emailed-code routes per IP (in-memory, per instance) | 60 per hour |
| Global delivery budget (all mail queued in the last hour) | 200, then `EMAIL_BUSY` for every address |

Per-address cooldowns, hourly counts and attempts live in PostgreSQL, so they survive restarts and hold across
instances; a request takes a transaction-scoped advisory lock on its address, so parallel requests cannot race them.

**Indistinguishable requests.** An unknown address gets a challenge row too (no owner, no mail) with the same cooldown,
hourly limit, attempt count and answers; a guess against it always fails and locks after 5 exactly like a real one. The
request only writes rows; sending happens later in the worker, so provider latency is not in the response.

**Resend policy.** Asking again while a code is live (and has 2+ minutes left) re-sends the **same** code and keeps its
attempt count. Nobody can void someone else's live code by asking, or reset its attempts. A new code replaces older
unused ones only when the live one has expired, is locked or nearly expired. Known nuisance (documented, bounded): five
wrong guesses lock a person's current code; they ask again (cooldown and hourly limit apply).

**Session invalidation.** Reset and change go through one method: a conditional update on the security stamp the caller
read (two changes cannot both win), a new stamp (every access token fails the existing stamp validation on its next
request), every refresh token revoked (refresh recovery has nothing to recover), every open code voided, their unsent
mail cancelled, a *password changed* notice queued, all in one transaction. Refresh tokens now carry the stamp they were
issued under and a refresh under another stamp is refused, which closes the race where a refresh that started before
the reset inserts its replacement after it. Requesting a code alone changes nothing: no session, password or account
state.

**Password policy** (one rule for registration, reset and change; existing passwords keep signing in, no forced
migration, hasher unchanged): 15 to 256 characters counted as Unicode code points, any characters, no composition rules,
never truncated. 15 because NIST SP 800-63B rev. 4 §3.1.1.2 and the OWASP Authentication Cheat Sheet (both read 21 Oct
2026) set 15 as the minimum for a password that is the only factor, which it is here; both ask to allow at least 64.
The previous minimum was 8. Not done: a breached-password blocklist and NFC normalization (would change how existing
non-normalized passwords verify).

**Delivery.** `MailMessages` is the outbox: one row per message, no address or body (the recipient is the account's
current address at send time). `MailWorker` (hosted, registered only when a provider is configured) claims due rows with
`FOR UPDATE SKIP LOCKED` behind a lease, re-checks that the code is still live (never sends a used, voided or expired
code), renders, and sends with `Idempotency-Key: gohard-mail-<row id>`. Retries (network error, timeout, 429, 5xx, 409
`concurrent_idempotent_requests`) back off 20 s … 5 min, at most 5 attempts, and stop at the message's expiry (the code's
expiry; a day for the notice). A retry carries the same key and identical content, so Resend sends it at most once.
Other errors fail the message at once. Logs carry the message id, kind, attempt, outcome and Resend's status and error
name: never an address, code, authorization, password, token, key or body.

**Email content.** English, French and Arabic (`language` from the app; `fr*` → French, `ar*` → Arabic, anything else
or nothing → English). Plain text and simple HTML: GoHard named, the purpose, the expiry, "if you didn't request this";
no user-supplied text, links, remote images or tracking pixels; Arabic is `dir="rtl"` with the code `dir="ltr"` (an
isolate in the text part). Subjects: *Your GoHard password reset code*, *Verify your GoHard email*, *Your GoHard password
was changed* (and their French and Arabic versions in `MailDelivery.cs`).

## 3. Provider and configuration

Provider: **Resend**, HTTPS Send Email API (one adapter, `ResendSender`). The project had no transactional sender.

| Variable (Railway, service of project devoted-caring) | Value |
|---|---|
| `GOHARD_Email__Provider` | `Resend` (empty or unset = no email; the routes answer `EMAIL_UNAVAILABLE`) |
| `GOHARD_Email__ResendApiKey` | the restricted sending key from Resend (secret) |
| `GOHARD_Email__FromAddress` | `noreply@auth.lesdeserts.ca` (after the domain is verified) |
| `GOHARD_Email__FromName` | `GoHard` (default) |
| `GOHARD_Email__ReplyTo` | leave **unset** unless you name an address that really receives replies |
| `GOHARD_Email__CodeSecret` | 48 random bytes, base64 (secret; at least 32 characters) |
| optional | `GOHARD_Email__CodeMinutes` 10, `__MaxAttempts` 5, `__CooldownSeconds` 60, `__MaxSendsPerHour` 5, `__DeliveryBudgetPerHour` 200, `__ResetGrantMinutes` 10, `__PerIpPerHour` 60, `__MaxDeliveryAttempts` 5, `__SendTimeoutSeconds` 15 |

With `Provider=Resend`, a missing key, an invalid From address or a short `CodeSecret` stops the API at startup with a
message naming `Email:` (it never falls back to printing codes). `Provider=Capture` is refused outside
Development/Testing. Nothing about email is in Flutter, in a committed file or in any response.

## 4. Setup checklist (owner)

Do these in order. Copy every DNS value from **your** Resend dashboard; the examples below only show the shape.

1. **Create the sending service.** Sign up at resend.com (check the current plan limits yourself; transactional volume
   here is small). This is a sending service, not a mailbox.
2. **Add the sending subdomain.** Resend › Domains › *Add domain* › `auth.lesdeserts.ca` (choose a region).
3. **Copy its DNS records into Cloudflare** (lesdeserts.ca zone › DNS › Records › *Add record*), each exactly as Resend
   shows it, *DNS only* (grey cloud). With Resend they normally have this shape, all **under `auth`**:
   - MX, name `send.auth`, the mail server Resend shows (e.g. `feedback-smtp.<region>.amazonses.com`), priority 10;
   - TXT (SPF), name `send.auth`, the value Resend shows (e.g. `v=spf1 include:amazonses.com ~all`);
   - TXT (DKIM), name `resend._domainkey.auth`, the long `p=…` value Resend shows.
   If Resend shows different names or values, use Resend's.
4. **Leave the root domain alone.** Do not edit or delete the existing records for `lesdeserts.ca` itself: the website
   records, the MX records Cloudflare Email Routing created for `contact@lesdeserts.ca`, the root SPF TXT, any root DKIM
   and any `_dmarc.lesdeserts.ca`. The new records are all on `send.auth` / `resend._domainkey.auth` and do not touch
   them. Email Routing (receiving) and Resend (sending) are separate; Email Routing gives no sending access.
5. **DMARC** (optional). If `_dmarc.lesdeserts.ca` exists, it already covers the subdomain (its `sp=` tag, or `p=`);
   leave it. If none exists and you want one for the subdomain only: TXT `_dmarc.auth`, `v=DMARC1; p=none;` to start.
   Never replace an existing DMARC record blindly.
6. **Verify.** Resend › the domain › *Verify DNS records*; wait for **Verified** (minutes, sometimes longer).
7. **Tracking off.** In the domain's settings in Resend, keep **open tracking and click tracking off** (they are
   per-domain; GoHard sends no links or pixels and relies on them being off).
8. **Restricted key.** Resend › API keys › *Create*: permission **Sending access**, domain **auth.lesdeserts.ca** only.
   It is shown once: put it straight into your password manager. Never paste it into a chat, a file or a commit.
9. **Code secret.** In PowerShell on your own computer:
   `$b = New-Object byte[] 48; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)`
   Store it in the password manager as well. Keep it stable: changing it voids only codes from the last 10 minutes
   (safe to rotate any time; there is nothing encrypted to migrate).
10. **Railway, later** (after this branch is merged and deployed with its migration): devoted-caring › the API
    service › Variables › add **all** variables of section 3 in one go (a partial set with `Provider=Resend` stops the
    API, on purpose). Railway redeploys. `GET /api/v1/capabilities` then lists `account.email`.
11. **Key rotation**: create a new key, replace `GOHARD_Email__ResendApiKey`, let it redeploy, delete the old key.

## 5. The From address and replies

`noreply@auth.lesdeserts.ca` does **not** need a mailbox to be a From address: once `auth.lesdeserts.ca` is verified in
Resend, any address on it can send. A verified sender does not receive anything, though. Replies to it go nowhere useful
unless you set up receiving separately, for example `GOHARD_Email__ReplyTo=contact@lesdeserts.ca` (already routed by
Cloudflare) once you confirm that is where replies should go, or Cloudflare Email Routing for the subdomain. Until you
decide, Reply-To stays unset and the messages say they are automatic.

## 6. Keeping Cloudflare routing and secrets safe

- Add only the records Resend lists, under `auth`; change nothing at the root (step 4). Before saving, check that the
  record list for `lesdeserts.ca` (no prefix) is exactly as before.
- Secrets (`ResendApiKey`, `CodeSecret`) live in Railway variables and your password manager only. The tracked
  `appsettings.json` has no Email section; local secrets would go in the untracked `appsettings.Local.json`.
- Railway: variables are per service; give nobody else project access just for this.

## 7. Local capture (development only)

`Email:Provider=Capture` keeps messages in the API's memory instead of sending them and adds `GET /dev/mail/latest?to=`
(subject, text, code). It is refused at startup outside Development/Testing (`AccountEmailService.cs`, test
`Without_a_sender_every_address_hears_unavailable_and_capture_is_refused_in_production`); the route exists only with
Capture. Run a capture API on a disposable database, loopback only:

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'; $env:GOHARD_Email__Provider = 'Capture'
$env:GOHARD_ConnectionStrings__Default = '<the local connection string with Database=<disposable db>>'
dotnet run --project api/src/GoHard.Api -- migrate seed-catalog
dotnet run --project api/src/GoHard.Api --no-build -- --urls http://127.0.0.1:5136
scripts\test-android.ps1 -Only journey_auth_test -ApiBase http://10.0.2.2:5136
```

Without `CodeSecret` a capture API makes a random one per process. Captured mail is never real delivery.

## 8. Owner checklist: real email and iPhone

Only after section 4 and a deploy, with addresses **you** choose (never addresses found in logs or the database):

1. `GET https://gohardrebuild-production.up.railway.app/api/v1/capabilities` lists `account.security` and `account.email`.
2. New test account on your iPhone (unsigned IPA via Sideloadly) with an address you read: the app goes straight to
   *Verify your email* (no Today first). The email arrives (check spam), from "GoHard <noreply@auth.lesdeserts.ca>", in
   the app's language; force-quit and reopen: still the verification step; the code autofills or pastes; then coach
   setup, then Today; Me shows *Verified*.
3. Me › *Password*: change it; you are signed out; sign in with the new one; your data is there. A *password changed*
   email arrives.
4. Sign out › *Forgot password?*: the code arrives; set a new password; the old one is refused; the new one works.
5. In French and in Arabic once each (Me › Language): the email is in that language; the Arabic one reads right to left
   with the code left to right.
6. Resend › Emails: each message is *Delivered*, no opens/clicks tracked. Then delete the test account (Me › Delete
   account).

## 9. Before public testing / launch

- Configure and verify real sending (sections 4 and 8); until then the app says recovery isn't available.
- **Verification enforcement**: done (section 10); a public launch still needs the real-email checks of section 8.
- Signing and distribution: this build is an unsigned IPA (Sideloadly); TestFlight/App Store needs the paid Apple
  Developer Program and a separate signing step.
- Consider: a breached-password check, a second factor, an email-change flow (not built: the sign-in address cannot be
  changed), per-account sign-in attempt limits (sign-in is limited per IP only), naming Resend as a processor in the
  privacy notice, and watching DMARC reports.
- The IP limit is per API instance (in memory); per-address limits and attempts are in the database.

## 10. Required verification: boundary, migration, rollout

**API boundary.** One rule (`AccountAccess.MayUseData`, read from the database on every request): verified, or
unverified inside a legacy grace period. Every `RequireAuthorization()` route needs it (the default policy); a
signed-in account that fails it gets **403 `{"code":"EMAIL_VERIFICATION_REQUIRED"}`**, never 401. Still open to it,
by name (policy `account`): `GET /me`, `POST /auth/logout`, `DELETE /account`, `POST /account/email-verification/request`,
`POST /account/email-verification/confirm`, `POST /account/password`. Public: health, `/capabilities`, register,
login, refresh, password reset. Invalid, expired or revoked tokens keep their 401. Login and refresh still answer a
waiting account (with the profile that says what is needed). `VerificationPolicyTests` walks every mapped signed-in route
with a waiting account's token and expects exactly that list to be open.

**Contract.** `ProfileDto` gains `verificationRequired` (data refused now) and `verificationDueAtUtc` (a legacy
account's deadline; null otherwise). Nothing a client sends can set them or `emailVerified`. `contractVersion` and the
default `Compatibility:MinimumClientContract` are now **2**: an app from before this branch shows the existing *Update
GoHard* screen (its outbox kept) instead of meeting 403s it cannot explain.

**Registration without a sender** (`Email:Provider` empty): `POST /auth/register` answers 503 `EMAIL_UNAVAILABLE`
before any row is written ("New accounts can't be created right now…"). Verification is never silently turned off. An
account created while the provider later fails keeps its pending state; *Resend* and the outbox retries apply.

**Migration `AddVerificationGrace`** (additive): `Users.VerificationGraceFromUtc`, set **once, by the migration**, to
the database's `now()` on every account unverified at that moment. Deadline = that + `Auth:VerificationGraceDays`
(**14**, configurable: `GOHARD_Auth__VerificationGraceDays`; changing it moves every legacy deadline alike, it never
grants verification). New accounts never get the column, whichever instance creates them (an old instance during the
deploy overlap included): null + unverified = verify now. Logins, refreshes, resends, restarts and redeploys never write
it. **Rollback**: rolling back *code* is safe (old code ignores the column; it then also stops enforcing). Do **not** run
the migration's `Down`: re-applying `Up` would start every grace period again from that day.

**Exact order (owner, after approval):**
1. Check Railway has the Email variables (section 3) and `GET /api/v1/capabilities` lists `account.email`. Without a
   sender, sign-up is refused (on purpose).
2. Merge; Railway's pre-deploy runs `migrate seed-catalog` (13 migrations) and the cutoff is recorded then.
3. Install the new IPA (contract 2). Older installs see *Update GoHard* from this deploy on.
4. Leave `Compatibility:MinimumClientContract` unset (default 2). Nothing else changes; no session is invalidated.

**On the phone.** One local-only, per-account record (`account_access`) from server answers only (sign-in, `/me`,
snapshot, confirm); no code or password is stored. A 403 `EMAIL_VERIFICATION_REQUIRED` pauses the outbox (commands stay
pending, untouched, same operation ids, no retry counted) and asks `/me`; the next successful pull or a confirmation
resumes it. No answer never changes the record. Local dev: `scripts\start-api.ps1` now uses the capture mailbox unless
`-Lan` (then registration needs a real sender).

## Design note: required verification (written before implementation, 23 Oct 2026)

- **Eligibility policy.** One rule, `AccountAccess.MayUseData`: verified, or an unverified account still inside a legacy
  grace period. The JWT handler already reads the account row for every request (stamp check); it now also reads
  `EmailVerifiedAtUtc` and `VerificationGraceFromUtc` and adds a request-only `gohard.eligible` claim when the rule
  holds (never issued in a token, so no old token or client field can carry it). The **default** authorization policy
  requires that claim, so every `RequireAuthorization()` route is covered, including routes added later. A small
  `account` policy (signed in only) is used by name for the exempt list: `GET /me`, `POST /auth/logout`,
  `DELETE /account`, `POST /account/email-verification/{request,confirm}`, `POST /account/password`. A signed-in but
  ineligible caller gets **403 `EMAIL_VERIFICATION_REQUIRED`** (never 401, so no refresh/sign-out loop).
- **Migration / cutoff.** Additive column `Users.VerificationGraceFromUtc`. The migration sets it to the migration's
  own `now()` for every account that is unverified at that moment; nothing else ever writes it. Deadline =
  that instant + `Auth:VerificationGraceDays` (14). New accounts never get it (null + unverified = required now).
  Accounts created by an old instance after the migration ran are new accounts (required). Redeploys and restarts do
  not re-run the migration, so the deadline never moves; do not run its `Down` (it would forget the cutoff).
- **Account transitions.** Register (refused with 503 `EMAIL_UNAVAILABLE` when no sender is configured, before any
  row is written) → session + profile with `verificationRequired: true` → the app's gate (the shared verify form) →
  confirm → the profile says eligible → setup → Today. Login and refresh still work for an ineligible account (they
  answer with the profile that explains what is required). `ProfileDto` gains `verificationRequired` and
  `verificationDueAtUtc` (additive). `minimumClientContract` and the contract become 2, so an older app shows the
  existing update screen instead of an endless sync error.
- **Offline preservation.** The app keeps one local-only, account-scoped record (`account_access`) written only from
  server answers (register/login, `/me`, snapshot, confirm). A 403 `EMAIL_VERIFICATION_REQUIRED` pauses the outbox
  (commands stay pending, untouched, same operation ids) and refreshes that record from `/me`. A new account's gate
  survives restarts and offline; a legacy account past its deadline keeps its shell, its recorder, timers and local
  saves, with uploads paused and a notice that opens the same form. No code or password is stored.
- **Navigation.** Eat: one full-width History & trends panel under the day's summary (the old text link removed).
  Train › Workouts: one Recent workouts section (latest 3) with *View all history* in its header; the separate
  History card goes. Progress: its Recent workouts list and Workout history card go.

## Design note (written before implementation)

Endpoints, state, races, delivery and compatibility as above. Choices made then and kept: a derived code instead of a
stored verifier or an encrypted queue payload (nothing recoverable at rest; the worker re-derives it); unknown addresses
get owner-less challenges so every outward behaviour matches; a live code is re-sent, not replaced; a database outbox
and one hosted worker instead of a broker; refresh tokens bound to the security stamp to close the reset/refresh race.
