import 'package:flutter/material.dart';

import 'cat_avatar.dart';
import 'catalog.dart';
import 'profile.dart';
import 'ui_widgets.dart';

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
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < names.length; i++)
              ChoiceChip(
                label: Text(names[i]),
                selected: selected == i,
                onSelected: (_) => change(() => update(i)),
                selectedColor: gold,
              ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('cats-scroll'),
    padding: const EdgeInsets.all(12),
    children: [
      const SectionHeading('PISICILE TALE'),
      Center(child: CatCharacter(player, height: 245)),
      AdaptiveCardGrid(
        minWidth: 110,
        maxColumns: 3,
        children: [
          for (final cat in ['Tzuki', 'Bubble', 'Custom'])
            panel(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pets, color: ink, size: 32),
                  Text(
                    cat == 'Custom' ? 'Creează-ți Pisica' : cat,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  ArenaButton(
                    text: player.cat == cat ? 'ECHIPAT' : 'ALEGE',
                    onPressed: () => change(() {
                      player.cat = cat;
                      player.photo = null;
                    }),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
            ),
        ],
      ),
      if (player.cat == 'Custom')
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const Divider(color: ink),
              const Text(
                'Putere echipată',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              for (var i = 0; i < powers.length; i++)
                ProductCard(
                  title: powerNames[i],
                  spriteName: powers[i],
                  buttonText: i == player.power
                      ? 'ECHIPAT'
                      : i == 0 || player.owned.contains(powers[i])
                      ? 'ECHIPEAZĂ'
                      : 'DEBLOCHEAZĂ ÎN MAGAZIN',
                  onPressed: () => i == 0 || player.owned.contains(powers[i])
                      ? change(() => player.power = i)
                      : onShop(),
                ),
            ],
          ),
        )
      else
        panel(
          Text(
            player.cat == 'Tzuki'
                ? 'Tzuki • O singură ureche, stânga\nThe Midnight Zoomies'
                : 'Bubble • Shadow Pounce',
            textAlign: TextAlign.center,
          ),
        ),
      const SectionHeading('ACCESORII'),
      ArenaButton(
        text: 'FĂRĂ ACCESORIU',
        onPressed: () => change(() => player.accessory = ''),
      ),
      AdaptiveCardGrid(
        minWidth: 145,
        maxColumns: 2,
        children: [
          for (final item in accessories)
            ProductCard(
              title: itemName(item),
              spriteName: item,
              buttonText: player.accessory == item
                  ? 'ECHIPAT'
                  : player.owned.contains(item)
                  ? 'ECHIPEAZĂ'
                  : 'MAGAZIN • 300',
              onPressed: () => player.owned.contains(item)
                  ? change(() => player.accessory = item)
                  : onShop(),
            ),
        ],
      ),
    ],
  );
}
