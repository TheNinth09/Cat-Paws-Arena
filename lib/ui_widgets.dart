import 'dart:math';

import 'package:flutter/material.dart';

const ink = Color(0xff51312d),
    cream = Color(0xffffedbb),
    gold = Color(0xffffc63c);

Widget sprite(String name, {double size = 40}) => Image.asset(
  'assets/generated/$name.png',
  width: size,
  height: size,
  fit: BoxFit.contain,
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
  });
  final Widget avatar;
  final String name;
  final int trophies, coins;
  final VoidCallback onProfile, onRoad, onShop, onMenu;

  Widget pill(
    String asset,
    String value,
    VoidCallback tap, {
    bool plus = false,
  }) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff96684c), Color(0xff75503a), Color(0xff64402f)],
      ),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0x59ffe9bd), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          offset: Offset(0, 2),
          blurRadius: 6,
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              sprite(asset, size: 24),
              const SizedBox(width: 5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: cream,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      shadows: [
                        Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
              if (plus) ...[
                const SizedBox(width: 5),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xffb9e07a),
                  ),
                  child: const Icon(Icons.add, size: 13, color: ink),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff96684c), Color(0xff6b4234)],
      ),
      border: Border(bottom: BorderSide(color: gold, width: 2)),
      boxShadow: [
        BoxShadow(
          color: Color(0x55432118),
          offset: Offset(0, 4),
          blurRadius: 12,
        ),
      ],
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xffffe9bd), Color(0xffe0b070)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x44000000),
                            offset: Offset(0, 2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: avatar,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 56,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: cream,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: pill('icon_trophy', '$trophies', onRoad)),
                const SizedBox(width: 6),
                Expanded(
                  child: pill('icon_paw_coin', '$coins', onShop, plus: true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Meniu',
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xff5e3a2a),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x59ffe9bd), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onMenu,
                  borderRadius: BorderRadius.circular(14),
                  child: const Icon(Icons.menu_rounded, color: cream, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ArenaBottomBar extends StatelessWidget {
  const ArenaBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.english = false,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final labels = english
        ? const ['SHOP', 'CATS', 'BATTLE', 'TEAM', 'EVENTS']
        : const ['MAGAZIN', 'PISICI', 'LUPTĂ', 'ECHIPĂ', 'EVENIMENTE'];
    const icons = [
      Icons.storefront,
      Icons.pets,
      Icons.sports_esports,
      Icons.shield,
      Icons.event,
    ];

    Widget navItem(int i) => Expanded(
      child: Semantics(
        button: true,
        selected: i == selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('nav-$i'),
            onTap: () => onSelected(i),
            child: SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 30,
                      width: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == i
                            ? const Color(0x2effd98b)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        icons[i],
                        size: 25,
                        color: selected == i ? gold : const Color(0xffd8b48f),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 13,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            color: selected == i
                                ? gold
                                : const Color(0xffe8c9a0),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
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
      ),
    );

    return SizedBox(
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 62,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff7c4e37), Color(0xff54342a)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: const Border(top: BorderSide(color: gold, width: 2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5520130e),
                    offset: Offset(0, -6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      if (i == 2)
                        const Expanded(child: SizedBox.shrink())
                      else
                        navItem(i),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                selected: selected == 2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('nav-2'),
                    onTap: () => onSelected(2),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xfffff6bd),
                                        gold,
                                        Color(0xffe8a01f),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xff8f5f14),
                                      width: 2.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x66ffc63c),
                                        blurRadius: 18,
                                      ),
                                      BoxShadow(
                                        color: Color(0x6620130e),
                                        offset: Offset(0, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Positioned(
                                top: 6,
                                left: 14,
                                right: 14,
                                height: 13,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x80ffffff),
                                        Color(0x00ffffff),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Center(child: sprite('btn_play_paw', size: 36)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          height: 13,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[2],
                              style: TextStyle(
                                color: selected == 2
                                    ? gold
                                    : const Color(0xffe8c9a0),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    offset: Offset(0, 1),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
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
