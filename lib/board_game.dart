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

/// Candidate sprite file names per canonical art key, tried in order
/// under `assets/images/` first and `assets/generated/` second. Lane 1's
/// converted sprites land in `assets/images/`; the generated fallbacks
/// keep working until then.
const _spriteCandidates = <String, List<String>>{
  'tile_star': ['tile_star'],
  'tile_fish': ['tile_fish'],
  'tile_mouse': ['tile_mouse'],
  'tile_yarn': ['tile_yarn'],
  'tile_paw': ['tile_paw'],
  'obs_cardboard_box': ['tile_box', 'obs_cardboard_box'],
  'obs_slipper': ['obs_slipper'],
  'obs_tangled_yarn': ['obs_tangled_yarn'],
  'special_line': ['special_fish_rocket'],
  'special_bomb': ['special_yarn_bomb'],
  'special_copter': ['special_mouse_copter'],
  'special_rainbow': ['special_rainbow_paw'],
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
    this.rowPicker,
    this.hintCells,
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

  /// When set, taps report the tapped row (0-based) instead of selecting a
  /// cell — used to pick a Zoomies target row.
  final void Function(int row)? rowPicker;

  /// Cells highlighted as a suggested move (tutorial hint).
  final Set<int>? hintCells;

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
  Offset _panDelta = Offset.zero;
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
    await Future.wait(
      _spriteCandidates.entries.map(
        (e) => _loadSprite(e.key, e.value),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Tries each candidate under `assets/images/` then
  /// `assets/generated/`, storing the first hit under [canonical].
  Future<void> _loadSprite(String canonical, List<String> candidates) async {
    for (final dir in const ['assets/images/', 'assets/generated/']) {
      for (final name in candidates) {
        try {
          final data = await rootBundle.load('$dir$name.png');
          // Decode near the on-screen size: tiles render at most ~100
          // logical px (~300 physical on 3x panels), so the full-res art
          // only burns decode time and GPU memory.
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
            targetWidth: 320,
          );
          final frame = await codec.getNextFrame();
          _art[canonical] = frame.image;
          return;
        } on Object {
          // Try the next candidate/directory.
        }
      }
    }
    // Missing art renders as a colored gem; never block the board.
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
    _idleNotified = false;
    _schedule = math.max(_schedule, _now);
    for (final e in events) {
      _fold(e);
    }
    if (!widget.suspended) _ensureTicker();
    return done.future;
  }

  Type? _lastKind;
  double _lastStart = 0;

  void _fold(BoardEvent event) {
    // Same-wave physics events animate together: a collapse drops its
    // column in one move and refills rain down as a group — not one cell
    // at a time like a waterfall.
    final kind = event.runtimeType;
    final grouped = identical(kind, _lastKind) &&
        (event is Fell || event is Refilled);
    final start = grouped ? _lastStart + 0.012 : _schedule;
    _schedule = grouped
        ? _schedule + 0.012
        : math.max(start, _schedule) + _slotFor(event);
    _lastKind = kind;
    _lastStart = start;
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

  bool _idleNotified = true;

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
              dur: 0.11,
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
              dur: 0.11,
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
              dur: 0.16,
            ),
          if (b.piece != null || b.obstacle != null)
            _staticFx(
              event,
              _FxKind.shake,
              secondCell,
              piece: b.piece,
              obstacle: b.obstacle,
              start: start,
              dur: 0.16,
            ),
        ];
      case Cleared(:final cells):
        return _popCells(event, cells, start, 0.14);
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
      case SpecialFired(:final cells, :final kind):
        final fx = <_Fx>[..._popCells(event, cells, start, 0.24)];
        // Activation effect per special kind: a light beam along the
        // cleared row/column, a blast ring for the bomb, a board flash
        // for the rainbow.
        if (cells.isNotEmpty) {
          switch (kind) {
            case SpecialKind.lineHorizontal:
              fx.add(
                _staticFx(
                  event,
                  _FxKind.beamH,
                  cells.first,
                  start: start,
                  dur: 0.34,
                ),
              );
            case SpecialKind.lineVertical:
              fx.add(
                _staticFx(
                  event,
                  _FxKind.beamV,
                  cells.first,
                  start: start,
                  dur: 0.34,
                ),
              );
            case SpecialKind.bomb || SpecialKind.copter:
              var rr = 0, cc = 0;
              for (final i in cells) {
                rr += i ~/ width;
                cc += i % width;
              }
              fx.add(
                _staticFx(
                  event,
                  _FxKind.blast,
                  (rr ~/ cells.length) * width + (cc ~/ cells.length),
                  start: start,
                  dur: 0.4,
                ),
              );
            case SpecialKind.rainbow:
              fx.add(
                _staticFx(
                  event,
                  _FxKind.boardFlash,
                  0,
                  start: start,
                  dur: 0.4,
                ),
              );
            case SpecialKind.none:
              break;
          }
        }
        return fx;
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
            dur: 0.16,
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
            dur: 0.18,
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
      case BoardReset(:final snapshot):
        return _reset(event, snapshot, start);
      case ObstacleQueued() ||
          PowerCharged() ||
          TurnEnded() ||
          MatchEnded():
        return const [];
    }
  }

  /// Round transition: swap in the freshly dealt board and fade each piece
  /// in column-by-column so the new round reads as a fresh deal.
  List<_Fx> _reset(BoardEvent event, BoardSnapshot snapshot, double start) {
    final src = snapshot.cells;
    final out = <_Fx>[];
    for (var idx = 0; idx < _cells.length && idx < src.length; idx++) {
      final cell = src[idx];
      _cells[idx] = cell;
      final stagger = (idx % width) * 0.02 + (idx ~/ width) * 0.008;
      if (cell.piece != null) {
        out.add(
          _staticFx(
            event,
            _FxKind.refill,
            idx,
            piece: cell.piece,
            start: start + stagger,
            dur: 0.24,
          ),
        );
      }
      if (cell.obstacle != null) {
        out.add(
          _staticFx(
            event,
            _FxKind.obstacleIn,
            idx,
            obstacle: cell.obstacle,
            start: start + stagger,
            dur: 0.26,
          ),
        );
      }
    }
    return out;
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
            dur: 0.3,
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
    Swapped() => 0.11,
    SwapRejected() => 0.14,
    Cleared() => 0.14,
    SpecialCreated() => 0.12,
    SpecialFired() => 0.14,
    PowerFired() => 0.14,
    Fell() => 0.1,
    Refilled() => 0.1,
    ObstacleLanded() => 0.12,
    ObstacleBroken() => 0.12,
    Shuffled() => 0.3,
    BoardReset() => 0.55,
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
    // Idle means the cell animations and scheduled events have drained —
    // floating meta banners (score/combo labels) may still be visible, so
    // they no longer hold the input lock or delay the bot's next move.
    if (_fx.isEmpty && _meta.isEmpty && _schedule <= _now && !_idleNotified) {
      _idleNotified = true;
      widget.onIdle?.call();
      for (final c in _completers) {
        if (!c.isCompleted) c.complete();
      }
      _completers.clear();
    }
    if (_fx.isEmpty &&
        _meta.isEmpty &&
        _banners.isEmpty &&
        _schedule <= _now) {
      _ticker.stop();
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
    _panDelta = Offset.zero;
    setState(() {});
    widget.onSwapAttempt?.call(from, to);
  }

  void _onTapUp(TapUpDetails details, double cell) {
    final target = _cellAt(details.localPosition, cell);
    if (target == null || !widget.inputEnabled) return;
    final picker = widget.rowPicker;
    if (picker != null) {
      picker(target ~/ width);
      return;
    }
    final sel = _selected;
    if (sel != null && _adjacent(sel, target) && sel != target) {
      _attempt(sel, target);
    } else {
      setState(() => _selected = target == _selected ? null : target);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, double cell) {
    if (!widget.inputEnabled || widget.rowPicker != null) return;
    _dragFrom ??= _downCell;
    final from = _dragFrom;
    if (from == null) return;
    // Short swipes (~16px) commit the swap in the drag direction right
    // away — no need to drag a full cell.
    _panDelta += details.delta;
    if (_panDelta.distance >= 16) {
      final horiz = _panDelta.dx.abs() >= _panDelta.dy.abs();
      final step = horiz
          ? (_panDelta.dx > 0 ? 1 : -1)
          : (_panDelta.dy > 0 ? width : -width);
      final to = from + step;
      if (to >= 0 && to < _cells.length && _adjacent(from, to)) {
        _attempt(from, to);
      } else {
        _panDelta = Offset.zero;
        _dragFrom = null;
      }
      return;
    }
    final target = _cellAt(details.localPosition, cell);
    if (target != null && _adjacent(from, target)) _attempt(from, target);
  }

  // --- meta-event banners ----------------------------------------------

  /// Floating label for events that have no board-cell animation
  /// (ObstacleQueued, PowerCharged, TurnEnded, MatchEnded).
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
            ? '1 cutie următoare!'
            : '$count cutii următoare!',
        const Color(0xffffb066),
        15.0,
      ),
      Shuffled() => ('AMESTECARE!', _bannerGold, 17.0),
      // The meter's own bar communicates charge; a floating percentage
      // over the board was noise the spec asks to remove.
      PowerCharged() => ('', _bannerGold, 12.0),
      TurnEnded(:final turn, :final scores) => (
        'Tura $turn  •  ${scores.first} – ${scores.second}',
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
                    hinted: widget.hintCells,
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
  beamH,
  beamV,
  blast,
  boardFlash,
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
  static const dur = 0.45;
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
    this.hinted,
  });

  final List<BoardCell> cells;
  final List<_Fx> fx;
  final double now;
  final Map<String, ui.Image> art;
  final int? selected;
  final int width;
  final int height;
  final Set<int>? hinted;

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
      // Uniform dark cells (spec: #24150E @ 0.82) — the warm frame tint
      // shows through slightly instead of a checkerboard.
      bg.color = i == selected
          ? const Color(0xffffd66d)
          : const Color(0xd124150e);
      canvas.drawRRect(rrect, bg);
    }

    final hinted = this.hinted;
    if (hinted != null && hinted.isNotEmpty) {
      final hp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Color.fromRGBO(
          255,
          214,
          109,
          0.5 + 0.3 * math.sin(now * 6),
        );
      for (final i in hinted) {
        if (i < 0 || i >= cells.length) continue;
        final col = i % width, row = i ~/ width;
        final x = ox + col * cell, y = oy + row * cell;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 2, y + 2, cell - 4, cell - 4),
            Radius.circular(cell * 0.16),
          ),
          hp,
        );
      }
    }

    // Unfiltered draw for the common alpha-1 case: a modulate filter on
    // every image routed 50+ draws per frame through the filtered
    // pipeline for nothing.
    final plainPaint = Paint()..filterQuality = FilterQuality.medium;
    Paint? fadePaint;
    Paint paintFor(double alpha) => alpha >= 0.999
        ? plainPaint
        : (fadePaint ??= Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(
            const Color(0xffffffff).withValues(alpha: alpha),
            BlendMode.modulate,
          ));

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
      // Only rainbow tiles rotate — the common path needs no save/
      // translate sandwich at all.
      final rotates = piece.special == SpecialKind.rainbow;
      if (rotates) {
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(now * 1.4);
        canvas.translate(-cx, -cy);
      }
      if (piece.special != SpecialKind.none) {
        // Pulsing glow behind the special tile, tinted by the colour it
        // was made from — that colour is what it combines with. Rainbow
        // keeps the neutral icy halo. Two stacked alpha circles cost two
        // fills; the old per-frame RadialGradient shader allocation is
        // gone.
        final glow = switch (piece.special) {
          SpecialKind.rainbow => const Color(0xff9fd7ff),
          _ when piece.kind < _gemColors.length => _gemColors[piece.kind],
          _ => const Color(0xfffff3c4),
        };
        final glowR = s * 0.6 * (1 + 0.07 * math.sin(now * 5));
        canvas.drawCircle(
          rect.center,
          glowR,
          Paint()..color = glow.withValues(alpha: 0.22 * alpha),
        );
        canvas.drawCircle(
          rect.center,
          glowR * 0.62,
          Paint()..color = glow.withValues(alpha: 0.34 * alpha),
        );
      }
      final img = piece.kind < _tileNames.length
          ? art[_tileNames[piece.kind]]
          : null;
      // Lane-1 special art replaces the tile + procedural marks entirely;
      // without it the procedural badge/mark fallback stays.
      final specialKey = switch (piece.special) {
        SpecialKind.lineHorizontal || SpecialKind.lineVertical =>
          'special_line',
        SpecialKind.bomb => 'special_bomb',
        SpecialKind.copter => 'special_copter',
        SpecialKind.rainbow => 'special_rainbow',
        SpecialKind.none => null,
      };
      final specialImg = specialKey == null ? null : art[specialKey];
      if (specialImg != null) {
        // The rocket art points right; a column-clearer flies up.
        final spin = piece.special == SpecialKind.lineVertical;
        if (spin) {
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(-math.pi / 2);
          canvas.translate(-cx, -cy);
        }
        canvas.drawImageRect(
          specialImg,
          Rect.fromLTWH(
            0,
            0,
            specialImg.width.toDouble(),
            specialImg.height.toDouble(),
          ),
          rect,
          paintFor(alpha),
        );
        if (spin) canvas.restore();
      } else if (img != null) {
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          rect,
          paintFor(alpha),
        );
      } else {
        _drawGem(canvas, rect, piece.kind, alpha);
      }
      if (piece.special != SpecialKind.none && specialImg == null) {
        _drawSpecialBadge(canvas, rect, piece.special, alpha);
        _drawSpecialMark(canvas, rect, piece.special, alpha, now);
      }
      // Colour chip on non-rainbow specials: the colour it was made from
      // is the colour it combines with.
      if (piece.special != SpecialKind.none &&
          piece.special != SpecialKind.rainbow &&
          piece.kind < _gemColors.length) {
        final d = s * 0.22;
        final c = Offset(
          rect.right - d * 0.42,
          rect.bottom - d * 0.42,
        );
        canvas.drawCircle(
          c,
          d * 0.52,
          Paint()..color = const Color(0xff20130e).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          c,
          d * 0.38,
          Paint()
            ..color = _gemColors[piece.kind].withValues(alpha: alpha),
        );
      }
      if (rotates) canvas.restore();
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
          paintFor(alpha),
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

    // Board-wide activation overlays carry no piece/obstacle.
    switch (f.kind) {
      case _FxKind.beamH:
        final h = cell * 0.34 * (1 - t * 0.5);
        final rect = Rect.fromLTWH(ox, cy - h / 2, f.width * cell, h);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(h / 2)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xfffff3c4).withValues(alpha: 0),
                const Color(0xfffff3c4).withValues(alpha: (1 - t) * 0.9),
                const Color(0xfffff3c4).withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
        return;
      case _FxKind.beamV:
        final w = cell * 0.34 * (1 - t * 0.5);
        final rect = Rect.fromLTWH(cx - w / 2, oy, w, f.width * cell);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(w / 2)),
          Paint()
            ..shader = LinearGradient(
              colors: [
                const Color(0xfffff3c4).withValues(alpha: 0),
                const Color(0xfffff3c4).withValues(alpha: (1 - t) * 0.9),
                const Color(0xfffff3c4).withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
        return;
      case _FxKind.blast:
        canvas.drawCircle(
          Offset(cx, cy),
          cell * (0.4 + 1.7 * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 + 4 * (1 - t)
            ..color = const Color(0xffffb64d).withValues(alpha: (1 - t) * 0.9),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          cell * (0.4 + 1.7 * t) * 0.9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 + 6 * (1 - t)
            ..color = const Color(0xffffd98b).withValues(alpha: (1 - t) * 0.3),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          cell * 0.4 * (1 - t),
          Paint()
            ..color = const Color(0xfffff3c4).withValues(alpha: (1 - t) * 0.75),
        );
        return;
      case _FxKind.boardFlash:
        canvas.drawRect(
          Rect.fromLTWH(ox, oy, f.width * cell, f.width * cell),
          Paint()
            ..color = const Color(0xfffff3c4).withValues(alpha: (1 - t) * 0.35),
        );
        return;
      case _:
        break;
    }

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
      case _FxKind.fall ||
          _FxKind.swap ||
          _FxKind.shuffle ||
          _FxKind.beamH ||
          _FxKind.beamV ||
          _FxKind.blast ||
          _FxKind.boardFlash:
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
      SpecialKind.copter => const Color(0xff3d6b2f),
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

  /// Distinct mark painted over a special tile: stripe pair for line
  /// pieces, a spark badge for the bomb, a rotating tri-colour arc for the
  /// rainbow. Complements [_drawSpecialBadge]'s ring.
  void _drawSpecialMark(
    Canvas canvas,
    Rect rect,
    SpecialKind kind,
    double alpha,
    double now,
  ) {
    final c = rect.center;
    final s = rect.width;
    switch (kind) {
      case SpecialKind.lineHorizontal || SpecialKind.lineVertical:
        final paint = Paint()
          ..color = const Color(0xfffff8dc).withValues(alpha: 0.92 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.09
          ..strokeCap = StrokeCap.round;
        for (final off in [-s * 0.15, s * 0.15]) {
          canvas.drawLine(
            kind == SpecialKind.lineHorizontal
                ? Offset(rect.left + s * 0.14, c.dy + off)
                : Offset(c.dx + off, rect.top + s * 0.14),
            kind == SpecialKind.lineHorizontal
                ? Offset(rect.right - s * 0.14, c.dy + off)
                : Offset(c.dx + off, rect.bottom - s * 0.14),
            paint,
          );
        }
      case SpecialKind.bomb:
        canvas.drawCircle(
          c,
          s * 0.3,
          Paint()
            ..color = const Color(0xff4a2c2c).withValues(alpha: 0.85 * alpha),
        );
        canvas.drawCircle(
          c,
          s * 0.3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.05
            ..color = const Color(0xffffb64d).withValues(alpha: alpha),
        );
        // Fuse spark, top-right, flickering.
        final spark = Offset(c.dx + s * 0.2, c.dy - s * 0.2);
        canvas.drawCircle(
          spark,
          s * 0.07 * (1 + 0.3 * math.sin(now * 9)),
          Paint()
            ..color = const Color(0xffffe28a).withValues(alpha: alpha),
        );
      case SpecialKind.copter:
        // Helicopter blades: two spinning rotor arms over a green disc.
        canvas.drawCircle(
          c,
          s * 0.3,
          Paint()
            ..color = const Color(0xff2f4f26).withValues(alpha: 0.8 * alpha),
        );
        final rotor = Paint()
          ..color = const Color(0xffd8f0c8).withValues(alpha: 0.95 * alpha)
          ..strokeWidth = s * 0.06
          ..strokeCap = StrokeCap.round;
        for (final a in [now * 10, now * 10 + math.pi / 2]) {
          canvas.drawLine(
            Offset(c.dx - math.cos(a) * s * 0.26, c.dy - math.sin(a) * s * 0.26),
            Offset(c.dx + math.cos(a) * s * 0.26, c.dy + math.sin(a) * s * 0.26),
            rotor,
          );
        }
      case SpecialKind.rainbow:
        // The tile itself rotates; paint a static shimmer ring of three
        // colour segments around it.
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: s * 0.42),
            i * (2 * math.pi / 3) + now * 1.4,
            math.pi / 2.6,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.06
              ..color = [
                const Color(0xffff9d8f),
                const Color(0xffffe28a),
                const Color(0xff9fd7ff),
              ][i].withValues(alpha: 0.9 * alpha),
          );
        }
      case SpecialKind.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.now != now ||
      old.cells != cells ||
      old.fx.length != fx.length ||
      old.selected != selected ||
      old.hinted != hinted;
}
