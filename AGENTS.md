# Project workflow

- Flutter SDK in this Windows workspace: `C:/flutter/bin/flutter.bat`; Dart: `C:/flutter/bin/dart.bat`.
- Generate transparent sprites, launcher icons, and synthesized purr: `C:/flutter/bin/dart.bat run tool_assets.dart`.
- Verify: `flutter analyze`, `flutter test`, `flutter build web --release`.
- Android build: `flutter build apk --release`. This machine has a locally installed JDK at `C:/Users/9then/AppData/Local/CatPawsBuild/jdk-17.0.17+10` and Android SDK at `C:/Users/9then/AppData/Local/CatPawsBuild/android-sdk`; pass these as `JAVA_HOME` and `ANDROID_HOME` for builds. SDK licenses were accepted with explicit user approval.
- APK delivery: only the orchestrator builds a release APK. It is attached to a GitHub Release and never committed to the repository. Lanes never push to `main`. Communicate with the user in Romanian. Do not publish a failed or unverified build.

End state: a cat owner plays a short, fair duel as their own cat, against a friend or a clearly labelled house cat, and comes back tomorrow. See [the plan](docs/plan.md) and [the shared contract](docs/contract.md).

## Agreed decisions

1. Five rounds of three moves on separate boards, same seed for both players. Obstacles earned in a round land at the start of the opponent's next round.
2. Flat points per piece, no cascade multiplier. Colour count (5 or 6) and the rainbow rule are configurable.
3. Friends use six-character codes; house cats are labelled bots. No ranked play against strangers.
4. Three free powers of equal strength; none is sold.
5. Cosmetic bundles use LEI prices. Paws are earned in play and never sold. No ads.
6. No free-text chat, trading, or teams. Preset emotes only.
7. Children and adults: Google Play Families policy, no advertising ID or ad SDKs, preset names only for player-visible names, no typed text shown to other players, and no countdown offers or pressure to buy.
8. Studio: One Ear Games. Application ID: `games.oneear.catpawsarena`.
9. Backend is proposed by lane 5 and approved by the orchestrator. Game rules are pure Dart; a match is a seed plus a move log.

## Parked scope

Ranked matchmaking, server-side validation as a separate deliverable, teams, chat, trading, tournaments, Speed Rush, Survival, High-Stakes, paws packs sold for money, Facebook login, photo avatars, iOS, seasons, and passes. No lane builds or re-enables parked work. Do not advertise existing parked surfaces as live services.

## Ownership and parallel work

- Orchestrator: `AGENTS.md`, `README.md`, `docs/`, `pubspec.yaml`, `lib/main.dart`, `lib/profile.dart`, `lib/catalog.dart`.
- Lane 1: `packages/arena_engine/`.
- Lane 2: `lib/match_screen.dart`, `lib/board_game.dart`, `lib/match_controller.dart`, `lib/arena.dart`, `assets/audio/`, `test/duel_test.dart`.
- Lane 3: `lib/cats_screen.dart`, `lib/cat_avatar.dart`, `assets/cats/`, `test/cats_test.dart`.
- Lane 4: `lib/home_screen.dart`, `lib/lobby_screen.dart`, `lib/shop_screen.dart`, `lib/app_dialogs.dart`, `lib/ui_widgets.dart`, `lib/boot_screen.dart`, `lib/team_screen.dart`, `lib/events_screen.dart`, `lib/local_play.dart`, `lib/shell/`, `test/shell_test.dart`.
- Lane 5: `.github/`, `lib/online/`, `backend/`, `android/`, `test/online_test.dart`.

The existing splash/build metadata may still display Paws & Claws or the previous application ID. Lane 5 owns Android identity; the orchestrator coordinates the studio splash with lane 2 and records completion only after verified integration. Do not claim the identity migration is complete at setup.

Stay within lane ownership. New dependencies may add lines to `pubspec.yaml` only with justification and review. Lanes never push to `main` or build another lane's features. Only the orchestrator changes `docs/contract.md` and announces every change. After each accepted merge, other lanes rebase on `main`. Submit cross-lane requests in `docs/requests.md`.

The orchestrator reviews pull requests against their Done-when checks and file lists, merges one at a time, answers shared-file requests, and reports blockers in Romanian. Human playtests are required; the orchestrator never marks a gate as passed. Gate 1 is 3 of 5 new players starting a second match without being asked.

- Preserve original assets. Most original files end in `.png.jpg`; generated transparent sprites live in `assets/generated/`.
- Current online interfaces explicitly report unavailable services. Do not represent local bot practice, purchases, rankings, chat, cloud sync, or tournaments as live services.
- Player data uses local shared preferences. Real-money billing, server-authoritative economy/PvP, identity providers, and moderation require separate service configuration.
- Human gate evidence is recorded without marking gates passed. Human playtests and release approval remain separate. See the gate table in [the plan](docs/plan.md).
- Never render full UI mockups (`assets/ui_*.png.jpg`) behind interactive widgets. They are reference-only and excluded from the runtime asset bundle. `RoomBackground` paints a clean room from code; `PlayerHud`, `ArenaBottomBar`, `ArenaButton`, and `ProductCard` are reusable interactive widgets in `lib/ui_widgets.dart`.
- UI regression tests cover 320×568, 360×640, 390×844, and 430×932 at 1× and 1.5× text scaling, plus shop interaction, aligned IAP buttons, profile disposal, and match/result screens. The runtime bundle may contain only `assets/generated/` individual sprites/audio and `assets/fonts/` Nunito variable fonts; full-screen reference images, including splash artwork, are excluded.
- `main.dart` only bootstraps the app. `home_screen.dart` owns navigation; lobby/shop/cats/team/events/boot/match have dedicated screen modules. `match_controller.dart`, `board_game.dart`, and `arena.dart` are lane-2 legacy until migrated to `packages/arena_engine`. `cat_avatar.dart` is lane-3; `catalog.dart` and `profile.dart` are orchestrator-owned shared contracts; `app_dialogs.dart` is lane-4. `team_screen.dart`, `events_screen.dart`, and `local_play.dart` are parked social surfaces: do not advertise them as live chat, trading, or tournaments and do not extend them into the friend-duel loop.
- Local browser review tooling: Playwright Core 1.55.1 is installed at `C:/Users/9then/AppData/Local/CatPawsBuild/playwright-1.55.1/package/cli.js`; use Node with `screenshot --channel msedge --viewport-size 390,844 --wait-for-timeout 8000 <local URL> <build screenshot path>`. Browser previews do not replace Android physical-device performance testing.
