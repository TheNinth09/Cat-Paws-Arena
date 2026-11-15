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
        : const [Shadow(color: ink, offset: Offset(1, 2), blurRadius: 2)],
  ),
);

Widget panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(14)}) =>
    Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xfafff0cf),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 4,
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

class ArenaButton extends StatelessWidget {
  const ArenaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.green = false,
    this.spriteName,
    this.singleLine = false,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool green, singleLine;
  final String? spriteName;
  Widget caption() => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: ink,
      fontSize: 16,
      fontWeight: FontWeight.w900,
    ),
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: green
                    ? [const Color(0xffb7df68), const Color(0xff65a135)]
                    : [const Color(0xffffe882), gold, const Color(0xffefa72b)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ink, width: 2),
              image: green
                  ? const DecorationImage(
                      image: AssetImage('assets/generated/btn_green.png'),
                      fit: BoxFit.fill,
                    )
                  : null,
              boxShadow: const [
                BoxShadow(color: Color(0x4451312d), offset: Offset(0, 3)),
              ],
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (spriteName != null) ...[
                        sprite(spriteName!, size: 30),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: singleLine
                            ? FittedBox(fit: BoxFit.scaleDown, child: caption())
                            : caption(),
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
  Widget stat(
    String asset,
    String value,
    VoidCallback tap, {
    bool plus = false,
  }) => Material(
    color: const Color(0xff643e39),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Row(
          children: [
            sprite(asset, size: 27),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: cream,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            if (plus)
              const Icon(Icons.add_circle, color: Color(0xffb9df70), size: 23),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xffa97153), Color(0xff74443f)]),
      border: Border(bottom: BorderSide(color: gold, width: 2)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatar,
                  const SizedBox(height: 3),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: cream,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(child: stat('icon_trophy', '$trophies', onRoad)),
                const SizedBox(width: 6),
                Expanded(
                  child: stat('icon_paw_coin', '$coins', onShop, plus: true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Meniu',
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded, color: cream, size: 30),
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
  Widget build(BuildContext context) => Material(
    color: const Color(0xff477c96),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 5; i++)
          Expanded(
            child: Semantics(
              selected: i == selected,
              button: true,
              child: InkWell(
                key: ValueKey('nav-$i'),
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected == i
                        ? const Color(0xffa94e43)
                        : Colors.transparent,
                    border: Border(
                      top: BorderSide(
                        color: selected == i ? gold : ink,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i == 2)
                        sprite('btn_play_paw', size: 30)
                      else
                        Icon(
                          [
                            Icons.storefront,
                            Icons.pets,
                            Icons.sports_esports,
                            Icons.shield,
                            Icons.event,
                          ][i],
                          size: 30,
                          color: cream,
                        ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 20,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            (english
                                ? ['SHOP', 'CATS', 'BATTLE', 'TEAM', 'EVENTS']
                                : [
                                    'MAGAZIN',
                                    'PISICI',
                                    'LUPTĂ',
                                    'ECHIPĂ',
                                    'EVENIMENTE',
                                  ])[i],
                            style: const TextStyle(
                              color: cream,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
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
        Center(child: sprite(spriteName, size: 64)),
        const SizedBox(height: 8),
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
            padding: const EdgeInsets.only(top: 5),
            child: Text(subtitle!, textAlign: TextAlign.center),
          ),
        const SizedBox(height: 8),
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
    child: label(title, size: 25),
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
    for (var x = 0.0; x < w; x += 34) {
      paint.color = const Color(0x10ffffff);
      canvas.drawRect(Rect.fromLTWH(x, 0, 15, h * .76), paint);
    }
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
        ..color = const Color(0xff855338)
        ..strokeWidth = 2;
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
    paint.color = const Color(0xff9b5748);
    canvas.drawOval(Rect.fromLTWH(w * .04, h * .79, w * .92, h * .17), paint);
    paint
      ..color = const Color(0xffd29b62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(Rect.fromLTWH(w * .08, h * .805, w * .84, h * .13), paint);
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
