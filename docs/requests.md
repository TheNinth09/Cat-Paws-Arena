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
Status: open
```

```text
Lane: 4
Blocking PR: lane-4 branch (Slice 1 freeze)
Request: In lib/match_screen.dart, remove the unused top-level `_goldGradient` declaration at line 26 (or use it) so `flutter analyze` is clean.
Reason: `flutter analyze` currently fails with `unused_element` on `_goldGradient`; the file is lane-2 owned and lane 4 cannot edit it. Slice 1 done-when requires a clean analyzer.
Status: answered — assigned to lane-2; pre-existing warning documented in docs/baseline.md; CI runs analyze non-fatally until lane-2 fixes it. Does not block lane-4 (merged).
```

```text
Lane: 5
Blocking PR: lane-5 (slice 1: CI and release hygiene)
Request: Lane 2 removes the unused `_goldGradient` declaration in `lib/match_screen.dart:26`.
Reason: `flutter analyze` exits 1 on this pre-existing warning (see docs/baseline.md). CI runs `flutter analyze --no-fatal-warnings` until it is fixed; lane 5 will then make warnings fatal again in `.github/workflows/ci.yml`.
Status: answered — lane-2 owns `lib/match_screen.dart` and should remove or use `_goldGradient` in its duel PR; orchestrator will switch CI back to fatal warnings after that lands.
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
Status: open — assigned to lane-2; does not block lane-5 slice 3a.
```

```text
Lane: 4
Blocking PR: lane-4 slice 2 (House Tour)
Request: In lib/profile.dart, change `Player.result` so a win adds 30 trophies, a loss subtracts 10, and trophies never fall below the floor of the highest House Tour room already reached.
Reason: Slice 2 gates House Tour rooms by trophies; lane 4 cannot edit orchestrator-owned `lib/profile.dart`.
Status: answered — implemented on main in 31a26b1 (`Player.result` floors trophies at `[0, 300, 800, 1500]` with +30/-10 deltas).
```
