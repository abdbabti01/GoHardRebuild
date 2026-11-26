# Branch cleanup record

## 25 Nov 2026 (after `main` d53431c, food identity)

Deleted only branches whose tip is an ancestor of `main` d53431c (`git merge-base --is-ancestor`), plus one stale
pre-rebase remote (below). No open pull requests existed. Their worktrees were clean (no tracked changes, no untracked files,
ignored files only build output; the eat-compact journey shots in `ghw/eatlayout/build/` are byte-identical to
docs/evidence/design/eat-compact/) and no process was using them. Tags, IPA artifacts and media were not touched.

Recover any branch with `git branch <name> <sha>` (local) or `git push origin <sha>:refs/heads/<name>` (remote). The
commits stay reachable from `main`, apart from the pre-rebase remote, whose commit sits in the object store until garbage
collection and also in this repository's GitHub history.

**Pre-rebase remote:** `origin/feature/eat-reusable-amounts` ceeefd5fee22458291210a1c316afe8b18e24c37 is not an ancestor
of `main`. It is the same commit (same message, author date 13 Nov 2026 22:02) before its rebase onto 62fb316, which became
41fc375 on `main` (also `origin/feature/eat-reusable-amounts-rebased`). `git range-diff` shows only rebase-context
differences in generated l10n files and the ledger; 41fc375 adds a ledger line. Nothing unique remains.

**Kept (unmerged, paused or uncertain):** `feature/animatic-squat-preview`, `feature/athlete-blendkit-base`,
`feature/exercise-demonstrations`, `feature/exercise-mannequin`, `feature/leon-blender-prototype`,
`feature/leon-character-v2`, `feature/leon-squat-pilot`, `feature/owner-exercise-videos`, `feature/wger-demonstrations`
(each has 2–11 commits not on `main`, local and remote); `main`. The `C:/dev/GoHardRebuild` worktree (on
`feature/animatic-squat-preview`, untracked owner hand-off folders) was not touched.

### Local branches deleted

| Branch | Tip SHA |
|---|---|
| `agent/art` | 72b7f90eb725c0f16ea62080f68b8b87b0a027ad |
| `agent/layout` | 7cc16aa27793a41e0385b1934c3eb63c7c2fa07b |
| `agent/motion` | 78fb9f26799bf386c2189006149dd1b07c15305e |
| `agent/plan-api` | 56c6ba94df8470c4686f3cdc26bdef5336dba48c |
| `agent/plan-builder` | a165e41129c99b3f69927eba870c3a7a6c1520b1 |
| `agent/plan-train` | 32173a1b901644710fe2231a06ba99b2c316c79b |
| `design/calm-momentum` | 22013e04ba9a4697745986d987ec4ec7cf5c5436 |
| `feature/appwide-design` | 5b24cb8bf1b91c5b384261c21f7e259b8895fc1b |
| `feature/auth-recovery-verification` | 6c0cc79c87c18d500e38baee6513ac5b76b783a3 |
| `feature/body-progress` | 14f628575838f359236cdc0aa66625b79d7fa2a8 |
| `feature/change-email` | e072c6d8beab25565d1295758350871c0383284a |
| `feature/coach-companion` | bbe4fd7870a950175edc3d300568dcef67822e2c |
| `feature/coach-groq` | dc8c967fb748270bad3742e554746d40c616d48b |
| `feature/coach-tabs-tracking-sync` | dc06ef51aeb82485a65837dfd899374b7f7f5d37 |
| `feature/coach-today` | e85993a792aa22de29f22cd64d5ef349a67ec9e6 |
| `feature/daily-nutrition-coach` | b0c0da63c5d0ec0a4e7f54ffab9ad5f25949cc48 |
| `feature/daily-rhythm-weather` | e6e43a816ab27607d0a423bd0499b6e95af0dba3 |
| `feature/eat-compact-top` | 2211ad021982cf8f8025cc197fd16e13adc5cfe6 |
| `feature/eat-companion` | 57ea8067556c79a1dfa6143a6163a9118dc25a18 |
| `feature/eat-meals-first` | acf973f56861f0fe442dd3894a126db55d74e4d2 |
| `feature/eat-reusable-amounts` | 41fc375814cc458e17bd5773d2135fdf384cd6ce |
| `feature/eating-out` | 71a80e9840941833bd51a2718609233754f20d55 |
| `feature/eating-out-discovery` | df6062cf7d450172532b1991b65798e3643ce5df |
| `feature/food-discovery` | 30ea10ddec456d07d02dbe1c438d62ca25753c30 |
| `feature/food-identity` | d53431c2dcf7b84b21db4c6e452fa9ebce209493 |
| `feature/food-resolution` | f35e2737d4b38e9f7641f6c545c78cafd6e4316d |
| `feature/food-search-describe-meal` | 1ebe45b869a282348565e1a5a28c99c70e7dd8eb |
| `feature/full-screen-weather` | 0364df0d4d6b12d793f20b838d7a5a17dbe2b2b1 |
| `feature/localization-fr-ar` | f4a1eb5a7729ce264128c4bd2f433d9d328a2941 |
| `feature/meal-copy-workout-panel` | f9661914548724b0d724ea7d8fb60cc3b6b50679 |
| `feature/meal-habits-reminders` | d613430ff5116d1d238fa930b900662c04b96e59 |
| `feature/met-hour-validity` | e41ac99e2699d0a08b88a8f6baf96b5e29eb6adc |
| `feature/nutrition-assessment-report` | 05a998d784cc7dc1630e56eed1f03f1a11bf6e03 |
| `feature/nutrition-goals-water` | 3948f0701cb8d85636f8fc978d9626f36f83c64c |
| `feature/nutrition-rings` | 48c555795986518a01c3fff5f819cf6569fd36cc |
| `feature/nutrition-trends` | 4871cc237f5293ca5ee6d7c41d1de3ec453b5aae |
| `feature/original-branding` | 2ff9a9dba278fd07a0e66e628cf10b03040e9321 |
| `feature/plan-library-overload` | 5a0ee30b3c33db5c5fe1d62dfa773c1f1ca5bd67 |
| `feature/plus-preview` | d31a29c8cb5375fda85580e3efc994f60e967bbd |
| `feature/rhythm-visual-followup` | 10c6750743313be3c1e8f3da333706f479b94b51 |
| `feature/run-walk` | ff65c88350c3556fc173621bb891fd3f7084d8b7 |
| `feature/saved-meals-recipes` | 13dcc7b8b769c243a5d063f5b3bd91ba3139b364 |
| `feature/steps-intervals-audio-records` | c586864125259c9bb74abc8700008e47624db2dd |
| `feature/target-estimate-review` | 6dcfda3473f907a7b2416921c4a69cbf09ab3de1 |
| `feature/target-estimator` | 009bae65ec2863c94956c07a16f6af6a58b719d3 |
| `feature/today-photo-cards` | 76623f7a1db34e971c172cd50d075543d3f669ed |
| `feature/today-photo-panels` | 72779c9605a21b2627ba683e357940efd1480b95 |
| `feature/today-refine` | e33a7fc626cf9fffb24a379d185579d68d2edada |
| `feature/train-plan-builder` | 1e3991e4ce7d546429c632b1f7dc358ad694d6c0 |
| `feature/training-progress` | 59ff7ebc1bb25c6ea44e1de9d091e1b26354bad4 |
| `feature/ui-food-search-refine` | af0594d7e7db835f2b38988257520c5532f2e602 |
| `feature/verification-navigation` | 3a36aa70f0fcea6f9c1a4dcd95b083c0b806bd09 |
| `feature/weather-fallback-check` | 39ad03d993673270edf89712195f58f2d910a746 |
| `feature/weather-motion` | d237319236ccd9b12ab57ebf02bbfaa0bd3d0a66 |
| `feature/workout-progression` | 225c7b35d58bfdab77afd4a2a5e1b62eb2011302 |
| `feature/workout-workspace` | 717f3f7f39c2f3bc3c5812ae03667f8922aca67b |
| `fix/auth-sign-out` | 0d49f2d8a4cb3475042c974c92f59705f1a097cf |
| `fix/workout-exercise-switch` | e33ec42afa76b392cb97f56005d7cf072417b495 |

### Remote branches deleted (origin)

| Branch | Tip SHA |
|---|---|
| `design/calm-momentum` | 22013e04ba9a4697745986d987ec4ec7cf5c5436 |
| `feature/appwide-design` | 5b24cb8bf1b91c5b384261c21f7e259b8895fc1b |
| `feature/auth-recovery-verification` | 6c0cc79c87c18d500e38baee6513ac5b76b783a3 |
| `feature/body-progress` | 14f628575838f359236cdc0aa66625b79d7fa2a8 |
| `feature/change-email` | e072c6d8beab25565d1295758350871c0383284a |
| `feature/coach-companion` | bbe4fd7870a950175edc3d300568dcef67822e2c |
| `feature/coach-groq` | dc8c967fb748270bad3742e554746d40c616d48b |
| `feature/coach-tabs-tracking-sync` | dc06ef51aeb82485a65837dfd899374b7f7f5d37 |
| `feature/coach-today` | e85993a792aa22de29f22cd64d5ef349a67ec9e6 |
| `feature/daily-nutrition-coach` | b0c0da63c5d0ec0a4e7f54ffab9ad5f25949cc48 |
| `feature/daily-rhythm-weather` | e6e43a816ab27607d0a423bd0499b6e95af0dba3 |
| `feature/eat-compact-top` | 2211ad021982cf8f8025cc197fd16e13adc5cfe6 |
| `feature/eat-companion` | 57ea8067556c79a1dfa6143a6163a9118dc25a18 |
| `feature/eat-meals-first` | acf973f56861f0fe442dd3894a126db55d74e4d2 |
| `feature/eat-reusable-amounts` | ceeefd5fee22458291210a1c316afe8b18e24c37 |
| `feature/eat-reusable-amounts-rebased` | 41fc375814cc458e17bd5773d2135fdf384cd6ce |
| `feature/eating-out` | 71a80e9840941833bd51a2718609233754f20d55 |
| `feature/eating-out-discovery` | df6062cf7d450172532b1991b65798e3643ce5df |
| `feature/food-discovery` | 30ea10ddec456d07d02dbe1c438d62ca25753c30 |
| `feature/food-identity` | d53431c2dcf7b84b21db4c6e452fa9ebce209493 |
| `feature/food-resolution` | f35e2737d4b38e9f7641f6c545c78cafd6e4316d |
| `feature/food-search-describe-meal` | ac324ff2f734d5f138d696d7bdba5190386e7390 |
| `feature/full-screen-weather` | 0364df0d4d6b12d793f20b838d7a5a17dbe2b2b1 |
| `feature/localization-fr-ar` | f4a1eb5a7729ce264128c4bd2f433d9d328a2941 |
| `feature/meal-copy-workout-panel` | f9661914548724b0d724ea7d8fb60cc3b6b50679 |
| `feature/meal-habits-reminders` | d613430ff5116d1d238fa930b900662c04b96e59 |
| `feature/met-hour-validity` | e41ac99e2699d0a08b88a8f6baf96b5e29eb6adc |
| `feature/nutrition-assessment-report` | 05a998d784cc7dc1630e56eed1f03f1a11bf6e03 |
| `feature/nutrition-goals-water` | 3948f0701cb8d85636f8fc978d9626f36f83c64c |
| `feature/nutrition-rings` | 48c555795986518a01c3fff5f819cf6569fd36cc |
| `feature/nutrition-trends` | 4871cc237f5293ca5ee6d7c41d1de3ec453b5aae |
| `feature/original-branding` | 2ff9a9dba278fd07a0e66e628cf10b03040e9321 |
| `feature/plan-library-overload` | 5a0ee30b3c33db5c5fe1d62dfa773c1f1ca5bd67 |
| `feature/plus-preview` | d31a29c8cb5375fda85580e3efc994f60e967bbd |
| `feature/rhythm-visual-followup` | 10c6750743313be3c1e8f3da333706f479b94b51 |
| `feature/run-walk` | ff65c88350c3556fc173621bb891fd3f7084d8b7 |
| `feature/saved-meals-recipes` | 13dcc7b8b769c243a5d063f5b3bd91ba3139b364 |
| `feature/steps-intervals-audio-records` | c586864125259c9bb74abc8700008e47624db2dd |
| `feature/target-estimate-review` | 6dcfda3473f907a7b2416921c4a69cbf09ab3de1 |
| `feature/target-estimator` | 009bae65ec2863c94956c07a16f6af6a58b719d3 |
| `feature/today-photo-cards` | 76623f7a1db34e971c172cd50d075543d3f669ed |
| `feature/today-photo-panels` | 72779c9605a21b2627ba683e357940efd1480b95 |
| `feature/today-refine` | e33a7fc626cf9fffb24a379d185579d68d2edada |
| `feature/train-plan-builder` | 1e3991e4ce7d546429c632b1f7dc358ad694d6c0 |
| `feature/training-progress` | 59ff7ebc1bb25c6ea44e1de9d091e1b26354bad4 |
| `feature/ui-food-search-refine` | af0594d7e7db835f2b38988257520c5532f2e602 |
| `feature/verification-navigation` | 3a36aa70f0fcea6f9c1a4dcd95b083c0b806bd09 |
| `feature/weather-fallback-check` | 39ad03d993673270edf89712195f58f2d910a746 |
| `feature/weather-motion` | d237319236ccd9b12ab57ebf02bbfaa0bd3d0a66 |
| `feature/workout-progression` | 225c7b35d58bfdab77afd4a2a5e1b62eb2011302 |
| `feature/workout-workspace` | 717f3f7f39c2f3bc3c5812ae03667f8922aca67b |
| `fix/auth-sign-out` | 0d49f2d8a4cb3475042c974c92f59705f1a097cf |
| `fix/workout-exercise-switch` | e33ec42afa76b392cb97f56005d7cf072417b495 |

### Worktrees removed

| Path | Branch | SHA |
|---|---|---|
| `C:/dev/ghw/art` | `agent/art` | 72b7f90eb725c0f16ea62080f68b8b87b0a027ad |
| `C:/dev/ghw/eatlayout` | `feature/eat-compact-top` | 2211ad021982cf8f8025cc197fd16e13adc5cfe6 |
| `C:/dev/ghw/layout` | `agent/layout` | 7cc16aa27793a41e0385b1934c3eb63c7c2fa07b |
| `C:/dev/ghw/mealtalk` | `feature/food-identity` (then `main` for the release notes) | d53431c2dcf7b84b21db4c6e452fa9ebce209493 |
| `C:/dev/ghw/motion` | `agent/motion` | 78fb9f26799bf386c2189006149dd1b07c15305e |
