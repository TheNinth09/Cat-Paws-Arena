import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BoardVfxType {
  tilePop,
  boxBreak,
  rocketRow,
  rocketCol,
  bombShockwave,
  laserCross,
  shadowClaw,
  zoomiesBurst,
}

class BoardVfxEvent {
  final BoardVfxType type;
  final Offset normalizedPos; // (0..7, 0..7) in grid coordinates
  final Color color;
  final String? label;
  final DateTime createdAt;
  final Duration duration;

  BoardVfxEvent({
    required this.type,
    required this.normalizedPos,
    this.color = const Color(0xFFFFD54F),
    this.label,
    this.duration = const Duration(milliseconds: 520),
  }) : createdAt = DateTime.now();

  double progress(DateTime now) {
    final elapsed = now.difference(createdAt).inMilliseconds;
    return (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

class BoardVfxController extends ChangeNotifier {
  final List<BoardVfxEvent> _events = [];
  double shakeIntensity = 0.0;

  List<BoardVfxEvent> get activeEvents {
    final now = DateTime.now();
    _events.removeWhere((e) => e.progress(now) >= 1.0);
    return List.unmodifiable(_events);
  }

  void emit(BoardVfxEvent event, {double shake = 0.0}) {
    _events.add(event);
    if (shake > shakeIntensity) {
      shakeIntensity = shake;
    }
    notifyListeners();
  }

  void tick() {
    final wasActive = _events.isNotEmpty || shakeIntensity > 0.01;
    _events.removeWhere((e) => e.progress(DateTime.now()) >= 1.0);
    shakeIntensity *= 0.82;
    if (shakeIntensity < 0.05) shakeIntensity = 0.0;
    final stillActive = _events.isNotEmpty || shakeIntensity > 0.01;
    // Notify while effects run and exactly once when they drain, so the
    // overlay can stop its ticker instead of repainting forever.
    if (wasActive || stillActive) notifyListeners();
  }
}

/// 60 FPS Non-Blocking VFX Layer rendered directly over the 7x7 Match-3 board.
class BoardVfxOverlay extends StatefulWidget {
  final BoardVfxController controller;
  final int gridSize;

  const BoardVfxOverlay({
    super.key,
    required this.controller,
    this.gridSize = 7,
  });

  @override
  State<BoardVfxOverlay> createState() => _BoardVfxOverlayState();
}

class _BoardVfxOverlayState extends State<BoardVfxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        widget.controller.tick();
      });
    // The ticker only runs while effects are active — idle frames must
    // not repaint the board overlay.
    widget.controller.addListener(_syncTicker);
    _syncTicker();
  }

  void _syncTicker() {
    final busy =
        widget.controller.activeEvents.isNotEmpty ||
        widget.controller.shakeIntensity > 0.01;
    if (busy && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!busy && _ticker.isAnimating) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTicker);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final events = widget.controller.activeEvents;
          return CustomPaint(
            size: Size.infinite,
            painter: _BoardVfxPainter(
              events: events,
              gridSize: widget.gridSize,
              now: DateTime.now(),
            ),
          );
        },
      ),
    );
  }
}

class _BoardVfxPainter extends CustomPainter {
  final List<BoardVfxEvent> events;
  final int gridSize;
  final DateTime now;

  _BoardVfxPainter({
    required this.events,
    required this.gridSize,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (events.isEmpty) return;
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    for (final e in events) {
      final t = e.progress(now);
      final ease = Curves.easeOutCubic.transform(t);
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final cx = (e.normalizedPos.dx + 0.5) * cellW;
      final cy = (e.normalizedPos.dy + 0.5) * cellH;
      final center = Offset(cx, cy);

      switch (e.type) {
        case BoardVfxType.tilePop:
        case BoardVfxType.boxBreak:
          final count = e.type == BoardVfxType.boxBreak ? 10 : 8;
          for (int i = 0; i < count; i++) {
            final angle = (2 * math.pi * i) / count + (i * 0.3);
            final dist = cellW * (0.2 + 0.85 * ease);
            final p = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
            final paint = Paint()
              ..color = e.color.withValues(alpha: alpha)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(p, cellW * 0.11 * (1.0 - 0.5 * t), paint);
          }
          break;

        case BoardVfxType.bombShockwave:
        case BoardVfxType.zoomiesBurst:
          final radius = cellW * (0.5 + 2.4 * ease);
          final ringPaint = Paint()
            ..color = e.color.withValues(alpha: alpha * 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.0 * (1.0 - t) + 1.5;
          canvas.drawCircle(center, radius, ringPaint);
          break;

        case BoardVfxType.rocketRow:
          final beamPaint = Paint()
            ..color = e.color.withValues(alpha: alpha * 0.9)
            ..strokeWidth = cellH * 0.42 * (1.0 - 0.4 * t)
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(0, cy), Offset(size.width, cy), beamPaint);
          break;

        case BoardVfxType.rocketCol:
          final beamPaint = Paint()
            ..color = e.color.withValues(alpha: alpha * 0.9)
            ..strokeWidth = cellW * 0.42 * (1.0 - 0.4 * t)
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), beamPaint);
          break;

        case BoardVfxType.laserCross:
          final outer = Paint()
            ..color = const Color(0xFFFF1744).withValues(alpha: alpha * 0.85)
            ..strokeWidth = cellW * 0.46 * (1.0 - 0.35 * t);
          final core = Paint()
            ..color = Colors.white.withValues(alpha: alpha)
            ..strokeWidth = cellW * 0.16 * (1.0 - 0.35 * t);
          canvas.drawLine(Offset(0, cy), Offset(size.width, cy), outer);
          canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), outer);
          canvas.drawLine(Offset(0, cy), Offset(size.width, cy), core);
          canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), core);
          break;

        case BoardVfxType.shadowClaw:
          final clawPaint = Paint()
            ..color = const Color(0xFFD500F9).withValues(alpha: alpha * 0.9)
            ..strokeWidth = 5.0 * (1.0 - 0.3 * t)
            ..strokeCap = StrokeCap.round;
          for (int s = -1; s <= 1; s++) {
            final shift = s * cellW * 0.38;
            final p1 = center + Offset(-cellW * 1.1 + shift, -cellH * 1.1);
            final p2 = p1 + Offset(cellW * 2.2 * ease, cellH * 2.2 * ease);
            canvas.drawLine(p1, p2, clawPaint);
          }
          break;
      }

      if (e.label != null && e.label!.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: e.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: alpha),
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: alpha * 0.85),
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(cx - tp.width / 2, cy - tp.height / 2 - cellH * 0.55 * ease),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardVfxPainter oldDelegate) => true;
}
