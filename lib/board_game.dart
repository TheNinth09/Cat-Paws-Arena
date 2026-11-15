import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'duel_events.dart';

/// Tile sprite names indexed by [BoardPiece.kind]; extra kinds fall back to a
/// procedural gem until more tile art exists.
const _tileNames = [
  'tile_star',
  'tile_fish',
  'tile_mouse',
  'tile_yarn',
  'tile_paw',
];

const _obstacleNames = {
  ObstacleKind.cardboardBox: 'obs_cardboard_box',
  ObstacleKind.slipper: 'obs_slipper',
  ObstacleKind.tangledYarn: 'obs_tangled_yarn',
};

const _gemColors = [
  Color(0xffff8fb3),
  Color(0xff7ec8ff),
  Color(0xff8be08b),
  Color(0xffffd166),
  Color(0xffc39bff),
  Color(0xffff9d76),
];

const _bannerGold = Color(0xffffd166);
const _mutedBanner = Color(0xffd8b48f);

/// Presentation-only board. It renders a [BoardSnapshot] and animates the
/// contract event list from `docs/contract.md`; it contains no game rules —
/// all timing lives in the view's ticker, never in rule code.
///
/// Events mutate the logical grid the moment [BoardViewState.play] folds
/// them, so the final board state is available before the animations end.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.initial,
    this.onSwapAttempt,
    this.onEvent,
    this.onIdle,
    this.inputEnabled = true,
    this.active = true,
    this.suspended = false,
  });

  /// Initial board contents (row-major, zero-based cell indices).
  final BoardSnapshot initial;

  /// Called when the player attempts an adjacent swap. The parent decides
  /// legality and replies with events (e.g. `Swapped`/`SwapRejected`).
  final void Function(int from, int to)? onSwapAttempt;

  /// Called as each event's animation starts (sound/haptic hooks).
  final void Function(BoardEvent event)? onEvent;

  /// Called when the event queue and all animations have drained.
  final VoidCallback? onIdle;

  /// Gates touch input; the view also ignores input while animating.
  final bool inputEnabled;

  /// False stops all animation (match over); visuals snap to final state.
  final bool active;

  /// True freezes animation time (pause/background/modal).
  final bool suspended;

  @override
  State<BoardView> createState() => BoardViewState();
}

class BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late List<BoardCell> _cells;
  final List<_Fx> _fx = [];
  final List<({double at, BoardEvent event})> _meta = [];
  final List<_Banner> _banners = [];
  final List<Completer<void>> _completers = [];
  final Map<String, ui.Image> _art = {};
  late final Ticker _ticker = createTicker(_onTick);

  int? _selected;
  int? _downCell;
  int? _dragFrom;
  double _now = 0;
  double _schedule = 0;
  Duration _lastElapsed = Duration.zero;
  bool _artRequested = false;

  int get width => widget.initial.width;
  int get height => widget.initial.height;

  /// Logical board contents; final as soon as [play] returns.
  List<BoardCell> get cells => List.unmodifiable(_cells);

  /// True while events or animations are still in flight.
  bool get busy => _fx.isNotEmpty || _meta.isNotEmpty || _schedule > _now;

  /// Live cell-effect count; used by tests to prove an event animated.
  int get debugFxCount => _fx.length;

  /// Live meta-banner count; used by tests to prove a meta event animated.
  int get debugBannerCount => _banners.length;

  void _resetCells() {
    final src = widget.initial.cells;
    _cells = List.generate(
      width * height,
      (i) => i < src.length ? src[i] : const BoardCell(),
    );
  }

  @override
  void initState() {
    super.initState();
    _resetCells();
    _loadArt();
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.initial, oldWidget.initial)) {
      _resetCells();
      _fx.clear();
      _meta.clear();
      _banners.clear();
      _selected = null;
    }
    if (widget.suspended != oldWidget.suspended) {
      if (widget.suspended) {
        _ticker.stop();
      } else {
        _ensureTicker();
      }
    }
    if (!widget.active && oldWidget.active) _finishAll();
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.onIdle?.call();
    for (final c in _completers) {
      if (!c.isCompleted) c.complete();
    }
    super.dispose();
  }

  Future<void> _loadArt() async {
    if (_artRequested) return;
    _artRequested = true;
    final names = {..._tileNames, ..._obstacleNames.values};
    await Future.wait(names.map(_loadSprite));
    if (mounted) setState(() {});
  }

  Future<void> _loadSprite(String name) async {
    try {
      final data = await rootBundle.load('assets/generated/$name.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      _art[name] = frame.image;
    } on Object {
      // Missing art renders as a colored gem; never block the board.
    }
  }

  /// Folds [events] into the logical grid immediately and schedules their
  /// animations. The returned future completes when everything has played.
  Future<void> play(List<BoardEvent> events) {
    if (events.isEmpty) return Future<void>.value();
    if (!widget.active) {
      // Match is over: keep the grid truthful, skip animation work.
      final fxCount = _fx.length;
      final metaCount = _meta.length;
      for (final e in events) {
        _fold(e);
      }
      _fx.removeRange(fxCount, _fx.length);
      _meta.removeRange(metaCount, _meta.length);
      return Future<void>.value();
    }
    final done = Completer<void>();
    _completers.add(done);
    _schedule = math.max(_schedule, _now);
    for (final e in events) {
      _fold(e);
    }
    if (!widget.suspended) _ensureTicker();
    return done.future;
  }

  void _fold(BoardEvent event) {
    final start = _schedule;
    _schedule += _slotFor(event);
    final fx = _apply(event, start);
    if (fx.isEmpty) {
      _meta.add((at: start, event: event));
    } else {
      // One event = one onEvent callback, fired as its first fx starts.
      for (var i = 1; i < fx.length; i++) {
        fx[i].fired = true;
      }
      _fx.addAll(fx);
    }
  }

  /// Logical mutation + animation specs for one event. Grid changes happen
  /// here, synchronously, so [cells] is always the post-event state.
  List<_Fx> _apply(BoardEvent event, double start) {
    switch (event) {
      case Swapped(:final firstCell, :final secondCell):
        final a = _cells[firstCell];
        final b = _cells[secondCell];
        _cells[firstCell] = b;
        _cells[secondCell] = a;
        return [
          if (a.piece != null || a.obstacle != null)
            _moveFx(
              event,
              kind: _FxKind.swap,
              piece: a.piece,
              obstacle: a.obstacle,
              from: firstCell,
              to: secondCell,
              start: start,
              dur: 0.15,
            ),
          if (b.piece != null || b.obstacle != null)
            _moveFx(
              event,
              kind: _FxKind.swap,
              piece: b.piece,
              obstacle: b.obstacle,
              from: secondCell,
              to: firstCell,
              start: start,
              dur: 0.15,
            ),
        ];
      case SwapRejected(:final firstCell, :final secondCell):
        final a = _cells[firstCell];
        final b = _cells[secondCell];
        return [
          if (a.piece != null || a.obstacle != null)
            _staticFx(
              event,
              _FxKind.shake,
              firstCell,
              piece: a.piece,
              obstacle: a.obstacle,
              start: start,
              dur: 0.26,
            ),
          if (b.piece != null || b.obstacle != null)
            _staticFx(
              event,
              _FxKind.shake,
              secondCell,
              piece: b.piece,
              obstacle: b.obstacle,
              start: start,
              dur: 0.26,
            ),
        ];
      case Cleared(:final cells):
        return _popCells(event, cells, start, 0.18);
      case SpecialCreated(:final cell, :final kind):
        final c = _cells[cell];
        final upgraded = c.piece?.withSpecial(kind);
        if (upgraded != null) {
          _cells[cell] = BoardCell(piece: upgraded, obstacle: c.obstacle);
        }
        return [
          _staticFx(
            event,
            _FxKind.sparkle,
            cell,
            piece: upgraded ?? c.piece,
            obstacle: c.obstacle,
            start: start,
            dur: 0.3,
          ),
        ];
      case SpecialFired(:final cells):
        return _popCells(event, cells, start, 0.24);
      case PowerFired(:final cells):
        return _popCells(event, cells, start, 0.26);
      case Fell(:final from, :final to):
        final content = _cells[from];
        if (content.isEmpty) return const [];
        _cells[from] = const BoardCell();
        _cells[to] = content;
        return [
          _moveFx(
            event,
            kind: _FxKind.fall,
            piece: content.piece,
            obstacle: content.obstacle,
            from: from,
            to: to,
            start: start,
            dur: 0.2,
            squash: true,
          ),
        ];
      case Refilled(:final cell, :final piece):
        final c = _cells[cell];
        _cells[cell] = BoardCell(piece: piece, obstacle: c.obstacle);
        return [
          _moveFx(
            event,
            kind: _FxKind.refill,
            piece: piece,
            from: cell,
            to: cell,
            start: start,
            dur: 0.24,
            delay: _refillDelay(cell, start),
            squash: true,
          ),
        ];
      case ObstacleLanded(:final cells, :final obstacle):
        final out = <_Fx>[];
        for (var i = 0; i < cells.length; i++) {
          final idx = cells[i];
          final c = _cells[idx];
          if (c.piece != null) {
            out.add(
              _staticFx(
                event,
                _FxKind.poof,
                idx,
                piece: c.piece,
                start: start + i * 0.02,
                dur: 0.14,
              ),
            );
          }
          _cells[idx] = BoardCell(obstacle: obstacle);
          out.add(
            _staticFx(
              event,
              _FxKind.obstacleIn,
              idx,
              obstacle: obstacle,
              start: start + i * 0.02,
              dur: 0.22,
            ),
          );
        }
        return out;
      case ObstacleBroken(:final cells):
        final out = <_Fx>[];
        for (var i = 0; i < cells.length; i++) {
          final idx = cells[i];
          final c = _cells[idx];
          if (c.obstacle == null) continue;
          out.add(
            _staticFx(
              event,
              _FxKind.obstacleBreak,
              idx,
              obstacle: c.obstacle,
              start: start + i * 0.02,
              dur: 0.2,
            ),
          );
          _cells[idx] = BoardCell(piece: c.piece);
        }
        return out;
      case Shuffled(:final cells, :final pieces):
        return _shuffle(event, cells, pieces, start);
      case ObstacleQueued() ||
          PowerCharged() ||
          ExtraMove() ||
          RoundEnded() ||
          MatchEnded():
        return const [];
    }
  }

  List<_Fx> _popCells(
    BoardEvent event,
    List<int> cells,
    double start,
    double dur,
  ) {
    final out = <_Fx>[];
    for (var i = 0; i < cells.length; i++) {
      final idx = cells[i];
      final c = _cells[idx];
      if (c.piece != null) {
        out.add(
          _staticFx(
            event,
            _FxKind.pop,
            idx,
            piece: c.piece,
            obstacle: c.obstacle,
            start: start + i * 0.018,
            dur: dur,
          ),
        );
      }
      _cells[idx] = BoardCell(obstacle: c.obstacle);
    }
    return out;
  }

  List<_Fx> _shuffle(
    BoardEvent event,
    List<int> cells,
    Map<int, BoardPiece> pieces,
    double start,
  ) {
    final location = <int, int>{};
    for (var i = 0; i < _cells.length; i++) {
      final p = _cells[i].piece;
      if (p != null) location[p.id] = i;
    }
    final kept = pieces.values.map((p) => p.id).toSet();
    final out = <_Fx>[];
    var i = 0;
    // Pieces leaving the board entirely poof out at their old cell.
    for (final idx in cells) {
      final old = _cells[idx].piece;
      if (old != null && !kept.contains(old.id)) {
        out.add(
          _staticFx(
            event,
            _FxKind.poof,
            idx,
            piece: old,
            start: start + i * 0.02,
            dur: 0.2,
          ),
        );
        i++;
      }
    }
    // Pieces that moved slide to their new cells; new ids materialize.
    for (final entry in pieces.entries) {
      final target = entry.key;
      final piece = entry.value;
      final from = location[piece.id];
      if (from != null && from != target) {
        out.add(
          _moveFx(
            event,
            kind: _FxKind.shuffle,
            piece: piece,
            from: from,
            to: target,
            start: start + i * 0.02,
            dur: 0.4,
            delay: i * 0.012,
          ),
        );
      } else if (from == null) {
        out.add(
          _moveFx(
            event,
            kind: _FxKind.shuffle,
            piece: piece,
            from: target,
            to: target,
            start: start + i * 0.02,
            dur: 0.3,
            delay: i * 0.012,
          ),
        );
      }
      i++;
    }
    for (final idx in cells) {
      _cells[idx] = BoardCell(piece: pieces[idx], obstacle: _cells[idx].obstacle);
    }
    for (final entry in pieces.entries) {
      if (!cells.contains(entry.key)) {
        final c = _cells[entry.key];
        _cells[entry.key] = BoardCell(
          piece: entry.value,
          obstacle: c.obstacle,
        );
      }
    }
    return out;
  }

  /// New pieces wait for same-column falls to land before dropping in.
  double _refillDelay(int cell, double start) {
    final col = cell % width;
    var until = 0.0;
    for (final f in _fx) {
      if (f.kind == _FxKind.fall &&
          f.toCell != null &&
          f.toCell! % width == col) {
        until = math.max(until, f.fireAt + f.dur);
      }
    }
    return math.max(0.0, until - 0.04 - start);
  }

  _Fx _moveFx(
    BoardEvent event, {
    required _FxKind kind,
    required int from,
    required int to,
    required double start,
    required double dur,
    BoardPiece? piece,
    ObstacleKind? obstacle,
    double delay = 0,
    bool squash = false,
  }) => _Fx.move(
    event: event,
    kind: kind,
    piece: piece,
    obstacle: obstacle,
    fromCell: from,
    toCell: to,
    start: start,
    dur: dur,
    delay: delay,
    squash: squash,
    width: width,
  );

  _Fx _staticFx(
    BoardEvent event,
    _FxKind kind,
    int cell, {
    required double start,
    required double dur,
    BoardPiece? piece,
    ObstacleKind? obstacle,
  }) => _Fx.staticAt(
    event: event,
    kind: kind,
    piece: piece,
    obstacle: obstacle,
    cell: cell,
    start: start,
    dur: dur,
    width: width,
  );

  double _slotFor(BoardEvent event) => switch (event) {
    Swapped() => 0.14,
    SwapRejected() => 0.26,
    Cleared() => 0.1,
    SpecialCreated() => 0.12,
    SpecialFired() => 0.12,
    PowerFired() => 0.14,
    Fell() => 0.085,
    Refilled() => 0.085,
    ObstacleLanded() => 0.12,
    ObstacleBroken() => 0.12,
    Shuffled() => 0.34,
    _ => 0.03,
  };

  void _ensureTicker() {
    if (_ticker.isActive ||
        (_fx.isEmpty && _meta.isEmpty && _banners.isEmpty)) {
      return;
    }
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (elapsed < _lastElapsed) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    // Ignore implausible jumps (app resume, test fast-forward) so suspend
    // freezes animation time instead of skipping it.
    if (dt > 0 && dt < 0.3) _now += dt;
    var dirty = false;
    for (final f in _fx) {
      if (!f.fired && _now >= f.fireAt) {
        f.fired = true;
        widget.onEvent?.call(f.event);
        dirty = true;
      }
    }
    _meta.removeWhere((m) {
      if (_now >= m.at) {
        widget.onEvent?.call(m.event);
        _banners.add(_Banner(m.event, _now));
        dirty = true;
        return true;
      }
      return false;
    });
    _banners.removeWhere((b) => _now >= b.start + _Banner.dur);
    _fx.removeWhere((f) => f.done(_now));
    if (_fx.isEmpty &&
        _meta.isEmpty &&
        _banners.isEmpty &&
        _schedule <= _now) {
      _ticker.stop();
      widget.onIdle?.call();
      for (final c in _completers) {
        if (!c.isCompleted) c.complete();
      }
      _completers.clear();
    }
    if (dirty || _fx.isNotEmpty || _meta.isNotEmpty) setState(() {});
  }

  void _finishAll() {
    _ticker.stop();
    _fx.clear();
    _meta.clear();
    _banners.clear();
    _selected = null;
    widget.onIdle?.call();
    for (final c in _completers) {
      if (!c.isCompleted) c.complete();
    }
    _completers.clear();
    if (mounted) setState(() {});
  }

  // --- input -----------------------------------------------------------

  int? _cellAt(Offset local, double cell) {
    final col = (local.dx / cell).floor();
    final row = (local.dy / cell).floor();
    if (row < 0 || row >= height || col < 0 || col >= width) return null;
    return row * width + col;
  }

  bool _adjacent(int a, int b) =>
      a >= 0 &&
      b >= 0 &&
      a < _cells.length &&
      b < _cells.length &&
      ((a ~/ width == b ~/ width && (a - b).abs() == 1) ||
          (a - b).abs() == width);

  void _attempt(int from, int to) {
    _selected = null;
    _downCell = null;
    _dragFrom = null;
    setState(() {});
    widget.onSwapAttempt?.call(from, to);
  }

  void _onTapUp(TapUpDetails details, double cell) {
    final target = _cellAt(details.localPosition, cell);
    if (target == null || !widget.inputEnabled || busy) return;
    final sel = _selected;
    if (sel != null && _adjacent(sel, target) && sel != target) {
      _attempt(sel, target);
    } else {
      setState(() => _selected = target == _selected ? null : target);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, double cell) {
    if (!widget.inputEnabled || busy) return;
    _dragFrom ??= _downCell;
    final from = _dragFrom;
    if (from == null) return;
    final target = _cellAt(details.localPosition, cell);
    if (target != null && _adjacent(from, target)) _attempt(from, target);
  }

  // --- meta-event banners ----------------------------------------------

  /// Floating label for events that have no board-cell animation
  /// (ObstacleQueued, PowerCharged, ExtraMove, RoundEnded, MatchEnded).
  Widget _bannerLayer(double cell) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        for (final b in _banners)
          Positioned(
            left: 0,
            right: 0,
            top: cell * height * 0.3,
            child: Center(child: _bannerContent(b)),
          ),
      ],
    );
  }

  Widget _bannerContent(_Banner b) {
    final t = ((_now - b.start) / _Banner.dur).clamp(0.0, 1.0);
    final opacity =
        (t / 0.12).clamp(0.0, 1.0) * ((1 - t) / 0.3).clamp(0.0, 1.0);
    final (text, color, size) = switch (b.event) {
      ObstacleQueued(:final count) => (
        count == 1
            ? '1 obstacol următor!'
            : '$count obstacole următoare!',
        const Color(0xffffb066),
        15.0,
      ),
      PowerCharged(:final amount) => amount >= 100
          ? ('ENERGIE MAXIMĂ!', _bannerGold, 17.0)
          : ('Energie $amount%', _bannerGold, 13.0),
      ExtraMove() => ('MUTARE EXTRA!', const Color(0xffb9e07a), 18.0),
      RoundEnded(:final round, :final scores) => (
        'Runda ${round + 1}  •  ${scores.first} – ${scores.second}',
        _mutedBanner,
        15.0,
      ),
      MatchEnded(:final outcome) => (
        switch (outcome) {
          MatchOutcome.firstWin => 'VICTORIE!',
          MatchOutcome.secondWin => 'ÎNFRÂNGERE',
          MatchOutcome.draw => 'EGALITATE',
        },
        _bannerGold,
        22.0,
      ),
      _ => ('', _bannerGold, 12.0),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, -16 * t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xdd3a2418),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.65), width: 1.4),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Color(0x66000000), offset: Offset(0, 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = constraints.biggest.shortestSide;
      final cell = side / math.max(width, height);
      return Center(
        child: SizedBox(
          width: cell * width,
          height: cell * height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _downCell = _cellAt(d.localPosition, cell),
            onTapUp: (d) => _onTapUp(d, cell),
            onPanStart: (_) {},
            onPanUpdate: (d) => _onPanUpdate(d, cell),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _BoardPainter(
                    cells: _cells,
                    fx: _fx,
                    now: _now,
                    art: _art,
                    selected: _selected,
                    width: width,
                    height: height,
                  ),
                ),
                IgnorePointer(child: _bannerLayer(cell)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Animation kinds; each maps to a distinct motion in the painter.
enum _FxKind {
  swap,
  shake,
  pop,
  sparkle,
  fall,
  refill,
  obstacleIn,
  obstacleBreak,
  shuffle,
  poof,
}

class _Fx {
  _Fx._({
    required this.event,
    required this.kind,
    required this.start,
    required this.dur,
    required this.width,
    this.piece,
    this.obstacle,
    this.fromCell,
    this.toCell,
    this.cell,
    this.delay = 0,
    this.squash = false,
  });

  factory _Fx.move({
    required BoardEvent event,
    required _FxKind kind,
    required int fromCell,
    required int toCell,
    required double start,
    required double dur,
    required int width,
    BoardPiece? piece,
    ObstacleKind? obstacle,
    double delay = 0,
    bool squash = false,
  }) => _Fx._(
    event: event,
    kind: kind,
    start: start,
    dur: dur,
    width: width,
    piece: piece,
    obstacle: obstacle,
    fromCell: fromCell,
    toCell: toCell,
    delay: delay,
    squash: squash,
  );

  factory _Fx.staticAt({
    required BoardEvent event,
    required _FxKind kind,
    required int cell,
    required double start,
    required double dur,
    required int width,
    BoardPiece? piece,
    ObstacleKind? obstacle,
  }) => _Fx._(
    event: event,
    kind: kind,
    start: start,
    dur: dur,
    width: width,
    piece: piece,
    obstacle: obstacle,
    cell: cell,
  );

  final BoardEvent event;
  final _FxKind kind;
  final double start;
  final double dur;
  final int width;
  final BoardPiece? piece;
  final ObstacleKind? obstacle;
  final int? fromCell;
  final int? toCell;
  final int? cell;
  final double delay;
  final bool squash;
  bool fired = false;
  double _squashT = -1;

  double get fireAt => start + delay;

  double _t(double now) => ((now - fireAt) / dur).clamp(0.0, 1.0);

  bool done(double now) {
    if (_t(now) < 1) return false;
    if (!squash) return true;
    if (_squashT < 0) _squashT = 0;
    _squashT = ((now - fireAt - dur) / 0.12).clamp(0.0, 1.0);
    return _squashT >= 1;
  }

  /// Landing squash factor (1 = normal, dips then recovers).
  double get squashScaleY {
    if (_squashT < 0 || _squashT >= 1) return 1;
    return 1 - 0.24 * math.sin(math.pi * _squashT);
  }

  /// Current position in fractional cell units (col, row).
  (double, double) pos(double now) {
    final t = _curve(_t(now));
    if (fromCell == null || toCell == null) {
      final c = cell ?? 0;
      return (c % width + 0.5, c ~/ width + 0.5);
    }
    final fc = fromCell!, tc = toCell!;
    final fx = fc % width + 0.5, fy = fc ~/ width + 0.5;
    final tx = tc % width + 0.5, ty = tc ~/ width + 0.5;
    var x = fx + (tx - fx) * t;
    var y = fy + (ty - fy) * t;
    if (kind == _FxKind.shuffle && t > 0 && t < 1) {
      y -= math.sin(math.pi * t) * 0.45;
    }
    if (kind == _FxKind.refill) {
      // Spawn above the board top in the same column, then drop in.
      final spawnY = -0.9 - delay * 1.5;
      y = spawnY + (ty - spawnY) * _curve(_t(now));
    }
    return (x, y);
  }

  double _curve(double t) => switch (kind) {
    _FxKind.fall || _FxKind.refill => t * t,
    _FxKind.swap =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2,
    _FxKind.shuffle => 0.5 - 0.5 * math.cos(math.pi * t),
    _ => t,
  };
}

/// A transient floating label for meta events (no cell animation).
class _Banner {
  const _Banner(this.event, this.start);
  final BoardEvent event;
  final double start;
  static const dur = 0.95;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.cells,
    required this.fx,
    required this.now,
    required this.art,
    required this.selected,
    required this.width,
    required this.height,
  });

  final List<BoardCell> cells;
  final List<_Fx> fx;
  final double now;
  final Map<String, ui.Image> art;
  final int? selected;
  final int width;
  final int height;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.shortestSide / math.max(width, height);
    final boardW = cell * width;
    final boardH = cell * height;
    final ox = (size.width - boardW) / 2;
    final oy = (size.height - boardH) / 2;

    // Pieces/obstacles with an in-flight fx are drawn by the fx, not the grid.
    final fxPieceIds = <int>{};
    final fxObstacleCells = <int>{};
    for (final f in fx) {
      if (f.piece != null) fxPieceIds.add(f.piece!.id);
      final c = f.cell ?? f.toCell;
      if (f.obstacle != null && c != null) fxObstacleCells.add(c);
    }

    final bg = Paint();
    for (var i = 0; i < cells.length; i++) {
      final col = i % width, row = i ~/ width;
      final x = ox + col * cell, y = oy + row * cell;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 1.5, y + 1.5, cell - 3, cell - 3),
        Radius.circular(cell * 0.18),
      );
      bg.color = i == selected
          ? const Color(0xffffd66d)
          : ((row + col) % 2 == 0
                ? const Color(0xff754c52)
                : const Color(0xff916168));
      canvas.drawRRect(rrect, bg);
    }

    void drawPiece(
      BoardPiece piece,
      double cx,
      double cy,
      double scale,
      double alpha,
    ) {
      if (alpha <= 0) return;
      final s = cell * 0.84 * scale;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: s,
        height: s,
      );
      canvas.save();
      canvas.translate(cx, cy);
      if (piece.special == SpecialKind.rainbow) {
        canvas.rotate(now * 1.4);
      }
      canvas.translate(-cx, -cy);
      final img = art[_tileNames[piece.kind % _tileNames.length]];
      final imagePaint = Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(
          const Color(0xffffffff).withValues(alpha: alpha),
          BlendMode.modulate,
        );
      if (img != null) {
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          rect,
          imagePaint,
        );
      } else {
        _drawGem(canvas, rect, piece.kind, alpha);
      }
      if (piece.special != SpecialKind.none) {
        _drawSpecialBadge(canvas, rect, piece.special, alpha);
      }
      canvas.restore();
    }

    void drawObstacle(
      ObstacleKind kind,
      double cx,
      double cy,
      double scale,
      double alpha,
    ) {
      if (alpha <= 0) return;
      final s = cell * 0.82 * scale;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: s,
        height: s,
      );
      final img = art[_obstacleNames[kind]];
      if (img != null) {
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          rect,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..colorFilter = ColorFilter.mode(
              const Color(0xffffffff).withValues(alpha: alpha),
              BlendMode.modulate,
            ),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.16)),
          Paint()
            ..color = const Color(0xff8a6242).withValues(
              alpha: 0.9 * alpha,
            ),
        );
      }
    }

    // Static grid contents.
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      final px = ox + (i % width + 0.5) * cell;
      final py = oy + (i ~/ width + 0.5) * cell;
      if (c.piece != null && !fxPieceIds.contains(c.piece!.id)) {
        drawPiece(c.piece!, px, py, 1, 1);
      }
      if (c.obstacle != null && !fxObstacleCells.contains(i)) {
        drawObstacle(c.obstacle!, px, py, 1, 1);
      }
    }

    // Animated fx on top, ordered by board row for cheap depth.
    final ordered = [...fx]..sort(
      (a, b) => a.pos(now).$2.compareTo(b.pos(now).$2),
    );
    for (final f in ordered) {
      _paintFx(canvas, f, ox, oy, cell, drawPiece, drawObstacle);
    }
  }

  void _paintFx(
    Canvas canvas,
    _Fx f,
    double ox,
    double oy,
    double cell,
    void Function(BoardPiece, double, double, double, double) drawPiece,
    void Function(ObstacleKind, double, double, double, double) drawObstacle,
  ) {
    final t = f._t(now);
    final (col, row) = f.pos(now);
    final cx = ox + col * cell;
    final cy = oy + row * cell;

    var scale = 1.0, alpha = 1.0, dx = 0.0;
    switch (f.kind) {
      case _FxKind.pop:
        scale = 1 + 0.38 * t;
        alpha = 1 - t;
      case _FxKind.poof:
      case _FxKind.obstacleBreak:
        scale = 1 - 0.45 * t;
        alpha = 1 - t;
        if (f.kind == _FxKind.obstacleBreak) {
          dx = math.sin(t * math.pi * 5) * cell * 0.04;
        }
      case _FxKind.shake:
        dx = math.sin(t * math.pi * 4) * cell * 0.09 * (1 - t);
      case _FxKind.sparkle:
        scale = 1 + 0.18 * math.sin(math.pi * t);
        alpha = 1 - t * 0.4;
        canvas.drawCircle(
          Offset(cx, cy),
          cell * (0.45 + 0.55 * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xfffff3c4).withValues(
              alpha: (1 - t) * 0.9,
            ),
        );
      case _FxKind.obstacleIn:
        scale = _backOut(t);
      case _FxKind.refill:
        alpha = t < 0.15 ? t / 0.15 : 1;
      case _FxKind.fall || _FxKind.swap || _FxKind.shuffle:
        break;
    }

    canvas.save();
    canvas.translate(cx + dx, cy);
    if (f.squash && f.squashScaleY != 1) {
      // Landing squash: compress Y, widen X slightly to keep volume.
      final sy = scale * f.squashScaleY;
      canvas.scale(scale / math.sqrt(f.squashScaleY), sy);
    } else {
      canvas.scale(scale, scale);
    }
    if (f.piece != null) {
      drawPiece(f.piece!, 0, 0, 1, alpha);
    }
    if (f.obstacle != null) {
      drawObstacle(f.obstacle!, 0, 0, 1, alpha);
    }
    canvas.restore();
  }

  double _backOut(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }

  void _drawGem(Canvas canvas, Rect rect, int kind, double alpha) {
    final color = _gemColors[kind % _gemColors.length];
    canvas.drawOval(
      rect.deflate(rect.width * 0.12),
      Paint()..color = color.withValues(alpha: color.a * alpha),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          rect.center.dx - rect.width * 0.12,
          rect.center.dy - rect.height * 0.14,
        ),
        width: rect.width * 0.3,
        height: rect.height * 0.18,
      ),
      Paint()
        ..color = const Color(0xffffffff).withValues(alpha: 0.5 * alpha),
    );
  }

  void _drawSpecialBadge(
    Canvas canvas,
    Rect rect,
    SpecialKind kind,
    double alpha,
  ) {
    final base = switch (kind) {
      SpecialKind.lineHorizontal || SpecialKind.lineVertical =>
        const Color(0xfffff3c4),
      SpecialKind.bomb => const Color(0xff4a2c2c),
      SpecialKind.rainbow => const Color(0xff7ec8ff),
      SpecialKind.none => null,
    };
    if (base == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = base.withValues(alpha: base.a * alpha),
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.now != now ||
      old.cells != cells ||
      old.fx.length != fx.length ||
      old.selected != selected;
}
