import 'dart:math';

import 'package:flutter/painting.dart';

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';

import 'arena.dart';

class BoardGame extends FlameGame with PanDetector, TapDetector {
  BoardGame(this.board, this.changed, this.attack, this.obstacleName);
  final MatchBoard board;
  final void Function() changed;
  final void Function() attack;
  final String obstacleName;
  final Map<String, Sprite> art = {};
  int? selected;
  bool busy = false;
  bool active = true, suspended = false;
  int? swapFrom, swapTo;
  double swapProgress = 1;
  double elapsed = 0, effect = 0;
  Set<int> clearing = {};
  double get unit => min(size.x, size.y) / 7;
  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/generated/';
    for (final name in [...MatchBoard.names, obstacleName]) {
      art[name] = await loadSprite('$name.png');
    }
  }

  int? index(Offset p) {
    final col = (p.dx / unit).floor(), row = (p.dy / unit).floor();
    return row >= 0 && row < 7 && col >= 0 && col < 7 ? row * 7 + col : null;
  }

  @override
  void onPanStart(DragStartInfo info) {
    if (!busy && active && !suspended) {
      selected = index(info.eventPosition.widget.toOffset());
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (busy || suspended || !active || selected == null) return;
    final target = index(info.eventPosition.widget.toOffset());
    if (target != null && board.adjacent(selected!, target)) {
      final from = selected!;
      selected = null;
      move(from, target);
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (busy || suspended || !active) return;
    final target = index(info.eventPosition.widget.toOffset());
    if (target == null) return;
    if (selected != null && board.adjacent(selected!, target)) {
      final from = selected!;
      selected = null;
      move(from, target);
    } else {
      selected = target;
    }
  }

  Future<void> move(int a, int b) async {
    if (!active || suspended || !board.swap(a, b)) return;
    busy = true;
    swapFrom = a;
    swapTo = b;
    swapProgress = 0;
    await step(const Duration(milliseconds: 160));
    swapFrom = swapTo = null;
    await resolve();
    busy = false;
  }

  Future<void> step(Duration duration) async {
    await Future<void>.delayed(duration);
    while (suspended && active) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> resolve() async {
    var combo = 1;
    while (active) {
      final found = board.matches();
      if (found.isEmpty) break;
      clearing = found;
      await step(const Duration(milliseconds: 180));
      if (!active) break;
      final old = board.attacks;
      board.clear(found, combo++);
      if (board.attacks > old) attack();
      clearing = {};
      board.fall();
      changed();
      await step(const Duration(milliseconds: 160));
    }
    if (active && !board.hasMove) board.reset();
  }

  Future<void> power(int kind) async {
    if (busy || suspended || !active || board.charge < 100) return;
    busy = true;
    board.charge = 0;
    effect = 1.3;
    final row = board.random.nextInt(7);
    final found = <int>{};
    for (var i = 0; i < 49; i++) {
      if (kind == 0
          ? i ~/ 7 == row
          : kind == 1
          ? i % 7 == row
          : board.cells[i] == row % 5) {
        found.add(i);
      }
    }
    board.clear(found, 1);
    board.fall();
    attack();
    changed();
    await resolve();
    busy = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (suspended) return;
    swapProgress = min(1, swapProgress + dt / 0.16);
    elapsed += dt;
    effect = max(0, effect - dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint();
    for (var i = 0; i < 49; i++) {
      final x = (i % 7) * unit, y = (i ~/ 7) * unit;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 1, y + 1, unit - 2, unit - 2),
        const Radius.circular(9),
      );
      paint.color = selected == i
          ? const Color(0xffffd66d)
          : ((i + i ~/ 7) % 2 == 0
                ? const Color(0xff754c52)
                : const Color(0xff916168));
      canvas.drawRRect(rect, paint);
      final sprite =
          art[board.cells[i] < 0
              ? obstacleName
              : MatchBoard.names[board.cells[i]]];
      final pulse = clearing.contains(i) ? 0.7 + sin(elapsed * 35) * 0.15 : 1.0;
      final inset = unit * (1 - pulse) * 0.5 + 4;
      final origin = i == swapFrom
          ? swapTo
          : i == swapTo
          ? swapFrom
          : null;
      final t = 1 - pow(1 - swapProgress, 3).toDouble();
      final dx = origin == null ? x : (origin % 7) * unit * (1 - t) + x * t;
      final dy = origin == null ? y : (origin ~/ 7) * unit * (1 - t) + y * t;
      sprite?.render(
        canvas,
        position: Vector2(dx + inset, dy + inset),
        size: Vector2.all(unit - inset * 2),
      );
    }
    if (effect > 0) {
      paint.color = const Color(0xffffcc44).withValues(alpha: effect / 3);
      canvas.drawRect(Rect.fromLTWH(0, 0, unit * 7, unit * 7), paint);
      final p = TextPainter(
        text: const TextSpan(
          text: 'ZOOM!',
          style: TextStyle(
            color: Color(0xffffffff),
            fontSize: 50,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(
        canvas,
        Offset((size.x - p.width) / 2, size.y / 2 - p.height / 2),
      );
    }
  }
}
