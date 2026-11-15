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
Lane: 2
Blocking PR: lane-2-slice-3 (slice 3: feel)
Request: Resolved in lane-2-s2 — the 16 SFX WAVs and CREDITS.md moved to assets/generated/audio/ (bundled via the existing assets/generated/ entry), so no pubspec audio line is needed and other lanes' bundle-whitelist tests stay green.
Reason: Lane 2 owns the audio assets; keeping them under assets/generated/ matches the AGENTS.md runtime-bundle rule ("assets/generated/ individual sprites/audio") and avoids editing lane-3/lane-4 test whitelists.
Status: answered — superseded by the generated/audio move on lane-2-s2.
```

```text
Lane: 2
Blocking PR: lane-2-s2 (slice 2: arena engine duel)
Request: Keep `arena_engine: path: packages/arena_engine` in pubspec.yaml when this branch merges — slice 2 cannot compile without the local package dependency. The slice-3 SFX moved from assets/audio/ to assets/generated/audio/ so the runtime bundle stays inside the assets/generated/ + assets/fonts/ whitelist without touching other lanes' tests; pubspec needs no audio line. Also: lane 1 fixes two `unnecessary_const` infos in packages/arena_engine/lib/src/engine.dart:61,63 (or the orchestrator excludes packages/** from the root analyzer), otherwise `flutter analyze` reports 2 info issues owned by lane 1.
Reason: The vendored engine package is lane-1 code; the analyzer lints live there, not in lane-2 files.
Status: open
```
