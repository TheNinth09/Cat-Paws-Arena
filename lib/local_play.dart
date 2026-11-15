import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'profile.dart';
import 'ui_widgets.dart';

/// Offline helpers shared by the Team and Events screens. Everything here is
/// a local simulation persisted through [Player.prefs]; nothing contacts a
/// server.

/// Polished locked-state card shown while a trophy gate is not reached yet.
Widget unlockGateCard({
  required String title,
  required String art,
  required int needed,
  required int current,
  required String reward,
}) {
  final progress = (current / needed).clamp(0.0, 1.0);
  return panel(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sprite(art, size: 76),
        const SizedBox(height: 8),
        label(title, size: 24, color: ink),
        const SizedBox(height: 6),
        Text(
          'Se deblochează la $needed trofee',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 14,
            color: gold,
            backgroundColor: const Color(0xff6c4244),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$current / $needed trofee',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.lock_open, size: 18, color: Color(0xffcb8b28)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Deblochează: $reward',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Câștigă trofee luptând în arenă pentru a debloca această zonă.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Team chat (local simulation)
// ---------------------------------------------------------------------------

class ChatMessage {
  const ChatMessage(this.who, this.text, {this.mine = false});
  final String who;
  final String text;
  final bool mine;

  Map<String, dynamic> toJson() => {'who': who, 'text': text, 'mine': mine};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    json['who'] as String? ?? '',
    json['text'] as String? ?? '',
    mine: json['mine'] == true,
  );
}

const chatHistoryLimit = 100;

List<ChatMessage> readChat(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) return <ChatMessage>[];
  try {
    return [
      for (final item in jsonDecode(raw) as List)
        ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  } catch (_) {
    return <ChatMessage>[];
  }
}

Future<void> writeChat(
  SharedPreferences prefs,
  String key,
  List<ChatMessage> messages,
) async {
  final recent = messages.length > chatHistoryLimit
      ? messages.sublist(messages.length - chatHistoryLimit)
      : messages;
  await prefs.setString(
    key,
    jsonEncode([for (final message in recent) message.toJson()]),
  );
}

const cannedChatReplies = [
  'Hai să jucăm după școală!',
  'Am văzut noul tău accessory, arată grozav!',
  'Ultimul meci a fost strâns, dar l-am câștigat!',
  'Trimite-mi un trade când ești liber!',
  'Echipa noastră e cea mai bună, aveți încredere!',
  'Hai la arenă diseară?',
  'M-ai făcut să râd toată ziua.',
  'Vom câștiga weekendul ăsta, simt!',
];

// ---------------------------------------------------------------------------
// Local team
// ---------------------------------------------------------------------------

/// Names used for simulated teammates, bots and weekend rivals.
const teamBotNames = [
  'Mochi',
  'Luna',
  'Pixel',
  'Nori',
  'Biscuit',
  'Kiko',
  'Taro',
  'Zoe',
];

/// Simulated teams a player can "join" locally. They are pure client-side
/// decoration; no roster is ever sent anywhere.
const joinableTeamSeeds = [
  ('Paws United', ['Mochi', 'Luna', 'Kiko']),
  ('Claw Crew', ['Pixel', 'Nori', 'Biscuit']),
  ('Midnight Meow', ['Taro', 'Zoe', 'Mochi']),
];

/// Picks [count] distinct simulated names, optionally with a fixed [seed] so
/// results are reproducible.
List<String> pickSimulatedNames(int count, [int? seed]) {
  final random = seed == null ? Random() : Random(seed);
  final names = List<String>.of(teamBotNames)..shuffle(random);
  return names.take(count < 0 ? 0 : count).toList();
}

class LocalTeam {
  LocalTeam({required this.name, required this.members});
  final String name;
  final List<String> members;

  Map<String, dynamic> toJson() => {'name': name, 'members': members};

  factory LocalTeam.fromJson(Map<String, dynamic> json) => LocalTeam(
    name: json['name'] as String? ?? '',
    members: [
      for (final member in (json['members'] as List? ?? const []))
        member as String,
    ],
  );
}

LocalTeam? readLocalTeam(SharedPreferences prefs) {
  final raw = prefs.getString('local_team');
  if (raw == null) return null;
  try {
    final team = LocalTeam.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    return team.name.isEmpty ? null : team;
  } catch (_) {
    return null;
  }
}

Future<void> writeLocalTeam(SharedPreferences prefs, LocalTeam? team) async {
  if (team == null) {
    await prefs.remove('local_team');
  } else {
    await prefs.setString('local_team', jsonEncode(team.toJson()));
  }
}

/// Builds a throwaway [Player] used only to render a simulated teammate's
/// avatar. It is never saved and shares no state with the real profile.
Player simulatedCat(SharedPreferences prefs, String name, int variant) {
  const cats = ['Tzuki', 'Bubble', 'Custom'];
  return Player(prefs)
    ..name = name
    ..cat = cats[variant % cats.length]
    ..fur = variant % 4
    ..eyes = variant % 3
    ..ears = variant % 2
    ..pattern = variant % 2
    ..accessory = accessories[variant % accessories.length]
    ..power = variant % powers.length
    ..photo = null;
}

// ---------------------------------------------------------------------------
// Private tournaments (local simulation)
// ---------------------------------------------------------------------------

class LocalTournament {
  LocalTournament({
    required this.name,
    required this.mode,
    required this.maxPlayers,
    required this.code,
    required this.owner,
    required this.players,
    this.status = 0,
    this.created = '',
  });

  final String name;
  final int mode;
  final int maxPlayers;
  String owner;
  final String code;
  final List<String> players;
  int status;
  final String created;

  bool has(String playerName) => players.contains(playerName);
  bool get full => players.length >= maxPlayers;
  int get freeSlots => maxPlayers - players.length;

  Map<String, dynamic> toJson() => {
    'name': name,
    'mode': mode,
    'maxPlayers': maxPlayers,
    'code': code,
    'owner': owner,
    'players': players,
    'status': status,
    'created': created,
  };

  factory LocalTournament.fromJson(Map<String, dynamic> json) {
    var mode = json['mode'] is int ? json['mode'] as int : 0;
    if (mode < 0 || mode >= modeNames.length) mode = 0;
    return LocalTournament(
      name: json['name'] as String? ?? 'Turneu',
      mode: mode,
      maxPlayers: json['maxPlayers'] == 8 ? 8 : 4,
      code: json['code'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      players: [
        for (final player in (json['players'] as List? ?? const []))
          player as String,
      ],
      status: json['status'] == 1 ? 1 : 0,
      created: json['created'] as String? ?? '',
    );
  }
}

List<LocalTournament> readTournaments(SharedPreferences prefs) {
  final raw = prefs.getString('local_tournaments');
  if (raw == null) return <LocalTournament>[];
  try {
    return [
      for (final item in jsonDecode(raw) as List)
        LocalTournament.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  } catch (_) {
    return <LocalTournament>[];
  }
}

Future<void> writeTournaments(
  SharedPreferences prefs,
  List<LocalTournament> tournaments,
) async {
  await prefs.setString(
    'local_tournaments',
    jsonEncode([for (final tournament in tournaments) tournament.toJson()]),
  );
}

/// Generates a shareable-looking 6 character code that does not collide with
/// [existing] codes. It only has meaning on this device.
String newTournamentCode(Iterable<String> existing) {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final random = Random();
  final taken = existing.toSet();
  while (true) {
    final code = List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    if (!taken.contains(code)) return code;
  }
}

typedef BracketMatch = ({String first, String second, String winner});

/// Builds a deterministic simulated bracket. Entrants are shuffled with a
/// seed derived from the tournament code and each match winner is picked
/// with a seeded [Random], so the same tournament always renders the same
/// bracket. Empty slots are shown as placeholders.
List<List<BracketMatch>> tournamentBracket(LocalTournament tournament) {
  final size = tournament.maxPlayers >= 8 ? 8 : 4;
  var entrants = tournament.players.take(size).toList();
  while (entrants.length < size) {
    entrants.add('—');
  }
  entrants.shuffle(Random('${tournament.code}:$size'.hashCode));
  final rounds = <List<BracketMatch>>[];
  var seed = tournament.code.hashCode;
  while (entrants.length > 1) {
    final matches = <BracketMatch>[];
    final winners = <String>[];
    for (var i = 0; i < entrants.length; i += 2) {
      final first = entrants[i];
      final second = entrants[i + 1];
      final winner = Random('$seed:$i'.hashCode).nextBool() ? first : second;
      matches.add((first: first, second: second, winner: winner));
      winners.add(winner);
    }
    rounds.add(matches);
    entrants = winners;
    seed += 31;
  }
  return rounds;
}

// ---------------------------------------------------------------------------
// Global weekend challenge (local simulation)
// ---------------------------------------------------------------------------

const weekendRivals = [
  ('Mochi', 15230),
  ('Luna', 14110),
  ('Pixel', 12880),
  ('Nori', 11750),
  ('Biscuit', 10420),
  ('Kiko', 9680),
  ('Taro', 8450),
  ('Zoe', 7320),
];

bool weekendJoined(SharedPreferences prefs) =>
    prefs.getBool('global_weekend_joined') ?? false;

Future<void> setWeekendJoined(SharedPreferences prefs, bool joined) async {
  await prefs.setBool('global_weekend_joined', joined);
}

/// Simulated standings for the weekend challenge. When [joined] is true the
/// local player is inserted with a score derived from their trophies.
List<({String name, int score, bool you})> weekendStandings(
  Player player,
  bool joined,
) {
  final entries = <({String name, int score, bool you})>[
    for (final rival in weekendRivals)
      (name: rival.$1, score: rival.$2, you: false),
    if (joined)
      (name: player.name, score: 9000 + player.trophies * 2, you: true),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return entries;
}
