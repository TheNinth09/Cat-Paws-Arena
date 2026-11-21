import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// VFX kinds for the Frenzy duel: the three cat powers plus the special-
/// piece detonations and the sabotage box flight.
enum CatPowerVfxType {
  zoomies, // Fiery orange-gold tornado vortex + speed trails
  shadowPounce, // Triple purple-magenta claw slashes across board
  laserChase, // High-energy crimson-gold laser beams cutting rows/columns
  rocketBlast, // Rocket line/column streak + shockwave
  bombShockwave, // Radial 3x3 star shockwave explosion
  boxFlight, // Cardboard box arcing off the board toward the rival avatar
}

class ActiveVfxEvent {
  final int id;
  final CatPowerVfxType type;
  final Offset normalizedCenter; // (0..1, 0..1) on board
  final bool horizontal;
  final double createdAtSec;
  final double durationSec;

  const ActiveVfxEvent({
    required this.id,
    required this.type,
    required this.normalizedCenter,
    this.horizontal = true,
    required this.createdAtSec,
    this.durationSec = 0.65,
  });
}

/// High-performance VFX controller for the Frenzy overlay. Holds at most
/// 8 concurrent effects; [FrenzyVfxOverlay] drives [tick] from its own
/// ticker, so no timers leak when the match screen disposes.
class FrenzyVfxController extends ChangeNotifier {
  final List<ActiveVfxEvent> _events = [];
  int _nextId = 1;
  double _clockSec = 0.0;

  List<ActiveVfxEvent> get events => List.unmodifiable(_events);
  double get clockSec => _clockSec;

  void tick(double dtSec) {
    if (_events.isEmpty) return;
    _clockSec += dtSec;
    final int before = _events.length;
    _events.removeWhere((e) => (_clockSec - e.createdAtSec) >= e.durationSec);
    if (_events.isNotEmpty || _events.length != before) {
      notifyListeners();
    }
  }

  void spawnVfx({
    required CatPowerVfxType type,
    Offset normalizedCenter = const Offset(0.5, 0.5),
    bool horizontal = true,
    double durationSec = 0.65,
  }) {
    // Cap concurrent VFX at 8 so cascades never tank the frame rate.
    if (_events.length >= 8) {
      _events.removeAt(0);
    }
    _events.add(
      ActiveVfxEvent(
        id: _nextId++,
        type: type,
        normalizedCenter: normalizedCenter,
        horizontal: horizontal,
        createdAtSec: _clockSec,
        durationSec: durationSec,
      ),
    );
    notifyListeners();
  }

  void clear() {
    _events.clear();
    notifyListeners();
  }
}

/// Non-blocking VFX layer over the 7x7 board, inside its own
/// [RepaintBoundary]: repaints a lightweight canvas of particles and
/// beams, never the board's cells. The overlay drives the controller's
/// clock from a ticker that only runs while effects are alive (or while
/// the Fever frame burns), so nothing ticks after the match ends.
class FrenzyVfxOverlay extends StatefulWidget {
  final FrenzyVfxController controller;

  /// Zoomies Fever flag — usually `match.boardSignals.fever`, so the
  /// flame frame follows the clock without rebuilding the board layer.
  final ValueListenable<bool> fever;

  const FrenzyVfxOverlay({
    super.key,
    required this.controller,
    required this.fever,
  });

  @override
  State<FrenzyVfxOverlay> createState() => _FrenzyVfxOverlayState();
}

class _FrenzyVfxOverlayState extends State<FrenzyVfxOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _last = Duration.zero;
    _ticker = createTicker(_onTick);
    widget.controller.addListener(_syncTicker);
    widget.fever.addListener(_syncTicker);
    _syncTicker();
  }

  void _syncTicker() {
    final alive = widget.controller._events.isNotEmpty || widget.fever.value;
    if (alive && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!alive && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt < 0 || dt > 0.25) dt = 0.016;
    widget.controller.tick(dt);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTicker);
    widget.fever.removeListener(_syncTicker);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.controller, widget.fever]),
          builder: (context, _) {
            return CustomPaint(
              painter: _FrenzyVfxPainter(
                events: widget.controller.events,
                clockSec: widget.controller.clockSec,
                isFeverMode: widget.fever.value,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _FrenzyVfxPainter extends CustomPainter {
  final List<ActiveVfxEvent> events;
  final double clockSec;
  final bool isFeverMode;

  _FrenzyVfxPainter({
    required this.events,
    required this.clockSec,
    required this.isFeverMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isFeverMode) {
      final rect = Offset.zero & size;
      final flicker =
          0.75 + 0.25 * math.sin(clockSec * 14.0);
      final feverBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0 + 1.5 * math.sin(clockSec * 9.0)
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFD54F).withValues(alpha: flicker),
            const Color(0xFFFF6D00).withValues(alpha: flicker),
            const Color(0xFFFF1744).withValues(alpha: flicker),
          ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(14)),
        feverBorder,
      );
    }

    for (final e in events) {
      final double t =
          ((clockSec - e.createdAtSec) / e.durationSec).clamp(0.0, 1.0);
      final double fade = (1.0 - t).clamp(0.0, 1.0);
      final center = Offset(
        e.normalizedCenter.dx * size.width,
        e.normalizedCenter.dy * size.height,
      );

      switch (e.type) {
        case CatPowerVfxType.laserChase:
          _drawLaserBeam(canvas, size, center, e.horizontal, t, fade);
        case CatPowerVfxType.shadowPounce:
          _drawClawSlashes(canvas, size, center, t, fade);
        case CatPowerVfxType.zoomies:
          _drawZoomiesVortex(canvas, size, center, t, fade);
        case CatPowerVfxType.rocketBlast:
          _drawRocketStreak(canvas, size, center, e.horizontal, t, fade);
        case CatPowerVfxType.bombShockwave:
          _drawBombShockwave(canvas, size, center, t, fade);
        case CatPowerVfxType.boxFlight:
          _drawBoxFlight(canvas, size, center, t, fade);
      }
    }
  }

  void _drawLaserBeam(Canvas canvas, Size size, Offset center, bool horizontal,
      double t, double fade) {
    final double beamWidth = (26.0 * (1.0 - t * 0.65)).clamp(4.0, 26.0);
    final outerGlow = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.75 * fade)
      ..strokeWidth = beamWidth
      ..strokeCap = StrokeCap.round;
    final innerCore = Paint()
      ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.95 * fade)
      ..strokeWidth = beamWidth * 0.38
      ..strokeCap = StrokeCap.round;

    final p1 = horizontal ? Offset(0, center.dy) : Offset(center.dx, 0);
    final p2 = horizontal
        ? Offset(size.width, center.dy)
        : Offset(center.dx, size.height);

    canvas.drawLine(p1, p2, outerGlow);
    canvas.drawLine(p1, p2, innerCore);
  }

  void _drawClawSlashes(
      Canvas canvas, Size size, Offset center, double t, double fade) {
    final double reach = size.width * 0.36 * Curves.easeOut.transform(t);
    final slashOuter = Paint()
      ..color = const Color(0xFFAA00FF).withValues(alpha: 0.85 * fade)
      ..strokeWidth = 10.0 * fade
      ..strokeCap = StrokeCap.round;
    final slashCore = Paint()
      ..color = const Color(0xFFF3E5F5).withValues(alpha: 0.95 * fade)
      ..strokeWidth = 4.0 * fade
      ..strokeCap = StrokeCap.round;

    for (int i = -1; i <= 1; i++) {
      final double offset = i * 24.0;
      final start =
          Offset(center.dx - reach + offset, center.dy - reach - offset * 0.4);
      final end =
          Offset(center.dx + reach + offset, center.dy + reach - offset * 0.4);
      canvas.drawLine(start, end, slashOuter);
      canvas.drawLine(start, end, slashCore);
    }
  }

  void _drawZoomiesVortex(
      Canvas canvas, Size size, Offset center, double t, double fade) {
    final double maxRadius = size.width * 0.42 * (0.3 + 0.7 * t);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0 * fade
      ..color = const Color(0xFFFF9100).withValues(alpha: 0.85 * fade);

    for (int i = 0; i < 3; i++) {
      final double r = maxRadius * (0.45 + i * 0.25);
      final double startAngle = t * math.pi * 4 + i * 1.4;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startAngle,
        math.pi * 1.35,
        false,
        ringPaint,
      );
    }
  }

  void _drawRocketStreak(Canvas canvas, Size size, Offset center,
      bool horizontal, double t, double fade) {
    final trail = Paint()
      ..color = const Color(0xFFFFAB00).withValues(alpha: 0.85 * fade)
      ..strokeWidth = 18.0 * fade
      ..strokeCap = StrokeCap.round;
    final a = horizontal ? Offset(0, center.dy) : Offset(center.dx, 0);
    final b = horizontal
        ? Offset(size.width * t, center.dy)
        : Offset(center.dx, size.height * t);
    canvas.drawLine(a, b, trail);
  }

  void _drawBombShockwave(
      Canvas canvas, Size size, Offset center, double t, double fade) {
    final double radius = size.width * 0.34 * Curves.easeOutCubic.transform(t);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0 * fade
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.9 * fade);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF6D00).withValues(alpha: 0.32 * fade);
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, ring);
  }

  /// The sabotage parcel: a small cardboard box arcing from the cleared
  /// cells up off the board's top edge, toward the rival's avatar.
  void _drawBoxFlight(
      Canvas canvas, Size size, Offset center, double t, double fade) {
    final double arc = Curves.easeIn.transform(t);
    final pos = Offset(
      center.dx + (size.width * 0.32 - center.dx) * arc,
      center.dy - size.height * 0.6 * arc,
    );
    final side = 16.0 * (1.0 - t * 0.4);
    final boxPaint = Paint()
      ..color = const Color(0xFFCD8A4C).withValues(alpha: 0.95 * fade);
    final tapePaint = Paint()
      ..color = const Color(0xFF8A5A2E).withValues(alpha: 0.9 * fade)
      ..strokeWidth = 2;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(t * 3.2);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: side, height: side),
      boxPaint,
    );
    canvas.drawLine(Offset(-side / 2, 0), Offset(side / 2, 0), tapePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FrenzyVfxPainter oldDelegate) => true;
}
