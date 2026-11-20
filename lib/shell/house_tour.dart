import 'package:shared_preferences/shared_preferences.dart';

import '../profile.dart';

class HouseCat {
  const HouseCat({
    required this.id,
    required this.name,
    required this.room,
    required this.level,
    required this.trophies,
    required this.fur,
    required this.eyes,
    required this.ears,
    required this.pattern,
  });

  final String id, name;
  final int room, level, trophies, fur, eyes, ears, pattern;
}

class HouseRoom {
  const HouseRoom({
    required this.name,
    required this.threshold,
    required this.cats,
  });

  final String name;
  final int threshold;
  final List<HouseCat> cats;
}

const houseRoomThresholds = [0, 1000, 2000, 3000, 4000];

/// Player-facing room names for the house-tour map, indexed like
/// [houseRooms]. Romanian is the default; English variants sit alongside.
const houseRoomDisplayNames = [
  'LIVING',
  'HOLUL PRINCIPAL',
  'BUCĂTARIA',
  'DORMITORUL',
  'CULOARUL DE SUS',
];
const houseRoomDisplayNamesEn = [
  'LIVING ROOM',
  'MAIN HALL',
  'KITCHEN',
  'BEDROOM',
  'UPPER HALLWAY',
];

/// Medallion room art per room (`assets/images/`).
const houseRoomArt = [
  'bg_living_room',
  'bg_main_hall',
  'bg_kitchen',
  'bg_bedroom',
  'bg_hallway',
];

/// One claimable node on the trophy road: a small paw-coin gift, an
/// emote unlock or — only at each room's threshold — an accessory plus
/// coins. Claimed via [Player.claimRoad], persisted in `roadClaims`.
class RoadMilestone {
  const RoadMilestone({
    required this.trophies,
    this.coins = 0,
    this.emote,
    this.gear,
    this.room = false,
  });

  final int trophies, coins;
  final String? emote, gear;
  final bool room;
}

/// The road between two rooms carries three milestones (+250/+500/+750
/// trophies); finishing a room grants its accessory + 150 paws.
const _roadEmotes = {500: 'wow', 1500: 'good_game', 2500: 'purr'};
const _roomGear = {
  1000: 'acc_pink_bow',
  2000: 'acc_witch_hat',
  3000: 'acc_pirate_bandana',
  4000: 'acc_ninja_headband',
};

List<RoadMilestone> get roadMilestones {
  final list = <RoadMilestone>[];
  for (var i = 1; i < houseRoomThresholds.length; i++) {
    final t = houseRoomThresholds[i];
    list
      ..add(RoadMilestone(trophies: t - 750, coins: 50))
      ..add(RoadMilestone(trophies: t - 500, emote: _roadEmotes[t - 500]))
      ..add(RoadMilestone(trophies: t - 250, coins: 75))
      ..add(
        RoadMilestone(
          trophies: t,
          coins: 150,
          gear: _roomGear[t],
          room: true,
        ),
      );
  }
  return list;
}

const houseRooms = [
  HouseRoom(
    name: 'Living',
    threshold: 0,
    cats: [
      HouseCat(
        id: 'living-puf',
        name: 'Puf',
        room: 0,
        level: 1,
        trophies: 20,
        fur: 0,
        eyes: 0,
        ears: 1,
        pattern: 0,
      ),
      HouseCat(
        id: 'living-misu',
        name: 'Misu',
        room: 0,
        level: 2,
        trophies: 45,
        fur: 1,
        eyes: 1,
        ears: 0,
        pattern: 1,
      ),
      HouseCat(
        id: 'living-toto',
        name: 'Toto',
        room: 0,
        level: 3,
        trophies: 70,
        fur: 2,
        eyes: 2,
        ears: 1,
        pattern: 0,
      ),
    ],
  ),
  HouseRoom(
    name: 'Hall',
    threshold: 1000,
    cats: [
      HouseCat(
        id: 'hall-nori',
        name: 'Nori',
        room: 1,
        level: 4,
        trophies: 1020,
        fur: 3,
        eyes: 0,
        ears: 0,
        pattern: 1,
      ),
      HouseCat(
        id: 'hall-kiko',
        name: 'Kiko',
        room: 1,
        level: 5,
        trophies: 1050,
        fur: 0,
        eyes: 1,
        ears: 1,
        pattern: 0,
      ),
      HouseCat(
        id: 'hall-biscuit',
        name: 'Biscuit',
        room: 1,
        level: 6,
        trophies: 1080,
        fur: 1,
        eyes: 2,
        ears: 0,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'Kitchen',
    threshold: 2000,
    cats: [
      HouseCat(
        id: 'kitchen-marmalade',
        name: 'Marmalade',
        room: 2,
        level: 7,
        trophies: 2020,
        fur: 2,
        eyes: 0,
        ears: 1,
        pattern: 1,
      ),
      HouseCat(
        id: 'kitchen-tofu',
        name: 'Tofu',
        room: 2,
        level: 8,
        trophies: 2050,
        fur: 3,
        eyes: 1,
        ears: 0,
        pattern: 0,
      ),
      HouseCat(
        id: 'kitchen-crouton',
        name: 'Crouton',
        room: 2,
        level: 9,
        trophies: 2080,
        fur: 0,
        eyes: 2,
        ears: 1,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'Bedroom',
    threshold: 3000,
    cats: [
      HouseCat(
        id: 'bedroom-shadow',
        name: 'Shadow',
        room: 3,
        level: 10,
        trophies: 3020,
        fur: 3,
        eyes: 2,
        ears: 0,
        pattern: 1,
      ),
      HouseCat(
        id: 'bedroom-nimbus',
        name: 'Nimbus',
        room: 3,
        level: 11,
        trophies: 3050,
        fur: 1,
        eyes: 0,
        ears: 1,
        pattern: 0,
      ),
      HouseCat(
        id: 'bedroom-aurora',
        name: 'Aurora',
        room: 3,
        level: 12,
        trophies: 3080,
        fur: 2,
        eyes: 1,
        ears: 0,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'Hallway',
    threshold: 4000,
    cats: [
      HouseCat(
        id: 'hallway-fig',
        name: 'Fig',
        room: 4,
        level: 13,
        trophies: 4020,
        fur: 0,
        eyes: 2,
        ears: 1,
        pattern: 0,
      ),
      HouseCat(
        id: 'hallway-sage',
        name: 'Sage',
        room: 4,
        level: 14,
        trophies: 4050,
        fur: 2,
        eyes: 1,
        ears: 0,
        pattern: 1,
      ),
      HouseCat(
        id: 'hallway-pretzel',
        name: 'Pretzel',
        room: 4,
        level: 15,
        trophies: 4080,
        fur: 1,
        eyes: 0,
        ears: 1,
        pattern: 0,
      ),
    ],
  ),
];

HouseRoom houseRoomForTrophies(int trophies) {
  var room = houseRooms.first;
  for (final candidate in houseRooms) {
    if (trophies >= candidate.threshold) room = candidate;
  }
  return room;
}

Player houseCatPlayer(SharedPreferences prefs, HouseCat cat) => Player(prefs)
  ..name = cat.name
  ..cat = 'Custom'
  ..trophies = cat.trophies
  ..coins = 0
  ..fur = cat.fur
  ..eyes = cat.eyes
  ..ears = cat.ears
  ..pattern = cat.pattern
  ..accessory = ''
  ..power = 0
  ..photo = null;
