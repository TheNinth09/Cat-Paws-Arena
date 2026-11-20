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
      haptics = d['haptics'] ?? true;
      photo = d['photo'];
      avatarSpec = d['avatarSpec'] ?? '';
      avatarArt = d['avatarArt'] ?? '';
      gamesPlayed = d['gamesPlayed'] ?? 0;
      gamesWon = d['gamesWon'] ?? 0;
      winStreak = d['winStreak'] ?? 0;
      bestStreak = d['bestStreak'] ?? 0;
      bestScore = d['bestScore'] ?? 0;
      roadClaims = Set<int>.from(d['roadClaims'] ?? []);
      unlockedEmotes = Set<String>.from(
        d['unlockedEmotes'] ?? baseEmotes,
      )..addAll(baseEmotes);
    }
  }
  final SharedPreferences prefs;
  String name = 'Alex', cat = 'Tzuki', accessory = '', daily = '';
  String? photo;
  String avatarSpec = '';
  String avatarArt = '';
  int trophies = 0,
      coins = 500,
      fur = 0,
      eyes = 0,
      ears = 1,
      pattern = 0,
      power = 0,
      gamesPlayed = 0,
      gamesWon = 0,
      winStreak = 0,
      bestStreak = 0,
      bestScore = 0;
  bool sfx = true,
      music = true,
      english = false,
      notifications = false,
      haptics = true;
  Set<String> owned = {};
  Set<int> claims = {};

  /// Trophy-road milestones already claimed (threshold values).
  Set<int> roadClaims = {};

  /// The six standard duel emotes every cat (Tzuki, Bubble…) starts with.
  static const baseEmotes = {
    'hello',
    'good_game',
    'wow',
    'oops',
    'thanks',
    'purr',
  };

  /// Duel emote wire values the player may send — the standard six, plus
  /// any extras unlocked along the trophy road.
  Set<String> unlockedEmotes = Set<String>.of(baseEmotes);
  int get tier => trophies >= 4000
      ? 4
      : trophies >= 3000
      ? 3
      : trophies >= 2000
      ? 2
      : trophies >= 1000
      ? 1
      : 0;
  int get next => [1000, 2000, 3000, 4000, 6000][tier];
  String get room => [
    'Living',
    'Holul Principal',
    'Bucătăria',
    'Dormitorul Stăpânului',
    'Culoarul de Sus',
  ][tier];
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
        'haptics': haptics,
        'photo': photo,
        'avatarSpec': avatarSpec,
        'avatarArt': avatarArt,
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'winStreak': winStreak,
        'bestStreak': bestStreak,
        'bestScore': bestScore,
        'roadClaims': roadClaims.toList(),
        'unlockedEmotes': unlockedEmotes.toList(),
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

  /// Daily gift cadence: +5 paws every 6 hours (owner decision; `daily`
  /// stores the last-claim ISO timestamp — old `yyyy-MM-dd` values keep
  /// working by parsing as that day's start).
  DateTime? get _lastDaily {
    final full = DateTime.tryParse(daily);
    return full ?? DateTime.tryParse('$daily 00:00:00Z');
  }

  bool get dailyReady {
    final last = _lastDaily;
    return last == null || DateTime.now().difference(last).inHours >= 6;
  }

  bool claimDaily() {
    if (!dailyReady) return false;
    daily = DateTime.now().toIso8601String();
    coins += 5;
    save();
    return true;
  }

  void result(int outcome, {int score = 0}) {
    const trophyFloors = [0, 1000, 2000, 3000, 4000];
    final floor = trophyFloors.lastWhere((t) => trophies >= t);
    final delta = outcome > 0
        ? 30
        : outcome < 0
        ? -25
        : 0;
    trophies = (trophies + delta).clamp(floor, 1000000);
    gamesPlayed++;
    if (outcome > 0) {
      coins += 150;
      gamesWon++;
      winStreak++;
      if (winStreak > bestStreak) bestStreak = winStreak;
    } else if (outcome < 0) {
      winStreak = 0;
    }
    if (score > bestScore) bestScore = score;
    save();
  }

  /// Claim a trophy-road milestone: small paw-coin gifts, emote unlocks
  /// and one accessory per finished room. Returns false when the
  /// threshold is not reached or the node was already claimed.
  bool claimRoad(int threshold, {int coinGift = 0, String? emote, String? gear}) {
    if (trophies < threshold || roadClaims.contains(threshold)) {
      return false;
    }
    roadClaims.add(threshold);
    coins += coinGift;
    if (emote != null) unlockedEmotes.add(emote);
    if (gear != null) owned.add(gear);
    save();
    return true;
  }
}
