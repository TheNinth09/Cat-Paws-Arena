const accessories = [
  'acc_pirate_bandana',
  'acc_witch_hat',
  'acc_pink_bow',
  'acc_ninja_headband',
  'acc_glasses',
  'acc_bowtie',
  'acc_flower',
];
const accessoryNames = [
  'Bandană Pirat',
  'Pălărie Vrăjitoare',
  'Fundiță Roz',
  'Bentiță Ninja',
  'Ochelari Rotunzi',
  'Papion Roșu',
  'Floare la Ureche',
];
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
