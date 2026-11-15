# Baseline — before lane setup

Recorded on `setup/one-ear-foundation`, from `main` at `2c78d3311c1687d0af83df897c63d2e99b3363f0`.

## Environment

- Flutter 3.47.7 stable, Dart 3.13.5, Windows.
- Verification uses `/c/flutter/bin/flutter.bat`; there was no Flutter/Dart on the general PATH during this session.
- No source corrections, feature development, APK build, release publication, or playtest were performed for this baseline.

## Static analysis

Command: `/c/flutter/bin/flutter.bat analyze`

Result: **exit 1; one warning, zero errors.** Analysis completed after 46.0 seconds.

`lib/match_screen.dart:26` reports unused `_goldGradient`. This warning exists before the setup changes and is deliberately left for a lane to address within its file ownership.

After recording this baseline, the requested setup replaces `test/widget_test.dart` with the four lane test files. The test bodies and assertions are preserved; only imports and a small shared artwork assertion helper are separated. The original file contained 12 named tests; the navigation test runs eight cases across four viewport sizes and two text scales, giving 19 executed tests. Setup verification is recorded below.

## Setup verification

On `setup/one-ear-foundation` after the reorganization, `flutter test` passed all **14 tests** with no skipped tests reported. `flutter analyze` reported **one warning and zero errors**: the pre-existing unused `_goldGradient` declaration in `lib/match_screen.dart`. This is the same analyzer finding as the baseline, now applied to the reorganized tree. The warning is intentionally left for the owning lane rather than changed during setup.

No gameplay fixes, APK builds, GitHub Releases, or human playtests were performed as part of setup.

## Tests

Command: `/c/flutter/bin/flutter.bat test`

Result: **exit 0; all 19 tests passed**, with no skipped tests reported. Total reported test time: 8 seconds.

| Test | Result |
| --- | --- |
| Runtime bundle contains only sprites and fonts | Passed |
| Match pause reasons compose and results reward only once | Passed |
| Clean adaptive navigation, 320×568 at 1× and 1.5× text scale | Both passed |
| Clean adaptive navigation, 360×640 at 1× and 1.5× text scale | Both passed |
| Clean adaptive navigation, 390×844 at 1× and 1.5× text scale | Both passed |
| Clean adaptive navigation, 430×932 at 1× and 1.5× text scale | Both passed |
| Profile edits close safely and preserve the player name | Passed |
| Shop reward and IAP cards are real interactive widgets | Passed |
| VS, gameplay and result never render screen mockups | Passed |
| Bot moves resolve cascades and recover blocked boards | Passed |
| Boards start without matches and always have a legal move | Passed |
| Nonadjacent and nonmatching swaps do not mutate the board | Passed |
| Line detection, cascades, charge and four-match attacks | Passed |
| Obstacles clear next to a match | Passed |
| Rewards, daily limits, purchases, tiers and persistence | Passed |

The asset test currently restricts bundled artwork to `assets/generated/` and `assets/fonts/`. Passing this test is not proof that online, release, or family-policy requirements are implemented.

## Scope and limitations

This is a baseline of the existing offline prototype, not acceptance of the proposed end state. The engine currently combines board mutation and presentation in `lib/arena.dart`; the contract's new pure Dart package has not been implemented.

The existing shop contains purchasable paws/coins and billing messaging, teams/events/local simulation exist, and the app identity/build configuration still reflects the prior release. These observations are inputs to the plan; no fixes or removals were made during baseline collection.

Flutter web release compilation and Android APK compilation were not repeated here because no application behavior was changed. Historical successful builds do not establish readiness of the proposed release or physical-device performance. Human playtests and Gate 1 remain unrun and unmarked as passed.
