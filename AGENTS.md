# Project workflow

- Flutter SDK in this Windows workspace: `C:/flutter/bin/flutter.bat`; Dart: `C:/flutter/bin/dart.bat`.
- Generate transparent sprites, launcher icons, and synthesized purr: `C:/flutter/bin/dart.bat run tool_assets.dart`.
- Verify: `flutter analyze`, `flutter test`, `flutter build web --release`.
- Android build: `flutter build apk --release`. This machine has a locally installed JDK at `C:/Users/9then/AppData/Local/CatPawsBuild/jdk-17.0.17+10` and Android SDK at `C:/Users/9then/AppData/Local/CatPawsBuild/android-sdk`; pass these as `JAVA_HOME` and `ANDROID_HOME` for builds. SDK licenses were accepted with explicit user approval.
- Android release signing currently uses Flutter's generated debug key for internal APK testing only; production distribution requires the owner's release signing configuration.
- User standing instruction: after every verified APK update, commit the corresponding source changes and replace the tracked `build/app/outputs/flutter-apk/app-release.apk` on GitHub by pushing to `origin/main`. Keep the same download path and increment the app version for updates. Do not publish a failed or unverified build. Communicate with the user in Romanian.
- Preserve original assets. Most original files end in `.png.jpg`; generated transparent sprites live in `assets/generated/`.
- Current online interfaces explicitly report unavailable services. Do not represent local bot practice, purchases, rankings, chat, cloud sync, or tournaments as live services.
- Player data uses local shared preferences. Real-money billing, server-authoritative economy/PvP, identity providers, and moderation require separate service configuration.
- Do not promise locked 60fps without profiling release builds on physical target Android devices.
- Never render full UI mockups (`assets/ui_*.png.jpg`) behind interactive widgets. They are reference-only and excluded from the runtime asset bundle. `RoomBackground` paints a clean room from code; `PlayerHud`, `ArenaBottomBar`, `ArenaButton`, and `ProductCard` are reusable interactive widgets in `lib/ui_widgets.dart`.
- UI regression tests cover 320×568, 360×640, 390×844, and 430×932 at 1× and 1.5× text scaling, plus shop interaction and match/result screens.
