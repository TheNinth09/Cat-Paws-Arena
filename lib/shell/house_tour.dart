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

const houseRoomThresholds = [0, 300, 800, 1500];

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
    threshold: 300,
    cats: [
      HouseCat(
        id: 'hall-nori',
        name: 'Nori',
        room: 1,
        level: 4,
        trophies: 325,
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
        trophies: 350,
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
        trophies: 375,
        fur: 1,
        eyes: 2,
        ears: 0,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'Kitchen',
    threshold: 800,
    cats: [
      HouseCat(
        id: 'kitchen-marmalade',
        name: 'Marmalade',
        room: 2,
        level: 7,
        trophies: 825,
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
        trophies: 850,
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
        trophies: 875,
        fur: 0,
        eyes: 2,
        ears: 1,
        pattern: 1,
      ),
    ],
  ),
  HouseRoom(
    name: 'Bedroom',
    threshold: 1500,
    cats: [
      HouseCat(
        id: 'bedroom-shadow',
        name: 'Shadow',
        room: 3,
        level: 10,
        trophies: 1525,
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
        trophies: 1550,
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
        trophies: 1575,
        fur: 2,
        eyes: 1,
        ears: 0,
        pattern: 1,
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
