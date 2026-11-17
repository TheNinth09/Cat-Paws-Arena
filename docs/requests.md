# Shared requests

Lanes submit requests here for orchestrator-owned files or cross-lane contract changes. Do not edit another lane's implementation to work around a request. Include the requesting lane, the blocking PR, exact files/symbols, the requested change, and the reason.

The orchestrator answers requests and announces every contract change. A request is not approval to change `docs/contract.md`.

Format:

```text
Lane: <1-5>
Blocking PR: <URL or branch/commit>
Request: <specific change>
Reason: <dependency or integration need>
Status: open
```

```text
Lane: 3
Blocking PR: lane-3 slice 2 (creator)
Request: Stop selling powers in the shop. In lib/shop_screen.dart remove `...powers` from the 'ACCESORII & PUTERI' grid (line ~100) and stop granting `powers[0]` in `buyCombo` (line ~37); if catalog.dart pricing treats powers as buyable items, mark them non-purchasable. Powers must stay free for every cat, per contract decision 4 and the Families policy.
Reason: The contract states "Three free powers of equal strength; none is sold." Lane 3's creator already lets the custom cat equip any of the three powers for free, but the shop still lists them at 300 paws, which contradicts the contract.
Status: answered — shop is cosmetics-only on main in 552aad1/d01c5d8; powers no longer purchasable.
```

```text
Lane: 3
Blocking PR: lane-3 slice 3 (share card)
Request: Review the new dependency line `share_plus: 13.3.1` added to pubspec.yaml (orchestrator-owned file). It is the standard Flutter Community plugin for the platform share sheet, published 44 days ago, supports Android/iOS/Web/Windows/macOS/Linux, requires Flutter >=3.38.1 / Dart >=3.10 (project has 3.47.7 / 3.13.5). No other dependency was added; `XFile` is re-exported by share_plus so `cross_file` is not needed as a direct dependency.
Reason: Slice 3 requires sending the share card "through the phone's share sheet". share_plus is the maintained, families-policy-safe choice (no ads, no tracking). pubspec.yaml may only be changed by the orchestrator, so this line needs review/approval.
Status: answered — orchestrator approved `share_plus: 13.3.1`; kept alongside the `arena_engine` path dependency on main.
```

```text
Lane: 4
Blocking PR: lane-4 branch (Slice 1 freeze)
Request: In lib/match_screen.dart, remove the unused top-level `_goldGradient` declaration at line 26 (or use it) so `flutter analyze` is clean.
Reason: `flutter analyze` currently fails with `unused_element` on `_goldGradient`; the file is lane-2 owned and lane 4 cannot edit it. Slice 1 done-when requires a clean analyzer.
Status: answered — lane-2 removed `_goldGradient` in the arena-engine duel merge; it is absent on main.
```

```text
Lane: 5
Blocking PR: lane-5 (slice 1: CI and release hygiene)
Request: Lane 2 removes the unused `_goldGradient` declaration in `lib/match_screen.dart:26`.
Reason: `flutter analyze` exits 1 on this pre-existing warning (see docs/baseline.md). CI runs `flutter analyze --no-fatal-warnings` until it is fixed; lane 5 will then make warnings fatal again in `.github/workflows/ci.yml`.
Status: answered — `_goldGradient` is removed on main; orchestrator will restore fatal-warning analyze once `flutter analyze` is verified clean.
```

```text
Lane: 5
Blocking PR: lane-5 (slice 1: CI and release hygiene)
Request: Owner adds the repository secrets ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD (upload key), and the orchestrator notes in README.md that releases come from pushing a `vX.Y.Z` tag matching `pubspec.yaml`.
Reason: The APK is no longer tracked. `.github/workflows/release.yml` needs these secrets to sign; it refuses to publish a debug-signed APK.
Status: open — orchestrator documented the tag-release flow in README.md; still requires the owner to add the four Android signing secrets before the first tagged release.
```

```text
Lane: 4
Blocking PR: lane-5 (slice 3a: room codes, account and cloud save over a fake transport)
Request: In lib/app_dialogs.dart settings, add "Link Google account" and "Delete account" entries (delete behind a parent gate and a confirm step) that call `OnlineAccount.linkGoogle` and `OnlineAccount.deleteAccount` from `lib/online/online_account.dart`, then clear local data. Add a join-room field that passes the typed code to `RoomService.joinRoom` (it already accepts lower case, spaces and dashes). Show both only when online play is configured; until then keep the existing "unavailable" label.
Reason: Slice 3 requires account linking and in-app account deletion; the UI files are lane-4 owned. Lane 5 provides the logic only.
Status: open — assigned to lane-4 for a post-slice-3a settings UI slice; not blocking lane-5 slice 3a.
```

```text
Lane: 5
Blocking PR: lane-5 (slice 3a)
Request: Owner creates the Firebase project (Blaze, Firestore europe-west1) for `games.oneear.catpawsarena` and provides `android/app/google-services.json`; orchestrator then approves adding `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging` and `google_sign_in` to pubspec.yaml.
Reason: Lane 5 adds no Firebase SDK until the config file exists. The Firebase implementations of `AuthBackend` and `CloudStore` (lib/online/online_backend.dart) replace `FakeCloud` after that.
Status: open — owner action; orchestrator approves adding firebase_core, firebase_auth, cloud_firestore, firebase_messaging and google_sign_in to pubspec.yaml once android/app/google-services.json exists.
```

```text
Lane: 4
Blocking PR: lane-4 slice 2 (House Tour)
Request: Lane 2 adds an optional house-cat opponent (name, trophies, avatar fields) to `MatchScreen` and `ArenaMatchController` so a match can start against the selected `HouseCat` instead of always `Bubble Bot`.
Reason: Lane-4 lobby offers named resident house cats; lane-4 cannot edit lane-2 match files. Orchestrator forwards lane-4's request to lane-2.
Status: answered on the lane-2 side and merged — `MatchScreen(opponent: HouseCat)` + `ArenaMatchController(opponent: BotOpponent)` are on main; remaining step is lane-4 wiring the selected cat through `onBattle` in `lib/home_screen.dart`.
```

```text
Lane: 4
Blocking PR: lane-4 slice 2 (House Tour)
Request: In lib/profile.dart, change `Player.result` so a win adds 30 trophies, a loss subtracts 10, and trophies never fall below the floor of the highest House Tour room already reached.
Reason: Slice 2 gates House Tour rooms by trophies; lane 4 cannot edit orchestrator-owned `lib/profile.dart`.
Status: answered — implemented on main in 31a26b1 (`Player.result` floors trophies at `[0, 300, 800, 1500]` with +30/-10 deltas).
```

```text
Lane: 1
Blocking PR: lane-1-s3 (slice 3: bots and luck harness)
Request: Add a path dependency on the engine to the root `pubspec.yaml` (orchestrator-owned): `arena_engine: { path: packages/arena_engine }` under `dependencies:`.
Reason: Lanes 2 and 4 must `import 'package:arena_engine/arena_engine.dart'` to drive matches with the real engine instead of provisional contract types. The package is pure Dart with no Flutter imports, so the path dependency is safe for all consumers once `lane-1` merges to `main`.
Status: answered — orchestrator added the `arena_engine` path dependency to root `pubspec.yaml`.
```

```text
Lane: 2
Blocking PR: lane-2-slice-3 (slice 3: feel)
Request: Resolved in lane-2-s2 — the 16 SFX WAVs and CREDITS.md moved to assets/generated/audio/ (bundled via the existing assets/generated/ entry), so no pubspec audio line is needed and other lanes' bundle-whitelist tests stay green.
Reason: Lane 2 owns the audio assets; keeping them under assets/generated/ matches the AGENTS.md runtime-bundle rule ("assets/generated/ individual sprites/audio") and avoids editing lane-3/lane-4 test whitelists.
Status: answered — merged on main under `assets/generated/audio/`.
```

```text
Lane: 2
Blocking PR: lane-2-s2 (slice 2: arena engine duel)
Request: Keep `arena_engine: path: packages/arena_engine` in pubspec.yaml when this branch merges — slice 2 cannot compile without the local package dependency. The slice-3 SFX moved from assets/audio/ to assets/generated/audio/ so the runtime bundle stays inside the assets/generated/ + assets/fonts/ whitelist without touching other lanes' tests; pubspec needs no audio line. Also: lane 1 fixes two `unnecessary_const` infos in packages/arena_engine/lib/src/engine.dart:61,63 (or the orchestrator excludes packages/** from the root analyzer), otherwise `flutter analyze` reports 2 info issues owned by lane 1.
Reason: The vendored engine package is lane-1 code; the analyzer lints live there, not in lane-2 files.
Status: answered — `arena_engine` path dependency is retained in `pubspec.yaml`; SFX are under `assets/generated/audio/` with no extra pubspec line; the two `unnecessary_const` infos in `packages/arena_engine/lib/src/engine.dart` were fixed by the orchestrator during merge.
```

```text
Lane: orchestrator
Blocking PR: lane-5 Firebase backend
Request: In lib/main.dart, after WidgetsFlutterBinding.ensureInitialized(), call `final online = await OnlineServices.start();` (lib/online/online_config.dart) and set `OnlinePlay.services` from it (lib/shell/online_play.dart) so settings show online controls only when configured.
Reason: Firebase must be initialized before any online call; lib/main.dart is orchestrator-owned.
Status: open — orchestrator will wire `OnlineServices.start()` -> `OnlinePlay.services` in lib/main.dart after this merge.
```

```text
Lane: 4
Blocking PR: lane-5 Firebase backend (follow-up to the slice 3a request above)
Request: In settings, wire the online account UI to `OnlineServices` (null = keep "unavailable"): parent gate via `showParentGate` returning `ParentGateApproval`, `account.linkGoogle(cred, approval)`, `restoreWithGoogle`, `account.deleteAccount()`, `rooms.joinRoom` and `createRoom` + `waitForGuest` for host.
Reason: lane 5 cannot edit lane-4 screens; the parent gate is required by docs/contract.md §7 before Google sign-in.
Status: answered — orchestrator updated the merged lane-4 settings UI to the lane-5 API during integration.
```

```text
Lane: owner
Blocking PR: lane-5 Firebase backend
Request: (1) Deploy rules and functions from backend/ (`firebase deploy --only firestore:rules,functions`) after review; (2) TTL policy on rooms.expiresAt — WAIVED, expiry is enforced client-side and by the rules, no billing TTL; (3) Google linking: Google provider enabled, SHA-1/SHA-256 added and google-services.json with OAuth client committed (2705454); still add Play App Signing SHA-1/SHA-256 after first publish.
Reason: lane 5 never deploys; Google sign-in needs the OAuth client (now present) and Play signing fingerprints later.
Status: partially done — google-services.json with OAuth client and keystore secrets are in place; owner still deploys firestore.rules/functions and adds Play SHA fingerprints at publish time.
```

```text
Lane: 4
Blocking PR: lane-4 slice 4 (settings UI for online account and rooms)
Request: Set `OnlinePlay.services` once during app bootstrap (lib/main.dart before runApp) from `OnlineServices.start()`; leave it null until online is configured.
Reason: The settings section is gated by `OnlinePlay.services != null`; lane 4 cannot edit lib/main.dart.
Status: open — orchestrator will wire `OnlineServices.start()` -> `OnlinePlay.services` in lib/main.dart after this merge.
```

```text
Lane: 2
Blocking PR: lane-5 match sync
Request: For the friend duel, use `MatchSession` (lib/online/match_sync.dart): after `rooms.joinRoom` / `rooms.waitForGuest`, `services.openMatch(matchId)` (a `MatchSession`, also used to resume after a restart); render `session.state`; on the player's move call `session.play(move)`; listen to `session.watch()` and also start `session.poll(const Duration(seconds: 20))` and call `refresh()` on app resume (works without Cloud Functions); show `liveMoveLimit` as the live timer and offer `claimForfeit()` once `session.deadline` has passed; award nothing unless `session.counts`; show a "match not counted" state when `session.flag != null`. Emotes: `RoomService`/`CloudStore.sendEmote` with preset `Emote` only.
Reason: lane 5 cannot edit the duel screen; the match is a seed plus a move log replayed on both phones (docs/contract.md §3–4).
Status: answered — lane-2-online consumes `MatchSession` exactly this way: `session.play`/`watch`/`poll(20s)`/`refresh` on resume, `liveMoveLimit` countdown in the HUD, `claimForfeit` banner after `deadline`, rewards gated on `session.counts`, "REZULTAT NEVERIFICAT" when finals disagree or a flag lands, preset emotes via `CloudStore.sendEmote`/`emotes`.
```

```text
Lane: 4
Blocking PR: lane-5 match sync
Request: When `account.deleteAccount()` throws `OnlineErrorCode.requiresRecentLogin` (Google-linked account), pick Google again through the parent gate and retry with `account.deleteAccount(freshGoogle: credential)`.
Reason: account deletion now runs on the client without Cloud Functions (Spark-safe) and needs a fresh Google sign-in first so no data is lost if deletion fails.
Status: answered — lane-4 implemented the retry in 4b7e18b; merged to main in 14e9c18.
```

```text
Lane: 3
Blocking PR: lane-3 avatar editor (P2-1 custom user avatar)
Request: Persist the custom user avatar so it survives save/reload and Google account link. Proposed schema — AvatarSpec in lib/cat_avatar.dart serializes to compact JSON {"s":species 0-3,"f":fur 0-5,"p":pattern 0-4,"e":eyes 0-3,"r":ears 0-3,"a":accessory sprite id or ""}. Ask: (1) lib/profile.dart — add `String avatarSpec` (default '') saved inside the 'player' JSON; (2) lib/online/cloud_profile.dart — add an `avatar` string key copied in fromPlayer/applyTo/toJson/fromJson (schemaVersion bump or tolerant read) so cloud sync does not drop it; (3) orchestrator/lane-4 may later surface AvatarAvatar(player) in PlayerHud/profile — lane 3 already ships loadAvatarSpec/saveAvatarSpec helpers over prefs key 'avatar_spec_v1' as the interim local store.
Reason: Owner decision for P2-1: a custom user avatar separate from the duel cats; cloud sync must not drop it on Google link. AvatarSpec.fromJsonString tolerates bad data so older/newer clients degrade safely.
Status: answered — orchestrator added Player.avatarSpec + CloudProfile.avatar (tolerant read, no schema bump), migrated the prefs store, and allowed the avatar key in Firestore validProfile (fce8aec).
```

```text
Lane: 4
Blocking PR: lane-2-online (friend duel presentation)
Request: Expose match sync through `OnlinePlay.services` (lib/shell/online_play.dart): the lobby needs `openMatch(matchId)` (or the `OnlineServices` object), `services.store` for emotes, and the signed-in uid so it can build `OnlineDuel.open(services, matchLink)` and push `MatchScreen(online: duel)`. `OnlinePlayServices` currently carries only account/rooms/googleCredential.
Reason: P1-2 wires create/join room UI to the duel; lane 2 cannot edit lane-4 shell files, and `OnlineServices` itself is orchestrator/bootstrap territory.
Status: answered — orchestrator added `OnlinePlayServices.online` (the full OnlineServices) and wired the friend room panel: host waits via `rooms.waitForGuest`, guest opens from `joinRoom`'s matchId, both call `OnlineDuel.open` and push `MatchScreen(online:)`; without a configured backend the panel keeps the honest "online duels unavailable" notice.
```

```text
Lane: 5
Blocking PR: lane-2-online (friend duel presentation)
Request: (optional, schema) The opponent's preset cat name is not in `CloudProfile`, so a custom-cat friend shows as generic 'Pisică' on the VS/result screens (typed names must never leave the device; `catPresetNames` are preset-safe). If peer-visible cat names are wanted, add a preset-name field to `CloudProfile` — lane 2 will consume it via `OnlineOpponentInfo.fromCloudProfile`.
Reason: docs/contract.md allows preset names only; today only Tzuki/Bubble are peer-visible through `CloudProfile.cat`.
Status: open
```

```text
Lane: orchestrator
Blocking PR: lane-2-online (friend duel presentation)
Request: Root `flutter analyze` reports ~455 errors, all inside `packages/arena_engine/test/*.dart`: they import `package:test/test.dart`, which is only a dev_dependency of the engine package and does not resolve from the root package config. Either exclude `packages/**` from the root analyzer in analysis_options.yaml or add `test` as a root dev_dependency. `dart test` inside packages/arena_engine passes (57/57); `flutter analyze lib test` is clean.
Reason: pre-existing on main since the lane-1 engine merges; lane 2 cannot edit analysis_options.yaml or pubspec.yaml.
Status: answered — orchestrator excluded `packages/**` from the root analyzer (analysis_options.yaml); the engine package keeps its own analysis and `dart test` (57/57).
```

```text
Lane: orchestrator (with lane 1 and lane 2)
Blocking PR: v0.3 timed-turn engine change
Request: Lane 5 checked the online sync against timed turns (docs/contract.md §3). MatchStore/MatchSession, the move log, finals and forfeit are move-entry based and stay valid. Items that still assume 5 rounds x 3 moves and must land with the engine change:
  1. backend/firestore.rules:126 hard-codes the old `MatchConfig.duel().fingerprint` ('v1|7x7|c5|r5|m3|...') and `engineVersion == 1`; MatchSession rejects any other config as `unknown_version`. When lane 1 changes the duel config, lane 5 must update the rules literal (and engine/contract version) in the same merge or every room claim is denied.
  2. Rules `validMove` accepts only `swap` and `power`. The explicit end-turn action needs its exact `Move.toJson()` shape from lane 1 so lane 5 can allow it; until then an end-turn entry is denied.
  3. The 30 s turn timer is not in the engine (no clock). Contract should say: the active player's client writes the end-turn entry when its timer expires; the opponent cannot enforce 30 s, only the 24 h forfeit (`roundLimit`). Decide whether a shorter live forfeit is wanted.
  4. `onMoveCreated` (backend/functions) pushes "your turn" on every log entry; with free swaps that is one push per swap. Needs authorizing lane 5 to push only when the entry's `next` becomes the recipient.
  5. Naming only, lib/online (not changed now): `roundLimit` = 24 h since the last entry; `liveMoveLimit` (30 s) is now the per-turn budget, so lane 2 should show it per turn, not per move.
  6. Lane 1's `summarizeLog` returns `RoundMoveLog`s and lane 2's `match_controller` exposes `round`/`totalRounds`; both need the turn model. test/online_test.dart no longer reads `state.round`.
Reason: docs/contract.md now uses timed turns; lane 5 was asked not to change lib/online production code in this pass.
Status: open
```

```text
Lane: 3
Blocking PR: lane-3 shell/lobby rework
Request: (1) Resolved on main already — bdd4779 moved the sprites to assets/images/ and pubspec now bundles them; bbbbc324 whitelisted assets/images/ in the shared artwork checker, so lane 3 dropped its local expectCleanShellArtwork workaround and uses expectCleanArtwork again. (2) FYI, no change requested: the VS mockup stakes differ from the contract — implemented +30 win / 0 draw / -25 loss exactly per docs/contract.md and AGENTS.md decision 1. (3) Optional follow-up for lane 2/orchestrator: match_screen.dart:346 still routes the in-match trophy badge to the old showTrophyRoad() dialog; consider pointing it at HouseTourScreen for consistency (lane-2 file, untouched by lane 3).
Reason: lane-3 owns only the listed shell files; the in-match HUD lives in lane-2's match_screen.dart.
Status: open
```

```text
Lane: 2
Blocking PR: lane-2 timed-turn duel (this PR)
Request: In lib/profile.dart `Player.result`, change the loss stake from -10 to -25 trophies (win +30, draw 0, loss -25), keeping the existing house-tour floor.
Reason: The timed-turn contract decision fixes stakes at +30/0/-25; the older -10 value predates the decision. lib/profile.dart is orchestrator-owned.
Status: open
```

```text
Lane: 2
Blocking PR: lane-2 timed-turn duel (this PR)
Request: Lane 5 — `MatchSession` creates online matches with `MatchConfig.duel()`, which now means firstPower/secondPower = zoomies/zoomies, so the cat's chosen power is ignored online. To carry the loadout, the match record needs each player's chosen power index (0-2, preset-safe) at open time, and `MatchConfig` built from them before `newMatch` — or the session accepts an optional `power` argument. lib/online is off-limits for lane 2; until this lands, friend duels fire zoomies for both cats (still equal-strength, no advantage).
Reason: contract decision: each cat brings one power chosen in the cat editor; the power must be identical on both clients for hash agreement.
Status: open
```

```text
Lane: 2
Blocking PR: lane-2 timed-turn duel (this PR)
Request: Lane 5 — update test/online_test.dart for the timed-turn move model: a player's turn is now a 30-second window of unlimited swaps that ends ONLY via `EndTurnMove`, so two lane-5 tests encode the old per-move alternation and fail: (a) "watch and play together count each move once" — `guest.play` right after `host.play` now throws MatchException(notYourTurn), which is correct new behavior; insert `engine.EndTurnMove()` before the guest's move. (b) "forfeit only after the 24-hour limit" — after `host.play` the host still holds the turn, so `host.claimForfeit()` throws notYourTurn at match_sync.dart:150; under timed turns it is the GUEST who claims after the host's deadline passes (forfeitWinner flips accordingly). lib/online itself needed no changes: `isMyTurn`/`deadline`/`claimForfeit`/`flag` semantics already map to the new model unchanged.
Reason: test/online_test.dart and lib/online are not in lane-2 ownership; the engine move model changed per the approved contract while the session surface stayed identical.
Status: open
```

```text
Lane: 2
Blocking PR: lane-2 timed-turn duel (this PR)
Request: Whitelist `assets/images/` in the runtime bundle (pubspec assets section) and let lane 1 place `tile_*.png` piece sprites + `tile_box.png` + `cat_run.png` there. BoardView already tries assets/images/ first and falls back to assets/generated/; MatchScreen's power-runner tries `assets/images/cat_run.png` then falls back to a procedural cat. Nothing breaks without it — the fallbacks keep working — but the mockup art path stays dark until the folder is whitelisted.
Reason: docs/contract.md battle-screen spec references assets/images/tile_*.png and cat_* sprites; only the orchestrator (or lane 1 by exception) may edit the pubspec assets section.
Status: answered — assets/images/ is bundled (bdd4779) and whitelisted (bbbc324); cat_run.png is absent so the procedural fallback runs — add the sprite later if desired.
```
