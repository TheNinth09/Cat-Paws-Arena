import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Player extends ChangeNotifier {
  Player(this.prefs) {
    final raw = prefs.getString('player');
    if (raw != null) {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      name = d['name'] ?? 'Alex';
      trophies = d['trophies'] ?? 0;
      coins = d['coins'] ?? 500;
      cat = d['cat'] ?? 'Tzuki';
      accessory = d['accessory'] ?? '';
      daily = d['daily'] ?? '';
      owned = Set<String>.from(d['owned'] ?? []);
      claims = Set<int>.from(d['claims'] ?? []);
      fur = d['fur'] ?? 0;
      eyes = d['eyes'] ?? 0;
      ears = d['ears'] ?? 1;
      pattern = d['pattern'] ?? 0;
      power = d['power'] ?? 0;
      sfx = d['sfx'] ?? true;
      music = d['music'] ?? true;
      english = d['english'] ?? false;
      notifications = d['notifications'] ?? false;
      photo = d['photo'];
      avatarSpec = d['avatarSpec'] ?? '';
    }
  }
  final SharedPreferences prefs;
  String name = 'Alex', cat = 'Tzuki', accessory = '', daily = '';
  String? photo;
  String avatarSpec = '';
  int trophies = 0,
      coins = 500,
      fur = 0,
      eyes = 0,
      ears = 1,
      pattern = 0,
      power = 0;
  bool sfx = true, music = true, english = false, notifications = false;
  Set<String> owned = {};
  Set<int> claims = {};
  int get tier => trophies >= 1500
      ? 3
      : trophies >= 800
      ? 2
      : trophies >= 300
      ? 1
      : 0;
  int get next => [300, 800, 1500, 2000][tier];
  String get room =>
      ['Living', 'Holul Principal', 'Bucătăria', 'Dormitorul Stăpânului'][tier];
  String get today => DateTime.now().toIso8601String().substring(0, 10);
  Future<void> save() async {
    notifyListeners();
    await prefs.setString(
      'player',
      jsonEncode({
        'name': name,
        'trophies': trophies,
        'coins': coins,
        'cat': cat,
        'accessory': accessory,
        'daily': daily,
        'owned': owned.toList(),
        'claims': claims.toList(),
        'fur': fur,
        'eyes': eyes,
        'ears': ears,
        'pattern': pattern,
        'power': power,
        'sfx': sfx,
        'music': music,
        'english': english,
        'notifications': notifications,
        'photo': photo,
        'avatarSpec': avatarSpec,
      }),
    );
  }

  bool buy(String item, int price) {
    if (owned.contains(item) || coins < price) return false;
    coins -= price;
    owned.add(item);
    save();
    return true;
  }

  bool claimDaily() {
    if (daily == today) return false;
    daily = today;
    coins += 200;
    save();
    return true;
  }

  void result(int outcome) {
    const trophyFloors = [0, 300, 800, 1500];
    final floor = trophyFloors.lastWhere((t) => trophies >= t);
    final delta = outcome > 0 ? 30 : outcome < 0 ? -25 : 0;
    trophies = (trophies + delta).clamp(floor, 1000000);
    if (outcome > 0) coins += 150;
    save();
  }
}
