# Owner exercise videos

**Status (19 Oct 2026): implemented and locally verified; real R2 setup and hosted verification deferred.** Code on
`feature/owner-exercise-videos` (f55f1bb; CI 97 and unsigned IPA 37 passed). To activate, follow Setup below.

Added 18–19 October 2026 on `feature/owner-exercise-videos`. The app's owner uploads demonstrations from the phone
(Me › Manage exercise videos), the server converts them, and after an explicit **Publish** everyone using GoHard sees
them on that exercise, without a new app build. Builds on [EXERCISE_DEMOS.md](EXERCISE_DEMOS.md) (the bundled library
and the shared player stay as they were).

## For the owner

1. **Me › Manage exercise videos** (only on the configured owner account), or **Manage demonstration** at the end of any
   exercise's details.
2. **Upload video**, choose the exercise, choose a video from your photos. Best: a short clear clip of the whole
   movement. Limits: **2 minutes, 200 MB**.
3. Say what it shows (equipment, grip, angle), the title and the credit everyone sees (default "GoHard"; your email or
   profile is never shown). For your own footage tick **I own this footage**; for someone else's, switch on **Someone
   else made this footage** and give its exact licence and source.
4. **Upload** (progress, Cancel). Keep GoHard open until it finishes; if it stops, upload again (no resume).
5. **Processing** (usually under a minute; you can leave the page and come back). Then **Ready to preview**: the real
   converted clip, with slow motion and full screen.
6. **Publish**: it becomes available to everyone using GoHard. Others see it on their next quiet refresh (on opening the
   app or Train, at most every five minutes).
7. Later: **Upload a replacement** (the published one stays until the replacement is published), **Unpublish** (the
   bundled demonstration, or none, comes back), **Delete draft** for an unpublished one.

A failed upload or conversion never touches the published video. Nothing is published by itself, and opening the
manager never publishes or retries a publish.

## How it works

```
phone (owner)                 API (Railway)                         R2 private "staging"          R2 public "media"
  create draft  ───────────▶  check owner, key, type, size
  upload link   ◀───────────  presigned PUT (30 min, one object, Content-Type signed)
  PUT file  ─────────────────────────────────────────────────────▶  originals/<random>
  complete  ───────────────▶  HEAD: real size ≤ 200 MiB → queued
                              worker: claim (DB lease) ◀──────────  download original
                                      ffprobe, ffmpeg → clip + poster ─▶ processed/<draft>/<sha>.mp4/.jpg
  preview   ◀───────────────  presigned GETs (10 min) of the processed files
  publish   ───────────────▶  copy ──────────────────────────────────────────────────────▶  clips/<key>/<sha>.mp4
                              check sizes, then in one transaction: active pointer, revision      posters/<key>/<sha>.jpg
phones (everyone) GET /exercise-media/catalog (ETag) ─▶ entries ─▶ stream/download from the media domain
```

- **Authorization**: `GOHARD_ExerciseMedia__OwnerUserId` against the verified token's subject (the token is already
  checked against the account's security stamp on every request). Every management route answers 404 to anyone else,
  including reads, upload and preview links. A missing or invalid setting means nobody manages. No profile field,
  email, client flag or request body can grant it; registration and profile updates know nothing of it.
  `GET /exercise-media/access` says only `canManage`, `ready` and a problem code, never who the owner is.
- **Data** (migration `AddExerciseMedia`): `MediaDrafts` (one upload, and the durable job: status, attempts, lease),
  `MediaVersions` (immutable published versions; a partial unique index allows one active per key), `MediaCatalogStates`
  (one row; its revision is the catalogue's ETag). Reference data, not account rows: never in a sync snapshot.
- **Commands**: create, details, complete, retry, publish, unpublish, delete go through the existing `CommandRunner`
  (operation IDs, idempotent replay, revision checks: a stale revision is a conflict, not an overwrite). Upload and
  preview links are plain answers, never written to the operation log.
- **Public catalogue** `GET /api/v1/exercise-media/catalog` (signed-in): revision, the media origin, and per active
  version only the key, variant, clip/poster URLs, bytes, SHA-256, size, duration, creator and rights. No staging keys,
  file names, actors, links or diagnostics.
- **Phone**: the catalogue is merged over the bundled library by exact key (an owner video wins for its key; others keep
  their third-party demos), persisted with its ETag, refreshed on foreground and Train entry when older than five
  minutes and at once after the owner publishes or unpublishes. A failed or 304 refresh keeps the last good catalogue.
  URLs are accepted only on the media origin the API names, over HTTPS (plain HTTP only for a local development
  address in a debug build). Nothing downloads by itself; Play and Download, mute, mixing, size and SHA-256 checks and
  offline use are those of the existing player. Withdrawn or replaced owner videos saved on a phone are deleted on its
  next successful refresh, never while playing; a phone that stays offline keeps showing what it last knew.
- **Capabilities**: `exercises.media-catalog` (every new server), `exercises.media-manage` (only where an owner and
  storage are configured). An older server is never asked; the bundled library works as before.

## Processing (`MediaWorker`, `FfmpegProcessor`)

- One job at a time per worker. Claimed with `UPDATE … WHERE Id = (SELECT … FOR UPDATE SKIP LOCKED)` and a lease
  (`JobTimeoutMinutes`, default 15); a worker that died is replaced when its lease ends. Results are recorded only by
  the lease holder. At most `MaxAttempts` (3) tries, then **Failed** with a reason; the owner can **Try again**.
- Works on a complete local file in a private temporary folder, deleted afterwards; refuses to start with less than 3 ×
  the original's size free. FFmpeg and ffprobe get argument arrays (no shell), generated file names only, and
  `-protocol_whitelist file` (a submitted file cannot make them read anything else).
- Checks first: a real video stream, duration ≤ 120 s, sane dimensions. Output: video only (no audio, subtitles, data
  or chapters), metadata stripped (no location or device), H.264 High 4.0, 8-bit yuv420p, BT.709 tagged, at most
  1280 × 720 (either orientation) and 30 fps, aspect ratio and rotation kept (no crop, stretch or mirror), `+faststart`,
  bitrate capped so the clip stays within 20 MiB; checked again after encoding (codec, pixel format, size), then a
  640 px poster and the SHA-256.
- HDR: PQ (HDR10) and HLG are tone-mapped to SDR with `zscale` + `tonemap=hable`; Dolby Vision profile 8 uses its
  HDR10/HLG base. Dolby Vision profile 5 and unknown transfer functions are refused ("UNSUPPORTED_HDR"), never
  published with wrong colours.
- Image: the API's Dockerfile adds Ubuntu 24.04's `ffmpeg` package (FFmpeg 6.1.1, with libx264 and zimg); the image
  grows from about 250 MB to 658 MB. That FFmpeg build is GPL (libx264 is GPL); GoHard only runs it as a separate
  program, but distributing the image means distributing GPL software (its source is available from Ubuntu).
- To run the worker apart from the web service (if conversions slow requests down): deploy the same image as a second
  Railway service with the same variables, set `GOHARD_ExerciseMedia__WorkerEnabled=false` on the web service (and
  leave it `true` on the worker service). Both may run at once safely (the lease).

Cleanup (hourly, in the worker): uploads never completed within a day after their link expired are cancelled; a
cancelled draft's staging files are deleted; an original is deleted seven days after its video was published. The
public bucket is never touched by cleanup: replaced and withdrawn clips stay (phones offline may still use them) and
can be removed by hand later if storage matters.

## Setup (Cloudflare R2 + Railway)

Nothing below was done by this work: no Cloudflare resource, Railway variable or production data was created or
changed. Do these in order; do not paste keys into chat or into the app.

1. **Owner ID.** Sign in to the hosted API with your account and read your ID (it is not secret, but it is personal:
   keep it out of the repository):
   ```powershell
   $t = (Invoke-RestMethod -Method Post https://<api>/api/v1/auth/login -ContentType application/json -Body (@{email='<you>';password=(Read-Host)}|ConvertTo-Json)).accessToken
   (Invoke-RestMethod https://<api>/api/v1/me -Headers @{Authorization="Bearer $t"}).userId
   ```
2. **R2** (Cloudflare dashboard › R2): create two buckets in Standard storage, e.g. `gohard-media-staging` (private:
   no public access, no r2.dev) and `gohard-media` (public through a custom domain only).
3. **Media domain**: on `gohard-media` › Settings › Custom Domains, add e.g. `media.<your domain>` (the domain must be a
   zone in the same Cloudflare account). Leave the r2.dev URL disabled (it is rate-limited and for development). Add a
   cache rule "Cache Everything" for that host (MP4 is not cached by default); objects are immutable, so long caching
   is safe.
4. **API token**: R2 › Manage API tokens › Create: **Object Read & Write**, limited to those two buckets. Note the access
   key ID, secret and the S3 endpoint `https://<account id>.r2.cloudflarestorage.com`.
5. **Railway** (devoted-caring, the API service) variables:
   ```
   GOHARD_ExerciseMedia__OwnerUserId=<your user ID from step 1>
   GOHARD_ExerciseMedia__ServiceUrl=https://<account id>.r2.cloudflarestorage.com
   GOHARD_ExerciseMedia__AccessKeyId=<from step 4>
   GOHARD_ExerciseMedia__SecretAccessKey=<from step 4>
   GOHARD_ExerciseMedia__StagingBucket=gohard-media-staging
   GOHARD_ExerciseMedia__PublicBucket=gohard-media
   GOHARD_ExerciseMedia__PublicBaseUrl=https://media.<your domain>
   # optional: WorkerEnabled=true, JobTimeoutMinutes=15, MaxAttempts=3, UploadUrlMinutes=30, PreviewUrlMinutes=10, WorkDirectory=
   ```
   The existing pre-deploy command (`dotnet GoHard.Api.dll migrate seed-catalog`) applies the migration. The service
   needs a few GB of temporary disk for one conversion and benefits from 2 vCPUs / 2 GB.
6. **Release**: merge, deploy, and install the app build from this branch once. Afterwards every upload works from the
   phone; no asset, JSON, CI run or app build is needed per video.
7. **Check** with `node scripts/media-roundtrip.mjs --api https://<api> --email <you> --password <pw> --clip <file>
   --key <catalogKey> --unpublish` against a key you are happy to publish briefly, or use the app.

## Costs and limits

- R2 Standard: 10 GB-month, 1 million Class A and 10 million Class B operations free each month; then $0.015 per
  GB-month, $4.50 per million Class A, $0.36 per million Class B; no egress fees (Cloudflare pricing page, Oct 2026).
  Fifty demonstrations at ~3 MB each are about 150 MB published plus originals kept a week: well within the free tier.
- Per clip: original ≤ 200 MiB and ≤ 120 s (refused by the server too); published ≤ 20 MiB, 720p, 30 fps. Phones keep at
  most 100 MiB of downloaded clips (least recently used out first).
- Railway: conversions use CPU for roughly the clip's duration on two cores; one at a time.

## Local verification

`scripts\start-media-local.ps1 -LocalOwner [-Build]` runs the API's real Linux image (with FFmpeg and the worker) on
port 5131 against the dev database, and SeaweedFS 3.97 on port 8333 standing in for R2 (MinIO's images are no longer
pullable): a private `gohard-staging` and a public-read `gohard-public` bucket. It registers a local test owner through
the API the first time (`build\media-local\owner.json`, git-ignored, with the generated local S3 keys).

Round trip, 19 Oct 2026 (`scripts/media-roundtrip.mjs`, real HTTP, real store, real FFmpeg): wger clip 79 (Face pull,
Goulart, CC BY-SA 4.0), a 19.7 MiB iPhone recording, HEVC Main 10, HLG with Dolby Vision profile 8, 1920 × 1080 at
~60 fps: signed direct upload 200; complete → queued; processed in 20 s to H.264 High, yuv420p, BT.709, 1280 × 720,
30 fps, 8.57 s, 2.22 MiB, video only, moov first, no location tags; tone-mapped frame checked by eye against a straight
decode (natural contrast, not washed out, uncropped); preview range request 206; publish; catalogue entry with SHA-256
matching the downloaded public clip; public range request 206; unsigned staging read 403 and public listing 403;
unpublish accepted.

Device journey: see the progress ledger (`journey_owner_videos_test`).

## Not verified, and known limits

- Real Cloudflare R2 (only an S3-compatible stand-in) and the hosted API: no credentials were used; setup above.
- The local store ignored `Cache-Control` on copied objects; R2 should honour it (`public, max-age=31536000, immutable`):
  check one published object's headers after setup.
- The published MP4's brand list still names `dby1` when the source was Dolby Vision (FFmpeg 6.1 copies it); the stream
  carries no Dolby configuration and is tagged BT.709, which is what players use.
- Real iPhone picking (the system photo picker), HDR appearance on an iPhone screen, uploads while iOS suspends the app
  (there is no background upload or byte resume: upload again), music and VoiceOver: not observed.
- Device test picking is SIMULATED (`GOHARD_TEST_PICK_FILE`, debug builds only).
- A published video is not a qualified technique review; technique notes keep their own source and review status.
