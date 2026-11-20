import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const ink = Color(0xff51312d),
    cream = Color(0xffffedbb),
    gold = Color(0xffffc63c);

Widget sprite(String name, {double size = 40}) => Image.asset(
  'assets/generated/$name.png',
  width: size,
  height: size,
  fit: BoxFit.contain,
);

/// Lane-1 game art placed under `assets/images/`. While the asset pipeline
/// has not bundled a file yet, [fallback] (a procedural painter or sprite)
/// is shown instead so screens never depend on merge order.
Widget arenaImage(
  String name, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  Widget? fallback,
}) => Image.asset(
  'assets/images/$name.png',
  width: width,
  height: height,
  fit: fit,
  errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
);

Widget label(String text, {double size = 22, Color color = cream}) => Text(
  text,
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w900,
    shadows: color == ink
        ? null
        : const [Shadow(color: ink, offset: Offset(0, 2), blurRadius: 3)],
  ),
);

Widget panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(14)}) =>
    Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xfffff8e4), Color(0xfffdf0cd), Color(0xfff2d5a0)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffb57f4e), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x383c241a),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );

Widget action(String text, VoidCallback? onTap, {bool green = false}) =>
    ArenaButton(
      text: text,
      onPressed: onTap,
      green: green,
      spriteName: text.startsWith('LUPTĂ') || text.startsWith('BATTLE')
          ? 'btn_play_paw'
          : null,
    );

class ArenaButton extends StatefulWidget {
  const ArenaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.green = false,
    this.spriteName,
    this.singleLine = false,
    this.secondary = false,
    this.danger = false,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool green, singleLine, secondary, danger;
  final String? spriteName;

  @override
  State<ArenaButton> createState() => _ArenaButtonState();
}

class _ArenaButtonState extends State<ArenaButton> {
  bool pressed = false;

  List<Color> get fill => widget.danger
      ? const [
          Color(0xffffb59d),
          Color(0xffef7a68),
          Color(0xffd14f41),
          Color(0xffb23c31),
        ]
      : widget.green
      ? const [
          Color(0xffc2f09a),
          Color(0xff8fd46f),
          Color(0xff63ab49),
          Color(0xff4a8a37),
        ]
      : widget.secondary
      ? const [
          Color(0xfffff8e8),
          Color(0xfff6e3b8),
          Color(0xffe8c98c),
          Color(0xffd9b276),
        ]
      : const [
          Color(0xfffff6b8),
          Color(0xffffe08a),
          gold,
          Color(0xffeda52c),
          Color(0xffdf931f),
        ];

  Color get edge => widget.danger
      ? const Color(0xff8e3227)
      : widget.green
      ? const Color(0xff3f6d22)
      : widget.secondary
      ? const Color(0xffa9763f)
      : const Color(0xffa86f16);

  Color get foreground => widget.danger ? cream : ink;

  Widget caption() => Text(
    widget.text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: foreground,
      fontSize: 16,
      fontWeight: FontWeight.w900,
      shadows: [
        Shadow(
          color: widget.danger
              ? const Color(0x55000000)
              : Colors.white.withValues(alpha: .55),
          offset: const Offset(0, -1),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedScale(
            scale: pressed ? 0.95 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: fill,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: edge, width: 1.6),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5520130e),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Color(0x443c241a),
                    offset: Offset(0, 7),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  onHighlightChanged: (highlighted) {
                    if (mounted) setState(() => pressed = highlighted);
                  },
                  borderRadius: BorderRadius.circular(18),
                  splashColor: Colors.white.withValues(alpha: .4),
                  highlightColor: Colors.white.withValues(alpha: .12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 50,
                      minWidth: 76,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 2,
                          left: 12,
                          right: 12,
                          height: 20,
                          child: const IgnorePointer(child: _Gloss(top: true)),
                        ),
                        Positioned(
                          bottom: 2,
                          left: 12,
                          right: 12,
                          height: 12,
                          child: const IgnorePointer(child: _Gloss(top: false)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.spriteName != null) ...[
                                sprite(widget.spriteName!, size: 30),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: widget.singleLine
                                    ? FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: caption(),
                                      )
                                    : caption(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Gloss extends StatelessWidget {
  const _Gloss({required this.top});
  final bool top;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.vertical(
        top: top ? const Radius.circular(13) : Radius.zero,
        bottom: top ? Radius.zero : const Radius.circular(12),
      ),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: top
            ? [
                Colors.white.withValues(alpha: .5),
                Colors.white.withValues(alpha: 0),
              ]
            : [const Color(0x00000000), const Color(0x2e000000)],
      ),
    ),
  );
}

class PlayerHud extends StatelessWidget {
  const PlayerHud({
    super.key,
    required this.avatar,
    required this.name,
    required this.trophies,
    required this.coins,
    required this.onProfile,
    required this.onRoad,
    required this.onShop,
    required this.onMenu,
    this.trophyBadgeKey,
    this.coinBadgeKey,
  });
  final Widget avatar;
  final String name;
  final int trophies, coins;
  final VoidCallback onProfile, onRoad, onShop, onMenu;

  /// Optional keys so a victory-flight overlay can find the badge centers.
  final Key? trophyBadgeKey, coinBadgeKey;

  /// Compact stat segment inside the avatar tile: tiny icon + value,
  /// individually tappable (trophy → road, coins → shop).
  Widget _stat(
    String asset,
    String value,
    VoidCallback tap, {
    Key? key,
    bool plus = false,
  }) => Expanded(
    child: KeyedSubtree(
      key: key,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              sprite(asset, size: 15),
              const SizedBox(width: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: cream,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (plus)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xff93d94f), Color(0xff4e9c22)],
                    ),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(Icons.add, size: 9, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    // Frameless top: one compact avatar tile (portrait, name, stats) on
    // the left and the menu button on the right — no bar, no big pills.
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x3d20130e), Color(0x0020130e)],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xcc8a5c3e), Color(0xcc5d3a2c)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0x66ffe9bd),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xff9a6b4a), Color(0xff5c3a26)],
                        ),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xfff3d99b),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: avatar,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: cream,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              shadows: [
                                Shadow(
                                  color: Color(0x66000000),
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        SizedBox(
                          width: 96,
                          child: Row(
                            children: [
                              _stat(
                                'icon_trophy',
                                '$trophies',
                                onRoad,
                                key: trophyBadgeKey,
                              ),
                              _stat(
                                'icon_paw_coin',
                                '$coins',
                                onShop,
                                key: coinBadgeKey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'Meniu',
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff5f96d4), Color(0xff2e5c96)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44000000),
                    offset: Offset(0, 2),
                    blurRadius: 5,
                  ),
                ],
              ),
              foregroundDecoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x59ffffff), Color(0x00ffffff)],
                  stops: [0, 0.45],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onMenu,
                  customBorder: const CircleBorder(),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Bottom navigation in the Match Masters style: a deep-navy band with
/// dark 3D icon tiles and one big golden tab protruding above the band's
/// top edge — the centre LUPTĂ is always the biggest; the active side
/// tab also lifts into a golden tile.
class ArenaBottomBar extends StatelessWidget {
  const ArenaBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.english = false,
    this.shopBadge = false,
    this.haptics = true,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final bool english;
  final bool shopBadge;

  /// Whether tap haptics fire — bound to the player's Vibrații setting.
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    final labels = english
        ? const ['SHOP', 'CATS', 'HOME', 'TEAM', 'EVENTS']
        : const ['MAGAZIN', 'PISICI', 'ACASĂ', 'ECHIPĂ', 'EVENIMENTE'];
    const icons = [
      Icons.storefront,
      Icons.pets,
      Icons.sports_esports,
      Icons.shield,
      Icons.event,
    ];

    Widget tileIcon(int i) {
      final active = selected == i;
      final iconColor = active || i == 2
          ? const Color(0xff5d3a2c)
          : const Color(0xffdce9f7);
      switch (i) {
        case 0:
          return CustomPaint(
            size: const Size(30, 30),
            painter: _ShopIconPainter(selected: active),
          );
        case 1:
          return CustomPaint(
            size: const Size(30, 30),
            painter: _CatsIconPainter(selected: active),
          );
        case 2:
          return sprite('btn_play_paw', size: 42);
        case 3:
        case 4:
          return arenaImage(
            i == 3 ? 'icon_team' : 'icon_events',
            width: 30,
            height: 30,
            fallback: Icon(icons[i], size: 27, color: iconColor),
          );
        default:
          return Icon(icons[i], size: 21, color: iconColor);
      }
    }

    // Band height 54 + headroom so the raised tiles can pop above it.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return SizedBox(
      height: 84 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 54 + bottomInset,
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff4a7ec2), Color(0xff2c4e85)],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xff8fb4e0), width: 2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x5520130e),
                    offset: Offset(0, -6),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            bottom: bottomInset,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      flex: i == 2 ? 3 : 2,
                      child: _NavButton(
                        key: ValueKey('nav-$i'),
                        label: labels[i],
                        centre: i == 2,
                        active: selected == i,
                        badge: i == 0 && shopBadge,
                        haptics: haptics,
                        onTap: () => onSelected(i),
                        child: tileIcon(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One nav tab, Match Masters style: inactive tabs are dark-navy 3D
/// tiles recessed in the band; the active tab (and always the centre
/// LUPTĂ button) is a golden tile that protrudes above the band's top
/// edge. Pressing scales it down with a selection haptic.
class _NavButton extends StatefulWidget {
  const _NavButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.centre = false,
    this.active = false,
    this.badge = false,
    this.haptics = true,
  });

  final String label;
  final bool haptics;
  final VoidCallback onTap;
  final Widget child;
  final bool centre, active, badge;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final centre = widget.centre;
    final active = widget.active;
    final golden = active || centre;
    // Tile heights measured from the row bottom: the band occupies its
    // lower 54 px, so taller tiles protrude above the band's top edge.
    final h = centre ? 78.0 : (active ? 62.0 : 50.0);
    return Semantics(
      button: true,
      selected: active,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 3,
            right: 3,
            bottom: 0,
            height: h,
            child: AnimatedScale(
              scale: _pressed ? 0.92 : 1,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: golden
                        ? const [
                            Color(0xfffff6b8),
                            Color(0xffffe08a),
                            gold,
                            Color(0xffdf931f),
                          ]
                        : const [
                            Color(0xff5d8cc9),
                            Color(0xff3a61a0),
                            Color(0xff2d4c81),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(centre ? 18 : 14),
                  border: Border.all(
                    color: golden
                        ? const Color(0xff8a4b0f)
                        : const Color(0xff1d3460),
                    width: centre || active ? 2.4 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: golden
                          ? const Color(0x99ffc63c)
                          : const Color(0x66101d38),
                      offset: Offset(0, golden ? 3 : 4),
                      blurRadius: golden ? 10 : 0,
                    ),
                    if (golden)
                      const BoxShadow(
                        color: Color(0x44fff3c4),
                        offset: Offset(0, -1),
                        blurRadius: 6,
                      ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.expand,
                    children: [
                      InkWell(
                        onTap: widget.onTap,
                        onHighlightChanged: (v) {
                          if (v && widget.haptics) {
                            HapticFeedback.selectionClick();
                          }
                          if (mounted) setState(() => _pressed = v);
                        },
                        borderRadius: BorderRadius.circular(centre ? 18 : 14),
                        splashColor: Colors.white.withValues(alpha: .45),
                        highlightColor: Colors.white.withValues(alpha: .10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(child: widget.child),
                            SizedBox(
                              height: centre ? 13 : 11,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.label,
                                  style: TextStyle(
                                    color: golden
                                        ? const Color(0xff5d3a2c)
                                        : const Color(0xffdce9f7),
                                    fontSize: centre ? 10.5 : 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                        color: golden
                                            ? const Color(0x66ffffff)
                                            : const Color(0x66101d38),
                                        offset: const Offset(0, -0.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.badge)
                        Positioned(
                          right: -2,
                          top: -3,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xffe2433a),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// Storefront glyph for the shop tab: scalloped striped awning over a
/// little stall. Drawn from shapes so it stays crisp at any size.
class _ShopIconPainter extends CustomPainter {
  const _ShopIconPainter({required this.selected});
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = Paint()
      ..color = selected ? const Color(0xff6b3a12) : const Color(0xff7a5335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // Stall body.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.16, h * 0.42, w * 0.84, h * 0.92),
      Radius.circular(w * 0.10),
    );
    fill.color = selected ? const Color(0xffffe9b0) : const Color(0xffe6c493);
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, ink);

    // Awning: striped valance with a scalloped lower edge.
    final awn = Path()
      ..moveTo(w * 0.06, h * 0.42)
      ..lineTo(w * 0.18, h * 0.14)
      ..lineTo(w * 0.82, h * 0.14)
      ..lineTo(w * 0.94, h * 0.42)
      ..close();
    fill.color = selected ? const Color(0xffe2503e) : const Color(0xffc08a63);
    canvas.drawPath(awn, fill);
    // Stripes clipped inside the awning.
    canvas.save();
    canvas.clipPath(awn);
    fill.color = selected ? const Color(0xfffff3d6) : const Color(0xffedd3ad);
    for (var x = 0.0; x < 4; x++) {
      final sx = w * (0.16 + x * 0.17);
      canvas.drawRect(
        Rect.fromLTRB(sx, h * 0.10, sx + w * 0.085, h * 0.46),
        fill,
      );
    }
    canvas.restore();
    canvas.drawPath(awn, ink);

    // Scallops under the awning edge.
    fill.color = selected ? const Color(0xffe2503e) : const Color(0xffc08a63);
    for (var x = 0.0; x < 4; x++) {
      final cx = w * (0.17 + x * 0.22);
      canvas.drawCircle(Offset(cx, h * 0.42), w * 0.10, fill);
      canvas.drawCircle(Offset(cx, h * 0.42), w * 0.10, ink);
    }

    // Door / window slit on the stall.
    fill.color = selected ? const Color(0xff8a4b1e) : const Color(0xff9c7044);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.42, h * 0.60, w * 0.58, h * 0.92),
        Radius.circular(w * 0.05),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(_ShopIconPainter old) => old.selected != selected;
}

/// Cat-album book with a paw print on the cover — the PISICI tab icon,
/// styled like the reference creator screen's diary/book button.
class _CatsIconPainter extends CustomPainter {
  const _CatsIconPainter({required this.selected});
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = Paint()
      ..color = selected ? const Color(0xff6b3a12) : const Color(0xff7a5335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // Page block peeking from behind the cover.
    fill.color = selected ? const Color(0xfffff3d6) : const Color(0xffe8d3ac);
    final pages = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.26, h * 0.16, w * 0.86, h * 0.88),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(pages, fill);
    canvas.drawRRect(pages, ink);

    // Cover.
    fill.color = selected ? const Color(0xffa0622d) : const Color(0xff8a5a3a);
    final cover = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.12, h * 0.10, w * 0.72, h * 0.92),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(cover, fill);
    canvas.drawRRect(cover, ink);

    // Spine stitches.
    for (var y = 0.0; y < 3; y++) {
      canvas.drawCircle(
        Offset(w * 0.21, h * (0.28 + y * 0.22)),
        w * 0.035,
        Paint()..color = const Color(0xff5c3a26),
      );
    }

    // Paw print on the cover.
    fill.color = selected ? gold : const Color(0xffe8c9a0);
    final pad = Offset(w * 0.47, h * 0.58);
    canvas.drawOval(
      Rect.fromCenter(center: pad, width: w * 0.24, height: h * 0.20),
      fill,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(w * (0.34 + i * 0.13), h * 0.40 - (i == 1 ? h * 0.05 : 0)),
        w * 0.06,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_CatsIconPainter old) => old.selected != selected;
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.title,
    required this.spriteName,
    required this.buttonText,
    required this.onPressed,
    this.subtitle,
  });
  final String title, spriteName, buttonText;
  final String? subtitle;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => panel(
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x80fff3cf), Color(0x00fff3cf)],
              ),
            ),
            child: sprite(spriteName, size: 68),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff8a6242),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 10),
        ArenaButton(text: buttonText, onPressed: onPressed, green: true),
      ],
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        label(title, size: 24),
        const SizedBox(height: 7),
        Container(
          width: 46,
          height: 5,
          decoration: BoxDecoration(
            color: gold,
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55e8a01f),
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AdaptiveCardGrid extends StatelessWidget {
  const AdaptiveCardGrid({
    super.key,
    required this.children,
    this.minWidth = 140,
    this.maxColumns = 3,
  });
  final List<Widget> children;
  final double minWidth;
  final int maxColumns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = ((constraints.maxWidth + 10) / (minWidth * scale + 10))
          .floor()
          .clamp(1, maxColumns);
      return Column(
        children: [
          for (var start = 0; start < children.length; start += columns)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < columns; col++) ...[
                      if (col > 0) const SizedBox(width: 10),
                      Expanded(
                        child: start + col < children.length
                            ? children[start + col]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class RoomBackground extends StatelessWidget {
  const RoomBackground({
    super.key,
    this.tier = 0,
    required this.child,
    this.dim = false,
  });
  final int tier;
  final Widget child;
  final bool dim;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: RepaintBoundary(child: CustomPaint(painter: RoomPainter(tier))),
      ),
      if (dim)
        const Positioned.fill(child: ColoredBox(color: Color(0x77432c33))),
      child,
    ],
  );
}

class RoomPainter extends CustomPainter {
  const RoomPainter(this.tier);
  final int tier;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wall = [
      const Color(0xffe6bc91),
      const Color(0xffdab17f),
      const Color(0xffc8d3ab),
      const Color(0xffb6a0c5),
    ][tier.clamp(0, 3)];
    final paint = Paint();
    final bounds = Offset.zero & size;
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [wall, Color.lerp(wall, const Color(0xff8e5342), 0.35)!],
    ).createShader(bounds);
    canvas.drawRect(bounds, paint);
    paint.shader = null;
    paint.shader = RadialGradient(
      center: const Alignment(0, -0.85),
      radius: 1.15,
      colors: [const Color(0x2effffdd), const Color(0x00ffffdd)],
    ).createShader(bounds);
    canvas.drawRect(bounds, paint);
    paint.shader = null;
    for (var x = 0.0; x < w; x += 34) {
      paint.color = const Color(0x12ffffff);
      canvas.drawRect(Rect.fromLTWH(x, 0, 15, h * .74), paint);
    }

    final garland = Path()
      ..moveTo(w * .04, h * .05)
      ..quadraticBezierTo(w * .5, h * .115, w * .96, h * .05);
    paint
      ..color = const Color(0xff7c4a34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(garland, paint);
    paint.style = PaintingStyle.fill;
    const flagColors = [
      Color(0xffffc63c),
      Color(0xfffff0d0),
      Color(0xffd98a5f),
      Color(0xff9dbf7a),
    ];
    for (var i = 0; i <= 14; i++) {
      final t = i / 14;
      final mt = 1 - t;
      final x = mt * mt * w * .04 + 2 * mt * t * w * .5 + t * t * w * .96;
      final y = mt * mt * h * .05 + 2 * mt * t * h * .115 + t * t * h * .05;
      paint.color = flagColors[i % flagColors.length];
      canvas.drawPath(
        Path()
          ..moveTo(x - 7, y)
          ..lineTo(x + 7, y)
          ..lineTo(x, y + 15)
          ..close(),
        paint,
      );
    }

    final clock = Offset(w * .925, h * .17);
    final clockR = w * .045;
    paint.color = const Color(0xff7c4a34);
    canvas.drawCircle(clock, clockR + 3, paint);
    paint.color = const Color(0xfffff3d0);
    canvas.drawCircle(clock, clockR, paint);
    paint
      ..color = const Color(0xff5e3a2a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(clock, clock + Offset(0, -clockR * .55), paint);
    canvas.drawLine(clock, clock + Offset(clockR * .4, clockR * .25), paint);
    paint.style = PaintingStyle.fill;

    void box(Rect rect, Color color, {double radius = 0}) {
      paint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }

    box(Rect.fromLTWH(0, h * .75, w, h * .25), const Color(0xffb77a4e));
    for (var row = 0; row < 4; row++) {
      final y = h * (.75 + row * .075);
      paint
        ..color = const Color(0x99855338)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
      for (var col = 0; col < 5; col++) {
        final x = w * (col / 4 + (row.isEven ? 0 : .12));
        canvas.drawLine(Offset(x, y), Offset(x, min(h, y + h * .075)), paint);
      }
    }
    box(Rect.fromLTWH(0, h * .735, w, 9), const Color(0xff74483b));
    final shelf = Rect.fromLTWH(w * .14, h * .10, w * .72, h * .60);
    box(shelf.inflate(5), const Color(0xff744b3c), radius: 9);
    box(shelf, const Color(0xff956344), radius: 5);
    for (var row = 0; row < 3; row++) {
      final y = h * (.15 + row * .17);
      box(Rect.fromLTWH(w * .18, y, w * .64, h * .12), const Color(0xff654536));
      for (var book = 0; book < 8; book++) {
        final x = w * (.195 + book * .075),
            height = h * (.065 + (book % 3) * .018);
        box(
          Rect.fromLTWH(x, y + h * .115 - height, w * .05, height),
          [
            const Color(0xffb67b64),
            const Color(0xff7d9b8c),
            const Color(0xffd0b26c),
            const Color(0xff8f879a),
          ][(book + row) % 4],
          radius: 2,
        );
      }
      box(
        Rect.fromLTWH(w * .17, y + h * .12, w * .66, 7),
        const Color(0xffbc8a5d),
        radius: 2,
      );
    }
    box(
      Rect.fromLTWH(w * .17, h * .65, w * .66, h * .045),
      const Color(0xffb67f54),
      radius: 3,
    );

    final potX = w * .795;
    box(
      Rect.fromLTWH(potX, h * .10, w * .055, h * .038),
      const Color(0xffb5654a),
      radius: 4,
    );
    paint.color = const Color(0xff7d9b6a);
    canvas.drawCircle(Offset(potX + w * .027, h * .088), w * .026, paint);
    canvas.drawCircle(Offset(potX + w * .006, h * .098), w * .018, paint);
    canvas.drawCircle(Offset(potX + w * .048, h * .098), w * .018, paint);
    paint.color = const Color(0xff93b57e);
    canvas.drawCircle(Offset(potX + w * .022, h * .09), w * .015, paint);

    paint.color = const Color(0xff9b5748);
    canvas.drawOval(Rect.fromLTWH(w * .04, h * .79, w * .92, h * .17), paint);
    paint
      ..color = const Color(0xffd29b62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(Rect.fromLTWH(w * .08, h * .805, w * .84, h * .13), paint);
    paint
      ..color = const Color(0x80d29b62)
      ..strokeWidth = 2.5;
    canvas.drawOval(Rect.fromLTWH(w * .14, h * .825, w * .72, h * .09), paint);
    paint.style = PaintingStyle.fill;
    for (final x in [w * .07, w * .93]) {
      box(Rect.fromLTWH(x - 2, h * .36, 4, h * .39), const Color(0xff795643));
      paint.color = const Color(0xffffd98b);
      canvas.drawPath(
        Path()
          ..moveTo(x - w * .045, h * .25)
          ..lineTo(x + w * .045, h * .25)
          ..lineTo(x + w * .08, h * .40)
          ..lineTo(x - w * .08, h * .40)
          ..close(),
        paint,
      );
      paint.color = const Color(0xff795643);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, h * .755), width: w * .12, height: 8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RoomPainter oldDelegate) => oldDelegate.tier != tier;
}
