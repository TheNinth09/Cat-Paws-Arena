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
Blocking PR: lane-4 slice 2 (House Tour)
Request: In lib/profile.dart, change `Player.result` so a win adds 30 trophies, a loss subtracts 10 (currently 25), and trophies never fall below the floor of the highest House Tour room already reached. Exact change: before applying `outcome`, compute `floor` as the greatest House Tour threshold (`0`, `300`, `800`, `1500`) that is `<= trophies`; then set `trophies = (trophies + delta).clamp(floor, 1000000)` where `delta` is `+30` for a win and `-10` for a loss.
Reason: Slice 2 gates House Tour rooms by trophies; lane 4 cannot edit orchestrator-owned `lib/profile.dart`.
Status: open
```

```text
Lane: 4
Blocking PR: lane-4 slice 2 (House Tour)
Request: In lib/match_screen.dart and lib/match_controller.dart, accept an optional house-cat opponent (name, trophies, and avatar fields) so `MatchScreen` can start against the selected `HouseCat` instead of always using `Bubble Bot`. Minimal change: add an optional opponent/player parameter to `MatchScreen`, pass it to `ArenaMatchController`, and use `opponent.name`/`opponent.trophies` for the bot label and `botTrophies`.
Reason: Slice 2 lobby offers named resident house cats; lane 4 owns lobby/home but cannot edit lane-2 match files.
Status: open
```
