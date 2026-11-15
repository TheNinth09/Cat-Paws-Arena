import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'boot_screen.dart';
import 'profile.dart';
import 'ui_widgets.dart';

export 'boot_screen.dart' show Boot, StudioSplash;
export 'cat_avatar.dart' show CatAvatar, CatCharacter;
export 'home_screen.dart' show Home;
export 'match_screen.dart' show MatchScreen;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final player = Player(await SharedPreferences.getInstance());
  runApp(CatPawsApp(player: player));
}

class CatPawsApp extends StatelessWidget {
  const CatPawsApp({super.key, required this.player});
  final Player player;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cat Paws Arena • Paws & Claws',
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
    home: Boot(player: player),
  );
}
