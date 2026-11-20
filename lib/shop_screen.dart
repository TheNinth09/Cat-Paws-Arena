import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'catalog.dart';
import 'profile.dart';
import 'shell/cosmetic_offers.dart';
import 'shell/purchase_service.dart';
import 'ui_widgets.dart';

const _cardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xffffe0a0), Color(0xffffedbb), Color(0xffe9ab60)],
);
const _badgeGradient = LinearGradient(
  colors: [Color(0xffe2725b), Color(0xffa83a2e)],
);

const _dailyDeal = CosmeticOffer(
  id: 'daily_deal_special',
  title: 'DAILY DEAL',
  subtitle: 'PACHET SPECIAL',
  art: 'acc_pirate_bandana',
  extraArt: 'tile_yarn',
  leiPrice: '8.99 LEI',
  items: ['acc_pirate_bandana'],
);

const _pawPackAssets = [
  'shop_paws_small',
  'shop_paws_medium',
  'shop_paws_medium',
  'shop_paws_mega',
  'shop_paws_mega',
  'shop_paws_mega',
];
const _pawPackFallbacks = [
  'icon_paw_coin',
  'icon_paw_coin',
  'icon_paw_coin',
  'icon_paw_coin',
  'icon_chest',
  'icon_chest',
];

Set<String>? _assetNames;

Future<Set<String>> _bundledAssets() async {
  final cached = _assetNames;
  if (cached != null) return cached;
  final names = (await AssetManifest.loadFromAssetBundle(rootBundle))
      .listAssets()
      .toSet();
  return _assetNames = names;
}

Widget _offerImage(String asset, String fallback, double size) => _BundledAsset(
  asset: asset,
  width: size,
  height: size,
  fallback: sprite(fallback, size: size),
);

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

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
    required this.onMessage,
    this.purchaseService = const UnavailablePurchaseService(),
  });
  final Player player;
  final ValueChanged<String> onUnavailable;
  final void Function(String, String) onMessage;
  final PurchaseService purchaseService;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Player get player => widget.player;

  bool ownsOffer(CosmeticOffer offer) =>
      offer.items.every(player.owned.contains);

  Future<void> buyOffer(CosmeticOffer offer) async {
    final result = await widget.purchaseService.purchase(offer.id);
    if (result.success) {
      player.owned.addAll(offer.items);
      await player.save();
      return;
    }
    widget.onMessage('Magazin', result.message);
  }

  Future<void> buyCoinBundle(int index) async {
    final bundle = coinBundles[index];
    final amount = bundle.$1.replaceAll(',', '');
    final result = await widget.purchaseService.purchase(
      'coin_bundle_$amount',
    );
    if (result.success) {
      player.coins += int.tryParse(amount) ?? 0;
      await player.save();
      return;
    }
    widget.onMessage('Pachete Lăbuțe', result.message);
  }

  /// Packs priced in earned paws — real offline economy, no billing.
  Future<void> buyPawOffer(List<String> items, int price) async {
    if (items.every(player.owned.contains)) return;
    if (player.coins < price) {
      widget.onMessage(
        'Magazin',
        'Nu ai destule lăbuțe încă — le câștigi din meciuri și din recompensa zilnică.',
      );
      return;
    }
    player.coins -= price;
    player.owned.addAll(items);
    await player.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ownsDeal = ownsOffer(_dailyDeal);
    return Stack(
      children: [
        ListView(
          key: const PageStorageKey('shop-scroll'),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
        const SectionHeading('ZONA DE OFERTE'),
        _HeroDealCard(
          owned: ownsDeal,
          onPressed: ownsDeal ? null : () => buyOffer(_dailyDeal),
        ),
        const SizedBox(height: 10),
        _HeroGiftCard(player: player),
        const SectionHeading('PACHETE LĂBUȚE'),
        AdaptiveCardGrid(
          key: const ValueKey('coin-bundle-grid'),
          minWidth: 100,
          maxColumns: 3,
          children: [
            for (var i = 0; i < coinBundles.length; i++)
              _PackCard(
                key: ValueKey('coin-bundle-$i'),
                amount: coinBundles[i].$1,
                price: '${coinBundles[i].$2} LEI',
                badge: coinBundles[i].$3,
                asset: 'assets/images/${_pawPackAssets[i]}.png',
                fallback: _pawPackFallbacks[i],
                onTap: () => buyCoinBundle(i),
              ),
          ],
        ),
        const SectionHeading('ACCESORII PE LĂBUȚE'),
        AdaptiveCardGrid(
          key: const ValueKey('paw-offer-grid'),
          minWidth: 150,
          maxColumns: 2,
          children: [
            for (var i = 0; i < accessories.length; i++)
              _CoinCard(
                key: ValueKey('paw-offer-$i'),
                title: accessoryNames[i],
                art: accessories[i],
                price: 2500,
                owned: player.owned.contains(accessories[i]),
                onTap: () => buyPawOffer([accessories[i]], 2500),
              ),
            _CoinCard(
              key: const ValueKey('paw-offer-bundle'),
              title: 'PACHET COMPLET',
              subtitle: 'Toate cele 4 accesorii',
              art: accessories[0],
              extraArt: accessories[2],
              price: 8500,
              badge: '-15%',
              owned: accessories.every(player.owned.contains),
              onTap: () => buyPawOffer(accessories, 8500),
            ),
          ],
        ),
        const SectionHeading('PACHETE COSMETICE'),
        AdaptiveCardGrid(
          minWidth: 180,
          maxColumns: 2,
          children: [
            for (final offer in cosmeticOffers)
              ShopOfferCard(
                title: offer.title,
                art: offer.art,
                extraArt: offer.extraArt,
                subtitle: offer.subtitle,
                buttonText: ownsOffer(offer) ? 'DEȚINUT' : offer.leiPrice,
                onPressed: ownsOffer(offer)
                    ? null
                    : () {
                        buyOffer(offer);
                      },
              ),
          ],
        ),
      ],
        ),
      ],
    );
  }
}

/// Big featured-deal banner inspired by premium match-3 shops: deep
/// violet panel, product art on the left, contents on the right and a
/// full-width price button at the bottom.
class _HeroDealCard extends StatelessWidget {
  const _HeroDealCard({required this.owned, required this.onPressed});
  final bool owned;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff8154a8), Color(0xff4b2d68)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: gold, width: 2.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x6620130e),
          offset: Offset(0, 5),
          blurRadius: 8,
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(19),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x3dffffff), Color(0x00ffffff)],
        stops: [0, 0.22],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Column(
      children: [
        Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                sprite(_dailyDeal.art, size: 74),
                sprite(_dailyDeal.extraArt!, size: 30),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dailyDeal.title,
                    style: const TextStyle(
                      color: gold,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Color(0x80000000),
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _OfferBadge('PACHET SPECIAL'),
                  const SizedBox(height: 8),
                  const Text(
                    'Accesoriu pentru pisica ta',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cream,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ArenaButton(
            text: owned ? 'DEȚINUT' : 'PACHET • 8.99 LEI',
            onPressed: onPressed,
            green: true,
            singleLine: true,
          ),
        ),
      ],
    ),
  );
}

/// Warm hero card for the daily free gift — the shop's "lucky" row.
class _HeroGiftCard extends StatelessWidget {
  const _HeroGiftCard({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: _cardGradient,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: ink, width: 2.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x6651312d),
          offset: Offset(0, 5),
          blurRadius: 8,
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Stack(
      children: [
        Column(
          children: [
            Row(
              children: [
                _offerImage(
                  'assets/images/paws_daily_5.png',
                  'icon_chest',
                  68,
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECOMPENSĂ ZILNICĂ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    player.dailyReady
                        ? 'Cadou gratuit (la 6 ore)'
                        : 'Revino peste 6 ore',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ArenaButton(
            text: player.dailyReady ? '+5 Lăbuțe' : 'REVENDICAT',
            onPressed: player.dailyReady ? player.claimDaily : null,
            green: true,
            singleLine: true,
          ),
        ),
          ],
        ),
        if (player.dailyReady)
          const Positioned(top: 0, right: 0, child: _OfferBadge('GRATIS')),
      ],
    ),
  );
}

/// Paw-pack tile with the price as a glossy green strip across the
/// card's bottom edge; the popularity badge is a ribbon sitting on top
/// of the strip, like the reference shop's coin packs.
class _PackCard extends StatelessWidget {
  const _PackCard({
    super.key,
    required this.amount,
    required this.price,
    required this.badge,
    required this.asset,
    required this.fallback,
    required this.onTap,
  });
  final String amount, price, badge, asset, fallback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          gradient: _cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ink, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x6651312d),
              offset: Offset(0, 4),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: badge.isNotEmpty ? 14 : 8),
            _offerImage(asset, fallback, 52),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$amount LĂBUȚE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xff6fc040), Color(0xff3f8f1e)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: Color(0xff2f6b14), width: 1.5),
                    ),
                  ),
                  child: Text(
                    price,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                if (badge.isNotEmpty)
                  Positioned(
                    top: -11,
                    left: -10,
                    right: -10,
                    child: Center(child: _OfferBadge(badge)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Cosmetic tile paid with earned paws: same card language as the paw
/// packs, but the bottom strip is gold and shows a paw icon + price.
class _CoinCard extends StatelessWidget {
  const _CoinCard({
    super.key,
    required this.title,
    required this.art,
    required this.price,
    required this.owned,
    required this.onTap,
    this.subtitle,
    this.extraArt,
    this.badge = '',
  });
  final String title, art;
  final String? subtitle, extraArt;
  final String badge;
  final int price;
  final bool owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: owned ? null : onTap,
      child: Ink(
        decoration: BoxDecoration(
          gradient: _cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ink, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x6651312d),
              offset: Offset(0, 4),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: badge.isNotEmpty ? 14 : 10),
            if (extraArt == null)
              sprite(art, size: 56)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: sprite(art, size: 44)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                  ),
                  Flexible(child: sprite(extraArt!, size: 44)),
                ],
              ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.62),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: owned
                          ? const [Color(0xff9a8a78), Color(0xff6f6257)]
                          : const [Color(0xfff0b93e), Color(0xffcf8a10)],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: owned
                            ? const Color(0xff5c5044)
                            : const Color(0xffa06a08),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: owned
                      ? const Center(
                          child: Text(
                            'DEȚINUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            sprite('icon_paw_coin', size: 18),
                            const SizedBox(width: 5),
                            Text(
                              _pawPrice(price),
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0x66000000),
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                if (badge.isNotEmpty)
                  Positioned(
                    top: -11,
                    left: -10,
                    right: -10,
                    child: Center(child: _OfferBadge(badge)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _pawPrice(int v) => v >= 1000
    ? '${v ~/ 1000},${(v % 1000).toString().padLeft(3, '0')}'
    : '$v';


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
        letterSpacing: 0.4,
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
    this.asset,
    this.badge = '',
    this.badgeArt,
    this.compact = false,
  });
  final String title, art, buttonText, badge;
  final String? subtitle, extraArt, asset, badgeArt;
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
          if (badge.isNotEmpty)
            badgeArt == null
                ? _OfferBadge(badge)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      sprite(badgeArt!, size: 16),
                      const SizedBox(width: 5),
                      Flexible(child: _OfferBadge(badge)),
                    ],
                  ),
          if (badge.isNotEmpty) SizedBox(height: compact ? 4 : 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ink,
              fontSize: compact ? 18 : 15,
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
            asset == null
                ? sprite(art, size: compact ? 58 : 80)
                : _offerImage(asset!, art, compact ? 58 : 80)
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
