import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cat_avatar.dart';
import 'catalog.dart';
import 'profile.dart';
import 'ui_widgets.dart';

const _cardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xffffe0a0), Color(0xffffedbb), Color(0xffe9ab60)],
);
const _selectedGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xfffff3c4), Color(0xffffe0a0), Color(0xfff0b45e)],
);
const _goldGradient = LinearGradient(
  colors: [Color(0xfffff3c4), gold, Color(0xffe8a92e)],
);
const _stageGradient = RadialGradient(
  center: Alignment(0, -0.55),
  radius: 1.05,
  colors: [Color(0xfffff6d8), Color(0xfff4d9a0), Color(0xffe2a866)],
);

/// Preset names a custom cat can take. Names shown to other players must
/// come from this list — typed text is never a peer-visible identity.
const catPresetNames = <String>[
  'Luna',
  'Milo',
  'Oliver',
  'Bella',
  'Lucy',
  'Leo',
  'Loki',
  'Nala',
  'Simba',
  'Oscar',
  'Mochi',
  'Willow',
  'Jasper',
  'Lily',
  'Felix',
  'Ginger',
  'Shadow',
  'Boots',
  'Whiskers',
  'Mittens',
  'Smokey',
  'Oreo',
  'Pepper',
  'Cinnamon',
  'Pumpkin',
  'Peanut',
  'Bandit',
  'Scout',
  'Olive',
  'Poppy',
  'Daisy',
  'Rosie',
  'Lulu',
  'Mia',
  'Zoe',
  'Ivy',
  'Jade',
  'Cleo',
  'Max',
  'Charlie',
  'Toby',
  'Bruno',
  'Rocky',
  'Duke',
  'Zeus',
  'Apollo',
  'Atlas',
  'Thor',
  'Nemo',
  'Marlin',
  'Crush',
  'Squirt',
  'Pearl',
  'Marina',
  'Coral',
  'Bubbles',
  'Dory',
  'Finn',
  'Jake',
  'Riley',
  'Bailey',
  'Molly',
  'Sophie',
  'Emma',
  'Chloe',
  'Ruby',
  'Hazel',
  'Violet',
  'Iris',
  'Aurora',
  'Stella',
  'Nova',
  'Comet',
  'Cosmo',
  'Astro',
  'Pixel',
  'Byte',
  'Echo',
  'Miso',
  'Tofu',
  'Sushi',
  'Boba',
  'Matcha',
  'Latte',
  'Mocha',
  'Espresso',
  'Cocoa',
  'Chai',
  'Maple',
  'Honey',
  'Biscuit',
  'Cupcake',
  'Muffin',
  'Cookie',
  'Brownie',
  'Waffle',
  'Pancake',
  'Bagel',
  'Pretzel',
  'Noodle',
  'Pasta',
  'Ravioli',
  'Meatball',
  'Bacon',
  'Salami',
  'Prosciutto',
  'Boulder',
  'Pebble',
  'Stone',
  'Granite',
  'Marble',
  'Onyx',
  'Opal',
  'Topaz',
  'Amber',
  'Saffron',
  'Clover',
  'Fern',
  'Basil',
  'Thyme',
  'Rosemary',
  'Mint',
  'Sage',
  'Rowan',
  'Skye',
  'Rain',
  'Storm',
  'Ember',
  'Ash',
  'Flint',
  'Slate',
  'Juno',
  'Vesta',
  'Minerva',
  'Diana',
  'Freya',
  'Frigg',
  'Sif',
  'Idun',
  'Hel',
  'Ra',
  'Anubis',
  'Bastet',
  'Sekhmet',
  'Horus',
  'Thoth',
  'Isis',
  'Osiris',
  'Set',
  'Hapi',
  'Miu',
  'Pisi',
  'Motan',
  'Zmeu',
  'Coco',
  'Tincuță',
  'Bobo',
  'Gică',
  'Michi',
  'Puiu',
  'Fufu',
  'Nucu',
  'Tutu',
  'Bubu',
  'Cici',
  'Didi',
  'Gigi',
  'Mimi',
  'Nini',
  'Pipi',
  'Sisi',
  'Titi',
  'Ileana',
  'Vlad',
  'Andrei',
  'Petre',
  'Ion',
  'Maria',
  'Elena',
  'Ana',
  'Ioana',
  'Matei',
  'Ștefan',
  'Radu',
  'Cristian',
  'Alexandru',
  'Gabriel',
  'David',
  'Samuel',
  'Noah',
  'Ethan',
  'Liam',
  'James',
  'Henry',
  'Jack',
  'Owen',
  'Caleb',
  'Isaac',
  'Lucas',
  'Mason',
  'Logan',
  'Eli',
  'Adam',
  'Nathan',
  'Aaron',
  'Benjamin',
  'Daniel',
  'Matthew',
  'Andrew',
  'Joshua',
  'Ryan',
  'Nathaniel',
  'Christian',
  'Jonathan',
  'Isaiah',
  'Sebastian',
  'Dominic',
  'Vincent',
  'Julian',
  'Hugo',
  'Felipe',
  'Diego',
  'Mateo',
  'Santiago',
  'Thiago',
  'Enzo',
  'Lorenzo',
  'Giovanni',
  'Marco',
  'Luca',
  'Alessandro',
  'Francesco',
  'Antonio',
  'Leonardo',
  'Riccardo',
  'Tommaso',
  'Edoardo',
  'Matteo',
  'Gabriele',
  'Federico',
  'Alessio',
  'Nicolas',
  'Antoine',
  'Léo',
  'Sacha',
  'Théo',
  'Mathis',
  'Paul',
];

/// Shared-preferences key holding the custom cat's preset name. The visual
/// spec itself lives in the regular [Player] fields (fur/pattern/eyes/
/// ears/power/accessory), which `profile.dart` already persists.
const catCustomNameKey = 'cat_custom_name_v1';

/// Loads the saved preset name for the custom cat, or null when absent or
/// not part of [catPresetNames] (typed text is never accepted as a
/// peer-visible name).
String? loadCustomCatName(SharedPreferences prefs) {
  final raw = prefs.getString(catCustomNameKey);
  return raw != null && catPresetNames.contains(raw) ? raw : null;
}

void saveCustomCatName(SharedPreferences prefs, String name) {
  if (catPresetNames.contains(name)) {
    prefs.setString(catCustomNameKey, name);
  }
}

class CatsScreen extends StatefulWidget {
  const CatsScreen({super.key, required this.player, required this.onShop});
  final Player player;
  final VoidCallback onShop;

  @override
  State<CatsScreen> createState() => _CatsScreenState();
}

class _CatsScreenState extends State<CatsScreen> {
  final _random = Random();
  String? _catName;
  late String _viewing = player.cat;

  Player get player => widget.player;

  @override
  void initState() {
    super.initState();
    _catName = loadCustomCatName(player.prefs);
    if (_catName == null) _pickRandomName();
  }

  void change(VoidCallback update) {
    setState(update);
    player.save();
  }

  void _pickRandomName() {
    _catName = catPresetNames[_random.nextInt(catPresetNames.length)];
    saveCustomCatName(player.prefs, _catName!);
  }

  void _randomise() => change(() {
    player.fur = _random.nextInt(catFurColours.length);
    player.pattern = _random.nextInt(catPatternCount);
    player.eyes = _random.nextInt(catEyeColours.length);
    player.ears = _random.nextInt(catEarCount);
    player.power = _random.nextInt(powers.length);
    _pickRandomName();
  });

  void _pickName() {
    var query = '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Numele pisicii'),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Caută nume',
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      setDialogState(() => query = value.toLowerCase()),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 2.6,
                        ),
                    itemCount: catPresetNames.length,
                    itemBuilder: (context, index) {
                      final name = catPresetNames[index];
                      if (query.isNotEmpty &&
                          !name.toLowerCase().contains(query)) {
                        return const SizedBox.shrink();
                      }
                      return _OptionChip(
                        text: name,
                        selected: name == _catName,
                        onTap: () {
                          change(() => _catName = name);
                          saveCustomCatName(player.prefs, name);
                          Navigator.pop(dialogContext);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('GATA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget nameRow() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nume',
          style: TextStyle(
            color: Color(0xff6b4a32),
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xfffff8e6), Color(0xffffedbb)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _catName == null ? const Color(0x6651312d) : ink,
                    width: _catName == null ? 1.5 : 2.2,
                  ),
                ),
                child: Text(
                  _catName ?? '—',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _IconAction(
              icon: Icons.casino,
              tooltip: 'Nume aleatoriu',
              onTap: () => change(_pickRandomName),
            ),
            const SizedBox(width: 6),
            _IconAction(
              icon: Icons.grid_view,
              tooltip: 'Alege numele',
              onTap: _pickName,
            ),
          ],
        ),
      ],
    ),
  );

  /// Three cat chips above the stage — the two defaults plus the
  /// custom creation. The gold ring marks the one being previewed and a
  /// green check marks the one equipped in duels.
  Widget _catChips() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final cat in ['Tzuki', 'Bubble', 'Custom'])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureDetector(
            onTap: () => setState(() => _viewing = cat),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xfffff3d9),
                        border: Border.all(
                          color: _viewing == cat ? gold : ink,
                          width: _viewing == cat ? 3 : 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x5551312d),
                            offset: Offset(0, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: cat == 'Custom'
                          ? CatSpecAvatar(catSpecForPlayer(player), size: 52)
                          : arenaImage(
                              'cat_${cat.toLowerCase()}',
                              fit: BoxFit.cover,
                              fallback: CatAvatar(player, size: 52),
                            ),
                    ),
                    if (player.cat == cat)
                      const Positioned(
                        right: -3,
                        bottom: -3,
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xff3f6d22),
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 64,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      cat == 'Custom' ? 'CUSTOM' : cat.toUpperCase(),
                      style: TextStyle(
                        color: _viewing == cat ? ink : const Color(0xff8a6242),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Cozy library backdrop lives on HomeScreen's crossfading page
      // background (`bg_cats`); a soft scrim keeps the UI legible.
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x3320130e), Color(0x0020130e), Color(0x4520130e)],
            stops: [0, 0.4, 1],
          ),
        ),
      ),
      ListView(
        key: const PageStorageKey('cats-scroll'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          const _CreatorTitle(),
          const SizedBox(height: 4),
          _catChips(),
          const SizedBox(height: 8),
          _CatStage(player: player, cat: _viewing, catName: _catName),
          if (_viewing == 'Custom') ...[
            nameRow(),
            _swatchesRow(
              'BLANĂ',
              catFurColours,
              const ['Gri', 'Portocaliu', 'Crem', 'Mov', 'Negru', 'Alb'],
              player.fur,
              (i) => change(() => player.fur = i),
            ),
            _choicesRow(
              'MODEL',
              const ['Uniform', 'Tigrat', 'Bicolor', 'Calico', 'Colorpoint'],
              player.pattern,
              (i) => change(() => player.pattern = i),
            ),
            _swatchesRow(
              'OCHI',
              catEyeColours,
              const ['Verzi', 'Albaștri', 'Aurii', 'Arămii'],
              player.eyes,
              (i) => change(() => player.eyes = i),
            ),
            _choicesRow(
              'URECHI',
              const ['Două urechi', 'Doar stânga', 'Plisate', 'Smocuri'],
              player.ears,
              (i) => change(() => player.ears = i),
            ),
            const _PanelTitle('PUTEREA AVATARULUI'),
            Row(
              children: [
                for (var i = 0; i < powers.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _AvatarPowerCard(
                        asset:
                            'assets/images/${['power_zoomies', 'power_shadow_pounce', 'power_laser_chase'][i]}.png',
                        fallback: powers[i],
                        title: powerNames[i],
                        selected: i == player.power,
                        onTap: () => change(() => player.power = i),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ArenaButton(
                    text: 'ALEATORIU',
                    onPressed: _randomise,
                    secondary: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ArenaButton(
                    text: player.cat == 'Custom'
                        ? 'SALVEAZĂ AVATAR'
                        : 'ECHIPEAZĂ ȘI SALVEAZĂ',
                    onPressed: () => change(() {
                      player.cat = 'Custom';
                      player.photo = null;
                    }),
                    green: true,
                  ),
                ),
              ],
            ),
          ] else
            panel(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xffcb8b28),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _viewing == 'Tzuki'
                        ? 'Tzuki • O singură ureche, stânga\nThe Midnight Zoomies'
                        : 'Bubble • Shadow Pounce',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          if (_viewing != 'Custom') ...[
            const SizedBox(height: 10),
            ArenaButton(
              text: _viewing == player.cat
                  ? 'ECHIPAT'
                  : 'ECHIPEAZĂ PE ${_viewing.toUpperCase()}',
              onPressed: _viewing == player.cat
                  ? null
                  : () => change(() {
                      player.cat = _viewing;
                      player.photo = null;
                    }),
              green: _viewing != player.cat,
            ),
          ],
          const SizedBox(height: 14),
          const SectionHeading('ACCESORII'),
          AdaptiveCardGrid(
            minWidth: 135,
            maxColumns: 2,
            children: [
              for (final item in accessories)
                _EquipCard(
                  art: item,
                  title: itemName(item),
                  selected: player.accessory == item,
                  buttonText: player.accessory == item
                      ? 'ECHIPAT'
                      : player.owned.contains(item)
                      ? 'ECHIPEAZĂ'
                      : shopAccessories.contains(item)
                      ? 'MAGAZIN'
                      : 'LA ${roadGearThresholdOf(item)} 🏆',
                  green:
                      player.accessory != item && player.owned.contains(item),
                  dim: !player.owned.contains(item),
                  onPressed: () => player.owned.contains(item)
                      ? change(() => player.accessory =
                          player.accessory == item ? '' : item)
                      : shopAccessories.contains(item)
                      ? widget.onShop()
                      : null,
                ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Big cartoon page title like the reference creator screen.
class _CreatorTitle extends StatelessWidget {
  const _CreatorTitle();

  @override
  Widget build(BuildContext context) => const Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'CREEAZĂ-ȚI\nPISICA',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xffff9430),
          fontSize: 30,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          height: 1.05,
          shadows: [
            Shadow(color: Color(0xff5a2f16), offset: Offset(0, 3)),
            Shadow(
              color: Color(0x665a2f16),
              offset: Offset(0, 5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CatStage extends StatelessWidget {
  const _CatStage({required this.player, required this.cat, this.catName});
  final Player player;
  final String cat;
  final String? catName;

  @override
  Widget build(BuildContext context) {
    final power = cat == 'Tzuki'
        ? 0
        : cat == 'Bubble'
        ? 1
        : player.power;
    final (tagText, tagColor) = cat == 'Tzuki'
        ? ('RARĂ', const Color(0xff8e4fc4))
        : cat == 'Bubble'
        ? ('COMUNĂ', const Color(0xff4a8a37))
        : ('UNICĂ', const Color(0xffcb8b28));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Just the cat over the room backdrop — no cushion, no panel.
        SizedBox(height: 235, child: Center(child: _catHeroArt(player, cat))),
        const SizedBox(height: 8),
        label(
          cat == 'Custom'
              ? (catName ?? 'PISI').toUpperCase()
              : cat.toUpperCase(),
          size: 24,
        ),
        const SizedBox(height: 4),
        _RarityTag(text: tagText, color: tagColor),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _LoadoutChip(
              art: [
                'power_zoomies',
                'power_shadow_pounce',
                'power_laser_chase',
              ][power.clamp(0, 2)],
              text: 'PUTERE • ${powerNames[power]}',
            ),
            _LoadoutChip(
              icon: Icons.checkroom,
              text: player.accessory.isEmpty
                  ? 'ACCESORIU • NICIUNUL'
                  : 'ACCESORIU • ${itemName(player.accessory)}',
            ),
          ],
        ),
      ],
    );
  }
}

/// Hero cat art for the stage: the real PNG sprites for the presets. The
/// created cat renders through the layer system so every editor choice —
/// fur, pattern, eyes, ears and accessory — changes the cat on screen.
Widget _catHeroArt(Player player, String cat) {
  if (cat == 'Custom') {
    return CatCharacter(player, height: 215);
  }
  return arenaImage(
    'cat_${cat.toLowerCase()}',
    height: 210,
    fallback: CatCharacter(player, height: 215),
  );
}

class _LoadoutChip extends StatelessWidget {
  const _LoadoutChip({this.icon, this.art, required this.text});
  final IconData? icon;
  final String? art;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xcc51312d),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0x88ffc63c), width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (art != null)
          arenaImage(
            art!,
            width: 18,
            height: 18,
            fallback: const Icon(Icons.bolt, size: 15, color: gold),
          )
        else
          Icon(icon, size: 15, color: gold),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: cream,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Small coloured class/rarity tag under the cat's stage name.
class _RarityTag extends StatelessWidget {
  const _RarityTag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ink, width: 1.6),
      boxShadow: const [
        BoxShadow(
          color: Color(0x5551312d),
          offset: Offset(0, 2),
          blurRadius: 3,
        ),
      ],
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        color: ink,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0xfffff3c4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ink, width: 1.8),
          ),
          child: Icon(icon, size: 20, color: ink),
        ),
      ),
    ),
  );
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? _goldGradient
              : const LinearGradient(
                  colors: [Color(0xfffff8e6), Color(0xffffedbb)],
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? ink : const Color(0x6651312d),
            width: selected ? 2.2 : 1.5,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(color: Color(0x5561312d), offset: Offset(0, 2)),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 15, color: ink),
              const SizedBox(width: 5),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                maxLines: 1,
                style: const TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SwatchChip extends StatelessWidget {
  const _SwatchChip({
    required this.colour,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final Color colour;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? _goldGradient
              : const LinearGradient(
                  colors: [Color(0xfffff8e6), Color(0xffffedbb)],
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? ink : const Color(0x6651312d),
            width: selected ? 2.4 : 1.5,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(color: Color(0x5561312d), offset: Offset(0, 2)),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colour,
                border: Border.all(color: ink, width: 1.4),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EquipCard extends StatelessWidget {
  const _EquipCard({
    required this.art,
    required this.title,
    required this.buttonText,
    required this.onPressed,
    this.selected = false,
    this.green = false,
    this.dim = false,
  });
  final String art, title, buttonText;
  final VoidCallback? onPressed;
  final bool selected, green, dim;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: selected ? _selectedGradient : _cardGradient,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: selected ? gold : ink, width: selected ? 3 : 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x6651312d),
          offset: Offset(0, 4),
          blurRadius: 5,
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dim
              ? Opacity(
                  opacity: 0.55,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: accessoryArt(art, size: 58),
                  ),
                )
              : accessoryArt(art, size: 58),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 6),
          ArenaButton(text: buttonText, onPressed: onPressed, green: green),
        ],
      ),
    ),
  );
}

/// Fixed-size card shared through the platform share sheet: the cat, its
/// preset name, its room and the game name — nothing else. It never shows
/// the player's name, photo, or any other personal data.
class CatShareCard extends StatelessWidget {
  const CatShareCard({
    super.key,
    required this.spec,
    required this.catName,
    required this.room,
    this.gameName = 'Cat Paws Arena',
    this.width = 360,
    this.height = 450,
  });

  /// Visual description of the cat to draw (see [catSpecForPlayer]).
  final CatSpec spec;

  /// Preset cat name — never typed text.
  final String catName;

  /// Room label (see [Player.room]).
  final String room;

  /// Game title shown at the bottom of the card.
  final String gameName;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Container(
      decoration: BoxDecoration(
        gradient: _stageGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6651312d),
            offset: Offset(0, 6),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            Positioned(
              top: 14,
              left: 16,
              child: Opacity(
                opacity: 0.22,
                child: sprite('tile_paw', size: 34),
              ),
            ),
            Positioned(
              bottom: 14,
              right: 16,
              child: Opacity(
                opacity: 0.22,
                child: sprite('tile_paw', size: 34),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: CatSpecAvatar(
                        spec,
                        size: 205,
                        showAccessory: false,
                      ),
                    ),
                  ),
                  Text(
                    catName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66ffffff),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ink, width: 1.4),
                    ),
                    child: Text(
                      'CAMERA • $room',
                      style: const TextStyle(
                        color: Color(0xff6b4a32),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gameName,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Label-chip row shared by the cat creator and the avatar editor.
Widget _choicesRow(
  String title,
  List<String> names,
  int selected,
  ValueChanged<int> onSelect,
) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Color(0xff6b4a32),
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < names.length; i++)
            _OptionChip(
              text: names[i],
              selected: selected == i,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    ],
  ),
);

/// Colour-swatch row shared by the cat creator and the avatar editor.
Widget _swatchesRow(
  String title,
  List<Color> colours,
  List<String> names,
  int selected,
  ValueChanged<int> onSelect,
) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Color(0xff6b4a32),
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < colours.length; i++)
            _SwatchChip(
              colour: colours[i],
              label: names[i],
              selected: selected == i,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    ],
  ),
);

Set<String>? _assetNames;

Future<Set<String>> _bundledAssets() async {
  final cached = _assetNames;
  if (cached != null) return cached;
  final names = (await AssetManifest.loadFromAssetBundle(rootBundle))
      .listAssets()
      .toSet();
  return _assetNames = names;
}

class _BundledAsset extends StatefulWidget {
  const _BundledAsset({
    required this.asset,
    required this.fallback,
    this.width,
    this.height,
  });

  final String asset;
  final Widget fallback;
  final double? width, height;

  @override
  State<_BundledAsset> createState() => _BundledAssetState();
}

class _BundledAssetState extends State<_BundledAsset> {
  bool useAsset = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final names = await _bundledAssets();
    if (mounted) setState(() => useAsset = names.contains(widget.asset));
  }

  @override
  Widget build(BuildContext context) => useAsset
      ? Image.asset(
          widget.asset,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => widget.fallback,
        )
      : widget.fallback;
}

class _AvatarPowerCard extends StatelessWidget {
  const _AvatarPowerCard({
    required this.asset,
    required this.fallback,
    required this.title,
    required this.selected,
    required this.onTap,
  });
  final String asset, fallback, title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        gradient: selected ? _selectedGradient : _cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? gold : ink,
          width: selected ? 2.6 : 1.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BundledAsset(
            asset: asset,
            width: 52,
            height: 52,
            fallback: sprite(fallback, size: 52),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (selected) ...const [
            SizedBox(height: 3),
            Icon(Icons.check_circle, color: Color(0xff3f6d22), size: 18),
          ],
        ],
      ),
    ),
  );
}
