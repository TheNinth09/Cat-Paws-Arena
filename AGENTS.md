# Project workflow

- Flutter SDK in this Windows workspace: `C:/flutter/bin/flutter.bat`; Dart: `C:/flutter/bin/dart.bat`.
- Generate transparent sprites, launcher icons, and synthesized purr: `C:/flutter/bin/dart.bat run tool_assets.dart`.
- Verify: `flutter analyze`, `flutter test`, `flutter build web --release`.
- Android build: `flutter build apk --release`. This machine has a locally installed JDK at `C:/Users/9then/AppData/Local/CatPawsBuild/jdk-17.0.17+10` and Android SDK at `C:/Users/9then/AppData/Local/CatPawsBuild/android-sdk`; pass these as `JAVA_HOME` and `ANDROID_HOME` for builds. SDK licenses were accepted with explicit user approval.
- Android release signing currently uses Flutter's generated debug key for internal APK testing only; production distribution requires the owner's release signing configuration.
- Preserve original assets. Most original files end in `.png.jpg`; generated transparent sprites live in `assets/generated/`.
- Current online interfaces explicitly report unavailable services. Do not represent local bot practice, purchases, rankings, chat, cloud sync, or tournaments as live services.
- Player data uses local shared preferences. Real-money billing, server-authoritative economy/PvP, identity providers, and moderation require separate service configuration.
- Do not promise locked 60fps without profiling release builds on physical target Android devices.
