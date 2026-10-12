# Testing GoHard Dev on a physical iPhone (from Windows)

The iPhone build is made by GitHub Actions on a macOS runner and talks to a separate **testing** API on Railway
over HTTPS. Nothing here touches the original GoHard app, API or database, and nothing is sent to the App Store
or TestFlight.

| Piece | Value |
|---|---|
| App name on the phone | **GoHard Dev** |
| Bundle identifier | `com.gohard.rebuild.dev` (separate from the original app, so both can be installed) |
| Workflow | `.github/workflows/ios-dev-ipa.yml` (manual run) → artifact **GoHard-Dev-ipa** |
| API container | `api/Dockerfile`, `api/railway.json` |
| API check | `scripts\verify-api.ps1 -BaseUrl <url>` |
| Maps | The app has **no map**. Runs record GPS distance only, so no Google Maps key is used or needed |

## What is already done and verified locally

- The API builds as a container and runs the way Railway will run it: `DATABASE_URL` + `PORT`, migrations as an
  explicit pre-deploy step, `/health/ready` as the health check.
- Started against an unmigrated database it answers 503 and changes nothing; after the pre-deploy step it is Ready.
- **Migration guard:** `migrate` refuses any database that already has tables but is not this project's (tested
  against a database holding someone else's `Users` table: refused, table untouched). Pointing it at the previous
  production database by mistake cannot alter it.
- `scripts\verify-api.ps1` passes against the container and the local API (readiness, contract compatibility,
  registration, sign-in, wrong password, token required, idempotent save, catalog, cleanup).
- 58 API tests and 64 Flutter tests pass; five Android device journeys pass against the local API.

Not yet verified, because it needs your accounts: the Railway deployment itself, and any iOS build (this app has
never been compiled for iOS).

## Step 1 — Put this workspace on GitHub

Create a **new private repository** (do not reuse the original app's repository) and push `C:\dev\GoHardRebuild`:

```powershell
cd C:\dev\GoHardRebuild
git remote add origin https://github.com/<you>/<new-repo>.git
git push -u origin main
```

## Step 2 — Create the Railway testing environment

In the Railway dashboard, in your existing account:

1. **New Project → Deploy from GitHub repo →** the new repository. Name the project e.g. `gohard-rebuild-testing`.
   Do **not** add this service to the project that holds the original production API.
2. Open the new service → **Settings → Source → Root Directory:** `api`. Railway then uses `api/railway.json`
   (Dockerfile build, pre-deploy migration, health check).
3. In the project: **Create → Database → Add PostgreSQL.** This is a brand-new, empty database inside this project.
4. Service → **Variables**, add exactly two:
   - `DATABASE_URL` = `${{Postgres.DATABASE_URL}}` (a reference to the database from step 3, not a pasted URL)
   - `GOHARD_Auth__SigningKey` = a new random string of 48+ characters. In PowerShell:
     `-join ((48..57)+(65..90)+(97..122) | Get-Random -Count 64 | % {[char]$_})`
5. Service → **Settings → Networking → Generate Domain.** The `https://….up.railway.app` address is the testing API URL.
6. Wait for the deploy to go green, then on your PC:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-api.ps1 -BaseUrl https://<your-domain>.up.railway.app
```

Every line must say PASS, including "Uses HTTPS". The script creates and deletes its own account.

**Cost:** a new project with one small service and one PostgreSQL uses your Railway plan's usage. Check the
project's Usage page after creating it. Nothing in this repository creates Railway resources by itself.

## Step 3 — Apple signing (Apple Developer portal)

You need a paid Apple Developer membership. In *Certificates, Identifiers & Profiles*:

1. **Identifiers → +  → App IDs → App:** Bundle ID *Explicit* `com.gohard.rebuild.dev`. No extra capabilities are
   needed (local notifications and location need none).
2. **Devices:** make sure your iPhone's UDID is registered. To read the UDID on Windows: connect the phone,
   open iTunes or the Apple Devices app, click the serial number until it shows the UDID, and copy it.
3. **Certificate:** an existing *Apple Distribution* certificate can be reused if you still have its `.p12`
   (certificate **and** private key) and password. A certificate from another app works; certificates are per team,
   not per app. If you only have a `.cer`, or no private key, create a new one.
4. **Profiles → + → Ad Hoc:** App ID `com.gohard.rebuild.dev`, your distribution certificate, your iPhone selected.
   Download the `.mobileprovision`. (A *Development* profile with an *Apple Development* certificate also works;
   the workflow detects which kind it is. Development builds additionally need Developer Mode switched on, on the phone.)

A provisioning profile from the original app **cannot** be reused: it is tied to that app's bundle ID.

## Step 4 — GitHub secrets and variables

Repository → **Settings → Secrets and variables → Actions.**

Convert the two files to base64 in PowerShell (this copies to the clipboard; paste straight into GitHub):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\cert.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\GoHard_Dev.mobileprovision")) | Set-Clipboard
```

| Kind | Name | Value |
|---|---|---|
| Secret | `IOS_CERTIFICATE_P12_BASE64` | base64 of the `.p12` |
| Secret | `IOS_CERTIFICATE_PASSWORD` | the `.p12` password |
| Secret | `IOS_PROVISIONING_PROFILE_BASE64` | base64 of the `.mobileprovision` |
| Variable | `GOHARD_TESTING_API_BASE` | `https://<your-domain>.up.railway.app` |
| Variable (optional) | `IPHONE_UDID` | your iPhone's UDID; the build then fails early if the profile does not include it |

Secrets are never printed by the workflow, and the signing keychain is deleted at the end of every run.

## Step 5 — Build the IPA

Repository → **Actions → ios-dev-ipa → Run workflow.** It will, in order:

1. stop with a clear message if a secret or variable is missing or the API URL is not HTTPS;
2. verify the testing API: readiness, contract compatibility with the app, and that sign-in rejects bad credentials;
3. check the profile is for `com.gohard.rebuild.dev`, lists devices (and your UDID if given), and matches the certificate;
4. analyze and test the app, build, sign and verify the signature.

**Artifact location:** the run's summary page → *Artifacts* → **GoHard-Dev-ipa** (a zip containing
`GoHard-Dev-<run number>.ipa`, kept 14 days).

The first run may fail on something only a Mac can reveal, since the iOS build has never been compiled. Send the
failing step's log and it can be fixed.

## Step 6 — Install on the iPhone from Windows

Unzip the artifact to get the `.ipa`. Connect the iPhone by cable, unlock it and tap **Trust**. Then use one of:

- **3uTools** or **iMazing** (Windows): choose the device → Apps → install from file / "Install .ipa" → pick the IPA.
  They install the already-signed IPA as it is. (I could not test these on your machine.)
- **TestFlight** is the alternative if a cable install is awkward. It needs an App Store Connect app record and an
  upload step that this workflow deliberately does not have; say if you want it added. It is not the public App Store.

The app appears as **GoHard Dev**. If the profile is a *Development* one: Settings → Privacy & Security →
Developer Mode → On (the phone restarts). If iOS says the app cannot be verified or installed, the phone's UDID is
not in the profile: add the device, regenerate the profile, update the secret and rebuild.

## Test checklist on the iPhone

- [ ] **Sign up** with a new email and a password of 8+ characters. Today shows "No plan yet" and no invented data.
- [ ] **Today:** create a plan (include today among the training days), start the workout, record two sets, finish.
      Today shows "Done for today".
- [ ] **Train:** switch Workouts / Plan / Progress; go to another tab and back: the section you chose is still selected.
- [ ] **Eat:** log a food with calories and a blank protein. Totals read "Known totals", protein shows a dash.
      Today shows the same numbers.
- [ ] **Me:** edit your name.
- [ ] **Appearance** (Me → Appearance): choose Light, Dark and System, and each of Blue, Green and Pink. The whole
      app changes at once, including the tab bar and any open sheet. Close the app from the app switcher and reopen:
      the same look comes back, with no flash of another colour while it opens.
- [ ] **System mode:** choose System, then switch the iPhone between Light and Dark (Control Centre → hold the
      brightness slider → Dark Mode). The app follows and keeps your accent.
- [ ] **Nothing is lost by changing the look:** start a workout, type a load without saving it, change the accent
      from Me → Appearance, go back: the timer kept running and the typed load is still there.
- [ ] **Brightness and comfort** (cannot be judged from screenshots): at low, medium and full screen brightness,
      in a lit room and a dim one, read Today, Train › Plan and Eat in Light and in Dark. Small grey text should
      stay readable at low brightness; Light should not dazzle in the dim room; nothing should glow in Dark.
- [ ] **Large text:** Settings → Display & Brightness → Text Size, largest. Train › Plan and Today still read
      without cut-off labels (week tiles and the three-way switch stack instead of shrinking).
- [ ] **Smoothness:** scroll Today and Train › Plan, tap between weeks, open and close a workout sheet, swipe back
      from a page. Note anything that stutters and where.
- [ ] **VoiceOver** (optional): the pass reads the plan name, week and completed count; week tiles read their
      dates and state; the selected tab and segment are announced as selected.
- [ ] **Nutrition goals:** Me → Nutrition goals. Both fields start empty. Set calories and protein, save: Today and
      Eat show the same two progress lines. Clear one field and save: that line disappears, the other stays.
- [ ] **Search a food:** Eat → Log food → type a food → "Search online". (Needs the USDA key on the testing API;
      without it the screen says search is not set up.) Open a result, change the amount and the unit, check the
      values change with it, press Log food: it appears in the journal and in the totals on Eat and Today.
- [ ] **Scan a barcode (cannot be checked without a phone):** Log food → Scan barcode. The first time, iOS asks for
      the camera with GoHard's explanation. Point at a packet: it should read within a second or two, buzz once, and
      open that product's form once (not several times). Try a packet in poor light with the torch button. Try a QR
      code from a poster: nothing should happen. Nothing is logged until you press Log food.
- [ ] **Camera refused:** Settings → GoHard Dev → Camera off, then Scan barcode: the screen explains and offers the
      typed barcode. Type the digits under a barcode: the same product opens.
- [ ] **Leaving and returning while scanning:** with the scanner open, go to the Home screen and come back: the
      camera view resumes. Press Cancel: the camera light or indicator goes off.
- [ ] **Unknown product:** scan something obscure (or type 96385074): the app says no product was found and offers
      manual entry. It must not invent a product.
- [ ] **Recent, favourite, My foods:** log a food, open Log food again: it is under Recent. Open it, tap the star,
      log it: it is now under Favourites. In a manual entry tap "Save to My foods without logging": it is under My
      foods and the journal did not change.
- [ ] **Offline food:** airplane mode → Log food: Recent, Favourites and My foods still work and can be logged;
      searching says you are offline; a barcode scanned earlier still opens. Turn airplane mode off: Me returns to
      "Everything is saved".
- [ ] **Saving data:** Me shows "Everything is saved to your account". Sign out, sign in again: everything is still there.
- [ ] **Restart:** start a workout, record a set, swipe the app away, reopen: Today offers "Resume workout" with the set.
- [ ] **Offline:** airplane mode, record a set, turn it off again: Me returns to "Everything is saved".
- [ ] **Running:** Today → Start a run → allow location → walk outside for a minute: distance rises; finish; the run
      shows time and distance. There is **no map**. Distance is measured only while the run screen is open.
- [ ] **Reminders:** Me → Workout reminders → allow notifications → set a time a few minutes ahead on a day with a
      planned workout: a notification arrives. Pause the plan: no reminder.
- [ ] **Both apps:** the original GoHard app is still installed and unchanged next to GoHard Dev.

Known limits for this build: food search is in English and mostly United States foods; barcode data is strongest
for European and North American products and can be incomplete; no route map, no background GPS, no social, health sync, music or AI features, and
the baseline plan content still needs your review.

## Fastest route: unsigned IPA + Sideloadly (no Apple certificate needed)

State on 12 October 2026: the repository variable `GOHARD_TESTING_API_BASE` is set. The three signing secrets in Step 4
are not, so only this unsigned route can produce an installable build today. To build the redesign before it is
merged: Actions → **ios-unsigned-ipa** → **Run workflow** → choose branch `design/calm-momentum`.

`.github/workflows/ios-unsigned-ipa.yml` builds an unsigned IPA with no secrets at all. It runs when started from
the Actions tab, or when a tag starting with `ipa-` is pushed. Artifact: **GoHard-Dev-unsigned-ipa**.

Install from Windows:

1. Install iTunes **from apple.com** (not the Microsoft Store version) and Sideloadly (sideloadly.io).
2. Connect the iPhone by cable, unlock it, tap **Trust**.
3. Unzip the downloaded artifact to get the `.ipa`, drag it into Sideloadly, enter your Apple ID, press **Start**.
   Sideloadly signs the app with your Apple ID and installs it.
4. On the iPhone: Settings → General → VPN & Device Management → your Apple ID → **Trust**.
   On iOS 16 or later also: Settings → Privacy & Security → **Developer Mode** → On (the phone restarts).

With a free Apple ID the app works for 7 days, then needs re-installing the same way; your data lives in the
testing API, so nothing is lost. Sideloadly may change the bundle identifier to make it unique for your Apple ID.
For a build that does not expire weekly, use the signed workflow above.
