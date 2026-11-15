import 'package:flutter/material.dart';

import 'catalog.dart';
import 'profile.dart';
import 'ui_widgets.dart';

const _cardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xffffe0a0), Color(0xffffedbb), Color(0xffe9ab60)],
);
const _bannerGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xff9a6242), Color(0xff74463a)],
);
const _badgeGradient = LinearGradient(
  colors: [Color(0xffe2725b), Color(0xffa83a2e)],
);

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
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
    children: [
      const _ShopBanner(),
      const SectionHeading('ZONA DE OFERTE'),
      AdaptiveCardGrid(
        minWidth: 150,
        maxColumns: 2,
        children: [
          ShopOfferCard(
            title: 'RECOMPENSĂ ZILNICĂ',
            art: 'icon_chest',
            subtitle: 'Cadoul de azi',
            badge: player.daily == player.today ? '' : 'GRATUIT',
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
            badge: player.owned.contains('daily_combo') ? '' : 'DEAL ZILNIC',
            buttonText: player.owned.contains('daily_combo')
                ? 'DEȚINUT'
                : '650 Lăbuțe',
            onPressed: player.owned.contains('daily_combo') ? null : buyCombo,
          ),
        ],
      ),
      const SectionHeading('PACHETE LĂBUȚE'),
      const _BillingNote(),
      AdaptiveCardGrid(
        key: const ValueKey('coin-bundle-grid'),
        minWidth: 96,
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
        minWidth: 150,
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

class _ShopBanner extends StatelessWidget {
  const _ShopBanner();

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
        sprite('icon_paw_coin', size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('MAGAZINUL', size: 26),
              const SizedBox(height: 2),
              Text(
                'Oferte noi în fiecare zi',
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
        sprite('icon_chest', size: 46),
      ],
    ),
  );
}

class _BillingNote extends StatelessWidget {
  const _BillingNote();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xeefff3d6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ink, width: 1.5),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: ink, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Achizițiile reale necesită Google Play Billing.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OfferBadge extends StatelessWidget {
  const _OfferBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      gradient: _badgeGradient,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ink, width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0x44000000), offset: Offset(0, 2)),
      ],
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: cream,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    ),
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
    decoration: BoxDecoration(
      gradient: _cardGradient,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ink, width: compact ? 2 : 2.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x6651312d),
          offset: Offset(0, 4),
          blurRadius: 5,
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(17),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x66ffffff), Color(0x00ffffff)],
        stops: const [0, 0.16],
      ),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 12,
        badge.isNotEmpty ? (compact ? 15 : 17) : (compact ? 8 : 10),
        compact ? 8 : 12,
        compact ? 8 : 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge.isNotEmpty) _OfferBadge(badge),
          if (badge.isNotEmpty) SizedBox(height: compact ? 4 : 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ink,
              fontSize: compact ? 20 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.68),
                  fontSize: compact ? 9.5 : 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          SizedBox(height: compact ? 6 : 10),
          if (extraArt == null)
            sprite(art, size: compact ? 58 : 80)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: sprite(art, size: 56)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '+',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
                Flexible(child: sprite(extraArt!, size: 56)),
              ],
            ),
          const Spacer(),
          const SizedBox(height: 6),
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
    ),
  );
}
