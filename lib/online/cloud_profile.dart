import '../cat_avatar.dart';
import '../catalog.dart';
import '../profile.dart';
import 'online_errors.dart';

/// The cat and progress that are saved to the cloud. Typed names and photos
/// stay on the device and are never part of this record.
class CloudProfile {
  const CloudProfile({
    required this.trophies,
    required this.coins,
    required this.cat,
    required this.accessory,
    required this.fur,
    required this.eyes,
    required this.ears,
    required this.pattern,
    required this.power,
    required this.owned,
    required this.claims,
    required this.daily,
    required this.sfx,
    required this.music,
    required this.english,
    required this.notifications,
    this.avatar = '',
    this.revision = 0,
  });

  static const schemaVersion = 1;
  static const maxIdLength = 64;
  static const maxListLength = 512;

  /// Values the cat screen and avatar can draw (lib/cats_screen.dart,
  /// lib/cat_avatar.dart). Anything else is not a save this app made.
  static const cats = {'Tzuki', 'Bubble', 'Custom'};
  static final furCount = catFurColours.length,
      eyesCount = catEyeColours.length;
  static const patternCount = catPatternCount, earsCount = catEarCount;

  final int trophies, coins, fur, eyes, ears, pattern, power, revision;
  final String cat, accessory, daily;
  final Set<String> owned;
  final Set<int> claims;
  final bool sfx, music, english, notifications;
  final String avatar;

  factory CloudProfile.fromPlayer(Player p, {int revision = 0}) => CloudProfile(
    trophies: p.trophies,
    coins: p.coins,
    cat: p.cat,
    accessory: p.accessory,
    fur: p.fur,
    eyes: p.eyes,
    ears: p.ears,
    pattern: p.pattern,
    power: p.power,
    owned: {...p.owned},
    claims: {...p.claims},
    daily: p.daily,
    sfx: p.sfx,
    music: p.music,
    english: p.english,
    notifications: p.notifications,
    avatar: p.avatarSpec,
    revision: revision,
  );

  /// Copies the cloud fields into [p] and saves it. Leaves the local name
  /// and photo alone.
  Future<void> applyTo(Player p) {
    p
      ..trophies = trophies
      ..coins = coins
      ..cat = cat
      ..accessory = accessory
      ..fur = fur
      ..eyes = eyes
      ..ears = ears
      ..pattern = pattern
      ..power = power
      ..owned = {...owned}
      ..claims = {...claims}
      ..daily = daily
      ..sfx = sfx
      ..music = music
      ..english = english
      ..notifications = notifications
      ..avatarSpec = avatar;
    return p.save();
  }

  CloudProfile withRevision(int value) => CloudProfile(
    trophies: trophies,
    coins: coins,
    cat: cat,
    accessory: accessory,
    fur: fur,
    eyes: eyes,
    ears: ears,
    pattern: pattern,
    power: power,
    owned: owned,
    claims: claims,
    daily: daily,
    sfx: sfx,
    music: music,
    english: english,
    notifications: notifications,
    avatar: avatar,
    revision: value,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'revision': revision,
    'trophies': trophies,
    'coins': coins,
    'cat': cat,
    'accessory': accessory,
    'fur': fur,
    'eyes': eyes,
    'ears': ears,
    'pattern': pattern,
    'power': power,
    'owned': owned.toList()..sort(),
    'claims': claims.toList()..sort(),
    'daily': daily,
    'sfx': sfx,
    'music': music,
    'english': english,
    'notifications': notifications,
    'avatar': avatar,
  };

  static const _keys = {
    'schemaVersion',
    'revision',
    'trophies',
    'coins',
    'cat',
    'accessory',
    'fur',
    'eyes',
    'ears',
    'pattern',
    'power',
    'owned',
    'claims',
    'daily',
    'sfx',
    'music',
    'english',
    'notifications',
    'avatar',
  };

  /// Strict parse: unknown keys, wrong types or an unknown schema version
  /// throw [OnlineException] with [OnlineErrorCode.invalidCloudSave].
  factory CloudProfile.fromJson(Map<String, Object?> json) {
    Never bad(String why) =>
        throw OnlineException(OnlineErrorCode.invalidCloudSave, why);
    final extra = json.keys.toSet().difference(_keys);
    if (extra.isNotEmpty) bad('unknown keys $extra');
    if (json['schemaVersion'] != schemaVersion) bad('schemaVersion');
    int count(String k) {
      final v = json[k];
      return v is int && v >= 0 ? v : bad(k);
    }

    int option(String k, int count) {
      final v = json[k];
      return v is int && v >= 0 && v < count ? v : bad(k);
    }

    bool flag(String k) {
      final v = json[k];
      return v is bool ? v : bad(k);
    }

    String id(Object? v, String k) =>
        v is String && v.length <= maxIdLength && !v.contains(_control)
        ? v
        : bad(k);
    List<Object?> list(String k) {
      final v = json[k];
      return v is List && v.length <= maxListLength ? v : bad(k);
    }

    return CloudProfile(
      revision: count('revision'),
      trophies: count('trophies'),
      coins: count('coins'),
      cat: cats.contains(json['cat']) ? json['cat'] as String : bad('cat'),
      accessory: id(json['accessory'], 'accessory'),
      fur: option('fur', furCount),
      eyes: option('eyes', eyesCount),
      ears: option('ears', earsCount),
      pattern: option('pattern', patternCount),
      power: option('power', powers.length),
      owned: {for (final v in list('owned')) id(v, 'owned')},
      claims: {
        for (final v in list('claims')) v is int && v >= 0 ? v : bad('claims'),
      },
      daily: id(json['daily'], 'daily'),
      sfx: flag('sfx'),
      music: flag('music'),
      english: flag('english'),
      notifications: flag('notifications'),
      avatar: _avatar(json['avatar']),
    );
  }

  static String _avatar(Object? v) =>
      v is String && v.length <= maxListLength ? v : '';

  static final _control = RegExp(r'[\x00-\x1f\x7f]');
}
