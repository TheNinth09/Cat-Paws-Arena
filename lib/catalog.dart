const accessories = [
  'acc_pirate_bandana',
  'acc_witch_hat',
  'acc_pink_bow',
  'acc_ninja_headband',
  'acc_glasses',
  'acc_bowtie',
  'acc_flower',
  'acc_collar',
  'acc_bib',
  'acc_nightcap',
  'acc_jester',
  'acc_scarf',
  'acc_sunhat',
  'acc_royal_cape',
  'acc_beret',
  'acc_medal',
  'acc_halo_crown',
  'acc_gold_crown',
  'acc_supreme_crown',
];
const accessoryNames = [
  'Bandană Pirat',
  'Pălărie Vrăjitoare',
  'Fundiță Roz',
  'Bentiță Ninja',
  'Ochelari Rotunzi',
  'Papion Roșu',
  'Floare la Ureche',
  'Zgardă cu Clopoțel',
  'Baveta Bucătarului',
  'Bonetă de Noapte',
  'Pălărie de Bufon',
  'Fular de Iarnă',
  'Pălărie de Soare',
  'Mantia Regală',
  'Beretă de Artist',
  'Medalie de Campion',
  'Coroniță de Lumină',
  'Coroana de Aur',
  'Coroana Supremă',
];

/// Accessories the shop sells for paw coins. Road-reward accessories are
/// earned on the trophy road instead, so they stay out of the shop grid.
const shopAccessories = [
  'acc_pirate_bandana',
  'acc_witch_hat',
  'acc_pink_bow',
  'acc_ninja_headband',
  'acc_glasses',
  'acc_bowtie',
  'acc_flower',
];

/// Trophy-road room thresholds — 15 rooms from the Living (0) to the
/// Golden Palace (90000), crowned by the Supreme Crown at 100000.
const roadRoomThresholds = [
  0,
  500,
  1500,
  5000,
  10000,
  15000,
  20000,
  25000,
  30000,
  40000,
  50000,
  60000,
  70000,
  80000,
  90000,
  100000,
];

/// Room names indexed like [roadRoomThresholds]; the last entry is the
/// supreme crown milestone rather than a room.
const roadRoomNamesRo = [
  'Living',
  'Holul Principal',
  'Bucătăria',
  'Dormitorul',
  'Camera de Joacă',
  'Biblioteca Pisicilor',
  'Grădina de Iarnă',
  'Terasa Însorită',
  'Salonul Regal',
  'Atelierul de Arte',
  'Podul Cozy',
  'Sala Trofeelor',
  'Observatorul Stelelor',
  'Sanctuarul Pisicilor',
  'Palatul de Aur',
  'Coroana Supremă',
];

/// Accessory granted when each room threshold is reached (never on the
/// intermediate stops — those only pay paw coins and a few emotes).
const roadGear = {
  500: 'acc_collar',
  1500: 'acc_bib',
  5000: 'acc_nightcap',
  10000: 'acc_jester',
  15000: 'acc_glasses',
  20000: 'acc_scarf',
  25000: 'acc_sunhat',
  30000: 'acc_royal_cape',
  40000: 'acc_beret',
  50000: 'acc_pirate_bandana',
  60000: 'acc_medal',
  70000: 'acc_witch_hat',
  80000: 'acc_halo_crown',
  90000: 'acc_gold_crown',
  100000: 'acc_supreme_crown',
};

/// Trophy threshold that unlocks [item] on the road, or null when the
/// accessory is shop-only.
int? roadGearThresholdOf(String item) {
  for (final e in roadGear.entries) {
    if (e.value == item) return e.key;
  }
  return null;
}
const powers = ['vfx_zoomies', 'vfx_shadow_pounce', 'vfx_laser_chase'];
const powerNames = ['The Midnight Zoomies', 'Shadow Pounce', 'Laser Chase'];

/// `assets/images/` button icons and board VFX sprites per power.
const powerIcons = [
  'power_zoomies',
  'power_shadow_pounce',
  'power_laser_chase',
];
const powerEffects = [
  'effect_zoomies',
  'effect_shadow_pounce',
  'effect_laser_chase',
];
const modeNames = ['1v1 Arena', 'Speed Rush', 'Survival', 'High-Stakes Ranked'];
const modeThresholds = [0, 1000, 2000, 3000];

/// Trophy gates for the bottom-nav tabs: ECHIPĂ unlocks at 500 trophies,
/// EVENIMENTE at 1000. Below the gate the tab shows a lock badge and the
/// page explains the requirement instead of its content.
const teamUnlockTrophies = 500;
const eventsUnlockTrophies = 1000;
const coinBundles = [
  ('500', '8.99', ''),
  ('1,500', '22.99', ''),
  ('3,250', '44.99', 'CEL MAI POPULAR'),
  ('7,000', '89.99', ''),
  ('12,750', '134.99', ''),
  ('25,000', '224.99', 'BEST VALUE'),
];
String itemName(String item) {
  final accessory = accessories.indexOf(item);
  if (accessory >= 0) return accessoryNames[accessory];
  final power = powers.indexOf(item);
  return power >= 0 ? powerNames[power] : item;
}
