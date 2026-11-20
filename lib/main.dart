import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'online/online_config.dart';
import 'online/online_errors.dart';
import 'profile.dart';
import 'shell/online_play.dart';
import 'studio_intro.dart';
import 'ui_widgets.dart';

export 'boot_screen.dart' show Boot;
export 'studio_intro.dart' show StudioIntro;
export 'cat_avatar.dart' show CatAvatar, CatCharacter;
export 'home_screen.dart' show Home;
export 'match_screen.dart' show MatchScreen;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Full immersive mode: no status bar (clock/battery) and no nav bar —
  // the art climbs to the screen edges and no band sits above the HUD
  // or under the nav bar. A swipe from an edge reveals them transiently.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Transparent system bars everywhere — the default nav-bar colour shows as
  // a dark band at the bottom (and a scrim at the top) on many devices.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // Ask Android for the panel's highest refresh mode — without this many
  // phones pin Flutter to 60 Hz and the game reads as stuttery.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } on Object {
      // Unsupported or virtualized displays: keep the default mode.
    }
  }
  OnlineServices? online;
  try {
    online = await OnlineServices.start();
  } catch (_) {
    online = null;
  }
  if (online != null) {
    OnlinePlay.services = OnlinePlayServices(
      account: online.account,
      rooms: online.rooms,
      online: online,
      googleCredential: () async {
        try {
          return await online!.google.pick();
        } on OnlineException catch (error) {
          if (error.code == OnlineErrorCode.cancelled) return null;
          rethrow;
        }
      },
    );
  }
  final player = Player(await SharedPreferences.getInstance());
  runApp(CatPawsApp(player: player));
}

class CatPawsApp extends StatelessWidget {
  const CatPawsApp({super.key, required this.player});
  final Player player;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cat Paws Arena • One Ear Games',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: gold),
      scaffoldBackgroundColor: ink,
      fontFamily: 'Nunito',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: ink),
      ),
    ),
    home: StudioIntro(player: player),
  );
}
