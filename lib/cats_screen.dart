import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
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
const _bannerGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xff9a6242), Color(0xff74463a)],
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
  AvatarSpec _avatar = const AvatarSpec();

  Player get player => widget.player;

  @override
  void initState() {
    super.initState();
    _catName = loadCustomCatName(player.prefs);
    if (_catName == null) _pickRandomName();
    _avatar = avatarSpecFor(player);
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

  /// Renders [CatShareCard] offstage, captures it as a PNG and hands it to
  /// the platform share sheet. The card carries only the cat, its preset
  /// name, the room and the game name — never the player's name or photo.
  Future<void> _shareCard() async {
    final spec = catSpecForPlayer(player);
    final catName = player.cat == 'Custom'
        ? (_catName ?? 'Pisică')
        : player.cat;
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -4000,
        top: -4000,
        child: RepaintBoundary(
          key: boundaryKey,
          child: CatShareCard(spec: spec, catName: catName, room: player.room),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: const ['pisica_mea.png'],
        ),
      );
    } finally {
      entry.remove();
    }
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

  /// Profile avatar card: the user's own creature, separate from the duel
  /// cats below. Opens the avatar editor.
  Widget _avatarCard() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        gradient: _cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6651312d),
            offset: Offset(0, 3),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xfffff8e6),
                  border: Border.all(color: ink, width: 2.5),
                ),
                child: ClipOval(child: AvatarAvatar(_avatar, size: 64)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVATARUL TĂU',
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Arată ca mine • separat de pisica de duel',
                      style: TextStyle(
                        color: Color(0xff8a5a3b),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ArenaButton(
            text: 'EDITEAZĂ',
            onPressed: _editAvatar,
            green: true,
            singleLine: true,
          ),
        ],
      ),
    ),
  );

  void _editAvatar() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarEditorSheet(
        initial: _avatar,
        owned: player.owned,
        onSave: (spec) {
          setState(() => _avatar = spec);
          saveAvatarSpecFor(player, spec);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('cats-scroll'),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
    children: [
      const _CatsBanner(),
      _avatarCard(),
      _CatStage(player: player, catName: _catName),
      const SizedBox(height: 8),
      ArenaButton(
        text: 'DISTRUIE CARDUL',
        onPressed: _shareCard,
        secondary: true,
      ),
      const SectionHeading('ALEGE PISICA'),
      AdaptiveCardGrid(
        minWidth: 104,
        maxColumns: 3,
        children: [
          for (final cat in ['Tzuki', 'Bubble', 'Custom'])
            _CatPickCard(
              cat: cat,
              player: player,
              onTap: () => change(() {
                player.cat = cat;
                player.photo = null;
              }),
            ),
        ],
      ),
      if (player.cat == 'Custom') ...[
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: _PanelTitle('CREATOR')),
                  ArenaButton(
                    text: 'ALEATORIZEAZĂ',
                    onPressed: _randomise,
                    green: true,
                    singleLine: true,
                  ),
                ],
              ),
              nameRow(),
              _swatchesRow(
                'Culoare blană',
                catFurColours,
                const ['Gri', 'Portocaliu', 'Crem', 'Mov', 'Negru', 'Alb'],
                player.fur,
                (i) => change(() => player.fur = i),
              ),
              _choicesRow(
                'Model',
                const ['Uniform', 'Tigrat', 'Bicolor', 'Calico', 'Colorpoint'],
                player.pattern,
                (i) => change(() => player.pattern = i),
              ),
              _swatchesRow(
                'Culoare ochi',
                catEyeColours,
                const ['Verzi', 'Albaștri', 'Aurii', 'Arămii'],
                player.eyes,
                (i) => change(() => player.eyes = i),
              ),
              _choicesRow(
                'Urechi',
                const ['Două urechi', 'Doar stânga', 'Plisate', 'Smocuri'],
                player.ears,
                (i) => change(() => player.ears = i),
              ),
            ],
          ),
        ),
        const SectionHeading('PUTERE'),
        AdaptiveCardGrid(
          minWidth: 100,
          maxColumns: 3,
          children: [
            for (var i = 0; i < powers.length; i++)
              _EquipCard(
                art: powers[i],
                title: powerNames[i],
                selected: i == player.power,
                buttonText: i == player.power ? 'ECHIPAT' : 'ECHIPEAZĂ',
                green: i != player.power,
                onPressed: () => change(() => player.power = i),
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
                player.cat == 'Tzuki'
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
      const SectionHeading('ACCESORII'),
      ArenaButton(
        text: 'FĂRĂ ACCESORIU',
        onPressed: () => change(() => player.accessory = ''),
      ),
      const SizedBox(height: 6),
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
                  : 'MAGAZIN • 300',
              green: player.accessory != item && player.owned.contains(item),
              onPressed: () => player.owned.contains(item)
                  ? change(() => player.accessory = item)
                  : widget.onShop(),
            ),
        ],
      ),
    ],
  );
}

class _CatsBanner extends StatelessWidget {
  const _CatsBanner();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: _bannerGradient,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: gold, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x6651312d),
          offset: Offset(0, 4),
          blurRadius: 6,
        ),
      ],
    ),
    child: Row(
      children: [
        sprite('tile_paw', size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('PISICILE TALE', size: 22),
              const SizedBox(height: 2),
              Text(
                'Alege-ți companionul de arenă',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cream.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        sprite('tile_paw', size: 44),
      ],
    ),
  );
}

class _CatStage extends StatelessWidget {
  const _CatStage({required this.player, this.catName});
  final Player player;
  final String? catName;

  @override
  Widget build(BuildContext context) {
    final power = player.cat == 'Tzuki'
        ? 0
        : player.cat == 'Bubble'
        ? 1
        : player.power;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: _stageGradient,
            border: Border.all(color: ink, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x6651312d),
                offset: Offset(0, 5),
                blurRadius: 8,
              ),
            ],
          ),
          child: SizedBox(
            height: 230,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 6,
                  left: 14,
                  child: Opacity(
                    opacity: 0.25,
                    child: sprite('tile_paw', size: 30),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 14,
                  child: Opacity(
                    opacity: 0.25,
                    child: sprite('tile_paw', size: 30),
                  ),
                ),
                CatCharacter(player, height: 215),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        label(
          player.cat == 'Custom'
              ? (catName ?? 'PISI').toUpperCase()
              : player.cat.toUpperCase(),
          size: 24,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _LoadoutChip(
              icon: Icons.bolt,
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

class _LoadoutChip extends StatelessWidget {
  const _LoadoutChip({required this.icon, required this.text});
  final IconData icon;
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

class _CatPickCard extends StatelessWidget {
  const _CatPickCard({
    required this.cat,
    required this.player,
    required this.onTap,
  });
  final String cat;
  final Player player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = player.cat == cat;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            gradient: selected ? _selectedGradient : _cardGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? gold : ink,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0x88ffc63c)
                    : const Color(0x6651312d),
                offset: const Offset(0, 3),
                blurRadius: selected ? 8 : 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 76, child: Center(child: _face())),
              const SizedBox(height: 6),
              Text(
                cat == 'Custom' ? 'Creează-ți Pisica' : cat,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 6),
              ArenaButton(
                text: selected ? 'ECHIPAT' : 'ALEGE',
                onPressed: onTap,
                green: !selected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _face() {
    if (cat == 'Custom') return CatAvatar(player, size: 72);
    return CatSpecAvatar(
      catSpecFor(cat, player),
      size: 72,
      showAccessory: false,
    );
  }
}

class _EquipCard extends StatelessWidget {
  const _EquipCard({
    required this.art,
    required this.title,
    required this.buttonText,
    required this.onPressed,
    this.selected = false,
    this.green = false,
  });
  final String art, title, buttonText;
  final VoidCallback? onPressed;
  final bool selected, green;

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
          sprite(art, size: 58),
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
    this.fit = BoxFit.contain,
  });

  final String asset;
  final Widget fallback;
  final double? width, height;
  final BoxFit fit;

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
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => widget.fallback,
        )
      : widget.fallback;
}

class _AvatarCushionPreview extends StatelessWidget {
  const _AvatarCushionPreview({required this.spec});
  final AvatarSpec spec;

  @override
  Widget build(BuildContext context) => Container(
    height: 230,
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: _stageGradient,
      border: Border.all(color: ink, width: 2.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x6651312d),
          offset: Offset(0, 5),
          blurRadius: 8,
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(
          child: _BundledAsset(
            asset: 'assets/images/cat_cushion.png',
            fit: BoxFit.cover,
            fallback: const SizedBox.expand(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: AvatarAvatar(spec, size: 150),
        ),
      ],
    ),
  );
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

/// Bottom-sheet editor for the player's avatar. Edits a local draft and only
/// persists through [onSave]; owned accessories are the only ones offered.
class _AvatarEditorSheet extends StatefulWidget {
  const _AvatarEditorSheet({
    required this.initial,
    required this.owned,
    required this.onSave,
  });
  final AvatarSpec initial;
  final Set<String> owned;
  final ValueChanged<AvatarSpec> onSave;

  @override
  State<_AvatarEditorSheet> createState() => _AvatarEditorSheetState();
}

class _AvatarEditorSheetState extends State<_AvatarEditorSheet> {
  late AvatarSpec _spec = widget.initial;
  final _random = Random();

  List<String> get _ownedAccessories =>
      accessories.where(widget.owned.contains).toList();

  void _update(AvatarSpec next) => setState(() => _spec = next);

  void _randomise() => setState(() {
    final ownedAcc = _ownedAccessories;
    _spec = AvatarSpec(
      fur: _furIndices[_random.nextInt(_furIndices.length)],
      pattern: _random.nextInt(catPatternCount),
      eyes: _random.nextInt(catEyeColours.length),
      ears: _random.nextInt(catEarCount),
      accessory: ownedAcc.isEmpty
          ? ''
          : ownedAcc[_random.nextInt(ownedAcc.length)],
      power: avatarPowerIds[_random.nextInt(avatarPowerIds.length)],
    );
  });

  /// Fur choices offered to the avatar — natural cat coats only. Indices
  /// point into [catFurColours]; a saved index outside the list still
  /// renders, it just is not reselectable here.
  static const _furIndices = [0, 1, 2, 4, 5];
  static const _furNames = ['Gri', 'Portocaliu', 'Crem', 'Negru', 'Alb'];

  static const _earLabels = [
    'Două urechi',
    'Ureche stângă',
    'Plisate',
    'Smocuri',
    'Bandaj roz',
  ];

  Widget _powerRow() {
    final selected = avatarPowerIds.indexOf(_spec.power);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PUTEREA AVATARULUI',
            style: TextStyle(
              color: Color(0xff6b4a32),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < avatarPowerIds.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 6,
                      right: i == avatarPowerIds.length - 1 ? 0 : 6,
                    ),
                    child: _AvatarPowerCard(
                      asset: 'assets/images/${avatarPowerIds[i]}.png',
                      fallback: 'vfx_${avatarPowerIds[i].substring(6)}',
                      title: avatarPowerNames[i],
                      selected: selected == i,
                      onTap: () =>
                          _update(_spec.copyWith(power: avatarPowerIds[i])),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    widget.onSave(_spec);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ownedAcc = _ownedAccessories;
    final accessoryIndex = _spec.accessory.isEmpty
        ? 0
        : ownedAcc.indexOf(_spec.accessory) + 1;
    final accessoryNames = [
      'Fără',
      for (final item in ownedAcc) itemName(item),
    ];
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xfffff3d9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0x6651312d),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CREEAZĂ-ȚI PISICA',
                      style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: ink),
                    tooltip: 'Închide',
                  ),
                ],
              ),
            ),
            _AvatarCushionPreview(spec: _spec),
            const SizedBox(height: 4),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _swatchesRow(
                    'BLANA',
                    [for (final i in _furIndices) catFurColours[i]],
                    _furNames,
                    _furIndices.indexOf(_spec.fur),
                    (i) => _update(_spec.copyWith(fur: _furIndices[i])),
                  ),
                  _choicesRow(
                    'MODEL',
                    const [
                      'Uniform',
                      'Tigrat',
                      'Bicolor',
                      'Calico',
                      'Colorpoint',
                    ],
                    _spec.pattern,
                    (i) => _update(_spec.copyWith(pattern: i)),
                  ),
                  _swatchesRow(
                    'OCHI',
                    catEyeColours,
                    const ['Verzi', 'Albaștri', 'Aurii', 'Arămii'],
                    _spec.eyes,
                    (i) => _update(_spec.copyWith(eyes: i)),
                  ),
                  _choicesRow(
                    'URECHI',
                    _earLabels,
                    _spec.ears.clamp(0, _earLabels.length - 1).toInt(),
                    (i) => _update(_spec.copyWith(ears: i)),
                  ),
                  _powerRow(),
                  _choicesRow(
                    'ACCESORII',
                    accessoryNames,
                    accessoryIndex.clamp(0, accessoryNames.length - 1),
                    (i) => _update(
                      _spec.copyWith(accessory: i == 0 ? '' : ownedAcc[i - 1]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ArenaButton(
                          text: 'ALEATORIZEAZĂ',
                          onPressed: _randomise,
                          green: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ArenaButton(
                          text: 'SALVEAZĂ AVATAR',
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
