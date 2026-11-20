import 'package:shared_preferences/shared_preferences.dart';

import '../catalog.dart';
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

const houseRoomThresholds = roadRoomThresholds;

/// The supreme crown milestone at the very top of the road.
const roadFinalThreshold = 100000;

/// Player-facing room names for the house-tour map, indexed like
/// [houseRooms]. Romanian is the default; English variants sit alongside.
const houseRoomDisplayNames = [
  'LIVING',
  'HOLUL PRINCIPAL',
  'BUCĂTARIA',
  'DORMITORUL',
  'CAMERA DE JOACĂ',
  'BIBLIOTECA PISICILOR',
  'GRĂDINA DE IARNĂ',
  'TERASA ÎNSORITĂ',
  'SALONUL REGAL',
  'ATELIERUL DE ARTE',
  'PODUL COZY',
  'SALA TROFEELOR',
  'OBSERVATORUL STELELOR',
  'SANCTUARUL PISICILOR',
  'PALATUL DE AUR',
  'COROANA SUPREMĂ',
];
const houseRoomDisplayNamesEn = [
  'LIVING ROOM',
  'MAIN HALL',
  'KITCHEN',
  'BEDROOM',
  'PLAYROOM',
  'CAT LIBRARY',
  'WINTER GARDEN',
  'SUNNY TERRACE',
  'ROYAL SALON',
  'ART STUDIO',
  'COZY ATTIC',
  'TROPHY HALL',
  'STAR OBSERVATORY',
  'CAT SANCTUARY',
  'GOLDEN PALACE',
  'SUPREME CROWN',
];

/// Medallion room art per room (`assets/images/`). Later rooms reuse the
/// closest matching background until bespoke art is drawn.
const houseRoomArt = [
  'bg_living_room',
  'bg_main_hall',
  'bg_kitchen',
  'bg_bedroom',
  'bg_team',
  'bg_cats',
  'bg_events',
  'bg_battle_lobby',
  'bg_main_hall',
  'bg_hallway',
  'bg_bedroom',
  'bg_main_hall',
  'bg_arena_battle',
  'bg_living_room',
  'bg_main_hall',
  'bg_main_hall',
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

/// Intermediate stops per room gap — exactly 50 evenly-spaced claimable
/// milestones between every pair of consecutive room thresholds.
const stopsPerGap = 50;

/// Road-exclusive emotes unlock at predefined stops along the gaps:
/// `gap index → (stop index within the gap, emote wire value)`. `love`
/// waits inside the Bedroom→Playroom gap (~7450 trophies) and `angry`
/// inside the Royal Salon→Art Studio gap (~34900 trophies).
const _roadEmoteStops = {
  3: (24, 'love'),
  8: (24, 'angry'),
};

List<RoadMilestone> get roadMilestones {
  final list = <RoadMilestone>[];
  for (var gap = 0; gap < houseRoomThresholds.length - 1; gap++) {
    final a = houseRoomThresholds[gap];
    final b = houseRoomThresholds[gap + 1];
    final emoteStop = _roadEmoteStops[gap];
    var seen = 0;
    for (var j = 0; j < stopsPerGap; j++) {
      final trophies = a + ((b - a) * (j + 1) / (stopsPerGap + 1)).round();
      // Emote stops also pay a small paw gift; the rest are coins only.
      final emote = emoteStop != null && emoteStop.$1 == j
          ? emoteStop.$2
          : null;
      list.add(
        RoadMilestone(
          trophies: trophies,
          coins: emote != null ? 40 : 10 + (j % 10) * 4,
          emote: emote,
        ),
      );
      seen++;
    }
    assert(seen == stopsPerGap);
    // The room threshold itself carries the room reward: accessory +
    // coins, claimed from the room sheet. The crown pays the most.
    list.add(
      RoadMilestone(
        trophies: b,
        coins: b == roadFinalThreshold ? 5000 : 150 + gap * 100,
        gear: roadGear[b],
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
    threshold: 500,
    cats: [
      HouseCat(
        id: 'hall-nori',
        name: 'Nori',
        room: 1,
        level: 4,
        trophies: 520,
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
        trophies: 550,
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
        trophies: 580,
        fur: 1,
        eyes: 2,
        ears: 0,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'Kitchen',
    threshold: 1500,
    cats: [
      HouseCat(
        id: 'kitchen-marmalade',
        name: 'Marmalade',
        room: 2,
        level: 7,
        trophies: 1520,
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
        trophies: 1550,
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
        trophies: 1580,
        fur: 0,
        eyes: 2,
        ears: 1,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'Bedroom',
    threshold: 5000,
    cats: [
      HouseCat(
        id: 'bedroom-shadow',
        name: 'Shadow',
        room: 3,
        level: 10,
        trophies: 5020,
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
        trophies: 5050,
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
        trophies: 5080,
        fur: 2,
        eyes: 1,
        ears: 0,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'Playroom',
    threshold: 10000,
    cats: [
      HouseCat(
        id: 'playroom-fig',
        name: 'Fig',
        room: 4,
        level: 13,
        trophies: 10020,
        fur: 0,
        eyes: 2,
        ears: 1,
        pattern: 0,
      ),
      HouseCat(
        id: 'playroom-sage',
        name: 'Sage',
        room: 4,
        level: 14,
        trophies: 10050,
        fur: 2,
        eyes: 1,
        ears: 0,
        pattern: 1,
      ),
      HouseCat(
        id: 'playroom-pretzel',
        name: 'Pretzel',
        room: 4,
        level: 15,
        trophies: 10080,
        fur: 1,
        eyes: 0,
        ears: 1,
        pattern: 0,
      ),
    ],
  ),
  // One guardian cat per deeper room keeps the bot roster varied on the
  // way to the crown; rooms stay focused on their road reward.
  HouseRoom(
    name: 'Library',
    threshold: 15000,
    cats: [
      HouseCat(
        id: 'library-scroll',
        name: 'Scroll',
        room: 5,
        level: 16,
        trophies: 15050,
        fur: 3,
        eyes: 1,
        ears: 0,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'WinterGarden',
    threshold: 20000,
    cats: [
      HouseCat(
        id: 'garden-frost',
        name: 'Frost',
        room: 6,
        level: 17,
        trophies: 20050,
        fur: 5,
        eyes: 1,
        ears: 1,
        pattern: 4,
      ),
    ],
  ),
  HouseRoom(
    name: 'Terrace',
    threshold: 25000,
    cats: [
      HouseCat(
        id: 'terrace-sol',
        name: 'Sol',
        room: 7,
        level: 18,
        trophies: 25050,
        fur: 1,
        eyes: 2,
        ears: 0,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'RoyalSalon',
    threshold: 30000,
    cats: [
      HouseCat(
        id: 'salon-duchess',
        name: 'Duchess',
        room: 8,
        level: 19,
        trophies: 30050,
        fur: 5,
        eyes: 0,
        ears: 1,
        pattern: 2,
      ),
    ],
  ),
  HouseRoom(
    name: 'Atelier',
    threshold: 40000,
    cats: [
      HouseCat(
        id: 'atelier-picasso',
        name: 'Picasso',
        room: 9,
        level: 20,
        trophies: 40050,
        fur: 2,
        eyes: 3,
        ears: 0,
        pattern: 3,
      ),
    ],
  ),
  HouseRoom(
    name: 'Attic',
    threshold: 50000,
    cats: [
      HouseCat(
        id: 'attic-dusty',
        name: 'Dusty',
        room: 10,
        level: 21,
        trophies: 50050,
        fur: 4,
        eyes: 2,
        ears: 1,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'TrophyHall',
    threshold: 60000,
    cats: [
      HouseCat(
        id: 'trophy-champ',
        name: 'Champ',
        room: 11,
        level: 22,
        trophies: 60050,
        fur: 1,
        eyes: 3,
        ears: 1,
        pattern: 0,
      ),
    ],
  ),
  HouseRoom(
    name: 'Observatory',
    threshold: 70000,
    cats: [
      HouseCat(
        id: 'observatory-nova',
        name: 'Nova',
        room: 12,
        level: 23,
        trophies: 70050,
        fur: 4,
        eyes: 0,
        ears: 0,
        pattern: 4,
      ),
    ],
  ),
  HouseRoom(
    name: 'Sanctuary',
    threshold: 80000,
    cats: [
      HouseCat(
        id: 'sanctuary-zen',
        name: 'Zen',
        room: 13,
        level: 24,
        trophies: 80050,
        fur: 2,
        eyes: 1,
        ears: 1,
        pattern: 2,
      ),
    ],
  ),
  HouseRoom(
    name: 'GoldenPalace',
    threshold: 90000,
    cats: [
      HouseCat(
        id: 'palace-midas',
        name: 'Midas',
        room: 14,
        level: 25,
        trophies: 90050,
        fur: 1,
        eyes: 2,
        ears: 0,
        pattern: 3,
      ),
    ],
  ),
  // The Supreme Crown crowns the road at 100000 trophies — no cats here,
  // just the final room reward.
  HouseRoom(name: 'Crown', threshold: 100000, cats: []),
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
