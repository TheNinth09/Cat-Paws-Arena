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
