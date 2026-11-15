import 'package:flutter/material.dart';

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

class CatsScreen extends StatelessWidget {
  const CatsScreen({super.key, required this.player, required this.onShop});
  final Player player;
  final VoidCallback onShop;
  void change(VoidCallback update) {
    update();
    player.save();
  }

  Widget choices(
    String title,
    List<String> names,
    int selected,
    ValueChanged<int> update,
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
                onTap: () => change(() => update(i)),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('cats-scroll'),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
    children: [
      const _CatsBanner(),
      _CatStage(player: player),
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
              const _PanelTitle('PERSONALIZARE'),
              choices(
                'Culoare blană',
                ['Gri', 'Portocaliu', 'Crem', 'Mov'],
                player.fur,
                (v) => player.fur = v,
              ),
              choices(
                'Model',
                ['Uniform', 'Tigrat'],
                player.pattern,
                (v) => player.pattern = v,
              ),
              choices(
                'Culoare ochi',
                ['Verzi', 'Albaștri', 'Aurii'],
                player.eyes,
                (v) => player.eyes = v,
              ),
              choices(
                'Urechi',
                ['Două urechi', 'Doar stânga'],
                player.ears,
                (v) => player.ears = v,
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
                buttonText: i == player.power
                    ? 'ECHIPAT'
                    : i == 0 || player.owned.contains(powers[i])
                    ? 'ECHIPEAZĂ'
                    : 'DEBLOCHEAZĂ ÎN MAGAZIN',
                green:
                    i != player.power &&
                    (i == 0 || player.owned.contains(powers[i])),
                onPressed: () => i == 0 || player.owned.contains(powers[i])
                    ? change(() => player.power = i)
                    : onShop(),
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
                  : onShop(),
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
  const _CatStage({required this.player});
  final Player player;

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
        label(player.cat.toUpperCase(), size: 24),
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
            Text(
              text,
              style: const TextStyle(
                color: ink,
                fontSize: 13,
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
