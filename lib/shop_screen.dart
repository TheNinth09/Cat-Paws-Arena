import 'package:flutter/material.dart';

import 'catalog.dart';
import 'profile.dart';
import 'ui_widgets.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
    required this.onMessage,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;
  final void Function(String, String) onMessage;
  void buyCombo() {
    if (player.coins < 650) {
      onMessage('Oferta zilei', 'Nu ai suficiente Lăbuțe.');
      return;
    }
    player.coins -= 650;
    player.owned.addAll(['daily_combo', accessories[0], powers[0]]);
    player.save();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('shop-scroll'),
    padding: const EdgeInsets.all(12),
    children: [
      const SectionHeading('ZONA DE OFERTE'),
      AdaptiveCardGrid(
        minWidth: 145,
        maxColumns: 2,
        children: [
          ShopOfferCard(
            title: 'RECOMPENSĂ ZILNICĂ',
            art: 'icon_chest',
            subtitle: 'Cadoul de azi',
            buttonText: player.daily == player.today
                ? 'REVENDICAT'
                : '+200 Lăbuțe',
            onPressed: player.daily == player.today ? null : player.claimDaily,
          ),
          ShopOfferCard(
            title: 'DAILY DEAL',
            art: 'acc_pirate_bandana',
            extraArt: 'vfx_zoomies',
            subtitle: 'Pachet special',
            buttonText: player.owned.contains('daily_combo')
                ? 'DEȚINUT'
                : '650 Lăbuțe',
            onPressed: player.owned.contains('daily_combo') ? null : buyCombo,
          ),
        ],
      ),
      const SectionHeading('PACHETE LĂBUȚE'),
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'Achizițiile reale necesită Google Play Billing.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cream, fontSize: 12),
        ),
      ),
      AdaptiveCardGrid(
        key: const ValueKey('coin-bundle-grid'),
        minWidth: 94,
        maxColumns: 3,
        children: [
          for (var i = 0; i < coinBundles.length; i++)
            ShopOfferCard(
              key: ValueKey('coin-bundle-$i'),
              title: coinBundles[i].$1,
              subtitle: 'LĂBUȚE',
              art: i >= 4 ? 'icon_chest' : 'icon_paw_coin',
              badge: coinBundles[i].$3,
              buttonText: '${coinBundles[i].$2} LEI',
              onPressed: () => onUnavailable('Google Play Billing'),
              compact: true,
            ),
        ],
      ),
      const SectionHeading('ACCESORII & PUTERI'),
      AdaptiveCardGrid(
        minWidth: 140,
        maxColumns: 2,
        children: [
          for (final item in [...accessories, ...powers])
            ShopOfferCard(
              title: itemName(item),
              art: item,
              buttonText: player.owned.contains(item)
                  ? 'DEȚINUT'
                  : '300 Lăbuțe',
              onPressed: player.owned.contains(item)
                  ? null
                  : () {
                      if (!player.buy(item, 300)) {
                        onMessage('Lăbuțe', 'Nu ai suficiente Lăbuțe.');
                      }
                    },
            ),
        ],
      ),
    ],
  );
}

class ShopOfferCard extends StatelessWidget {
  const ShopOfferCard({
    super.key,
    required this.title,
    required this.art,
    required this.buttonText,
    required this.onPressed,
    this.subtitle,
    this.extraArt,
    this.badge = '',
    this.compact = false,
  });
  final String title, art, buttonText, badge;
  final String? subtitle, extraArt;
  final VoidCallback? onPressed;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 7 : 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xffffd89b), Color(0xffffedbb), Color(0xffe8b26e)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ink, width: 3),
      boxShadow: const [
        BoxShadow(color: Color(0x6651312d), offset: Offset(0, 4)),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ink,
            fontSize: compact ? 23 : 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (extraArt == null)
          sprite(art, size: compact ? 65 : 90)
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: sprite(art, size: 65)),
              const Text(
                '+',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              Flexible(child: sprite(extraArt!, size: 65)),
            ],
          ),
        if (badge.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xffab4a42),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  badge,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ArenaButton(
            text: buttonText,
            onPressed: onPressed,
            green: !compact,
            singleLine: compact,
          ),
        ),
      ],
    ),
  );
}
