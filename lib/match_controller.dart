import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'arena.dart';
import 'duel_events.dart';
import 'profile.dart';

enum MatchPhase { searching, playing, finished }

/// Owns match timers, pause reasons, and one-time rewards for the legacy
/// 90-second race. Game rules live in [MatchBoard] (arena.dart) until
/// `packages/arena_engine` lands; this class only shuttles contract events
/// to the board view and never animates anything itself.
class ArenaMatchController extends ChangeNotifier {
  ArenaMatchController(this.player, this.mode) {
    remaining = mode == 1 ? 45 : 90;
    botTrophies = max(0, player.trophies + Random().nextInt(151) - 75);
    board.slot = PlayerSlot.first;
    bot.slot = PlayerSlot.second;
    board.obstacleKind = _obstacleKindFor(player.tier);
    bot.obstacleKind = ObstacleKind.tangledYarn;
    board.takeEvents();
    bot.takeEvents();
    _search = Timer(const Duration(seconds: 3), () {
      phase = MatchPhase.playing;
      refresh();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    });
  }

  static ObstacleKind _obstacleKindFor(int tier) => switch (tier) {
    0 => ObstacleKind.cardboardBox,
    1 => ObstacleKind.slipper,
    _ => ObstacleKind.tangledYarn,
  };

  final Player player;
  final int mode;
  final board = MatchBoard(), bot = MatchBoard();

  /// Initial board contents for [BoardView]; stable for the match lifetime.
  late final BoardSnapshot initialSnapshot = board.snapshot();

  /// Set by the screen to receive contract events for the player board.
  /// Events are queued until a sink is attached.
  void Function(List<BoardEvent>)? _eventSink;
  final List<BoardEvent> _pending = [];
  bool _busy = false;

  set eventSink(void Function(List<BoardEvent>)? sink) {
    _eventSink = sink;
    if (sink != null && _pending.isNotEmpty) {
      final events = List<BoardEvent>.of(_pending);
      _pending.clear();
      sink(events);
    }
  }

  late int remaining, botTrophies;
  MatchPhase phase = MatchPhase.searching;
  int? result;
  bool _disposed = false, _background = false, _modal = false;
  Timer? _search, _clock;
  bool get paused => _background || _modal;
  int get botScore => bot.score;
  bool get acceptingInput => phase == MatchPhase.playing && !paused && !_busy;

  void refresh() {
    if (!_disposed) notifyListeners();
  }

  void pause({bool? background, bool? modal}) {
    if (background != null) _background = background;
    if (modal != null) _modal = modal;
    refresh();
  }

  /// Player attempted an adjacent swap; the board decides legality and the
  /// resulting contract events go to the view.
  void tryMove(int a, int b) {
    if (!acceptingInput) return;
    if (!board.adjacent(a, b)) {
      board.rejectSwap(a, b, SwapRejectReason.notAdjacent);
    } else if (board.cells[a] < 0 || board.cells[b] < 0) {
      board.rejectSwap(a, b, SwapRejectReason.blocked);
    } else if (!board.swap(a, b)) {
      board.rejectSwap(a, b, SwapRejectReason.noMatch);
    } else {
      final attacks = board.attacks;
      board.resolve();
      if (board.attacks > attacks) bot.obstacle();
    }
    bot.takeEvents();
    _emit();
  }

  /// Fires the player's charged power (legacy row/column/colour clear).
  void firePower(int kind) {
    if (!acceptingInput || board.charge < 100) return;
    board.firePower(kind, power: _powerKind(kind));
    final attacks = board.attacks;
    board.resolve();
    if (board.attacks > attacks) bot.obstacle();
    bot.takeEvents();
    _emit();
  }

  static PowerKind _powerKind(int kind) => switch (kind) {
    0 => PowerKind.zoomies,
    1 => PowerKind.shadowPounce,
    _ => PowerKind.laserChase,
  };

  /// Called by the board view when its animation queue has drained.
  void onBoardIdle() {
    if (_busy) {
      _busy = false;
      refresh();
    }
  }

  void _emit() {
    final events = board.takeEvents();
    if (events.isEmpty) {
      refresh();
      return;
    }
    _busy = true;
    if (_eventSink != null) {
      _eventSink!(events);
    } else {
      _pending.addAll(events);
    }
    refresh();
  }

  void tick() {
    if (_disposed || paused || phase != MatchPhase.playing) return;
    remaining--;
    if (remaining % 3 == 0) {
      final old = bot.attacks;
      bot.autoMove();
      bot.takeEvents();
      if (bot.attacks > old) board.obstacle();
      _emit();
    }
    if (mode == 2 && remaining % 8 == 0) {
      board.obstacle();
      _emit();
    }
    if (remaining <= 0) {
      finish(board.score.compareTo(botScore));
    } else {
      refresh();
    }
  }

  void finish(int outcome) {
    if (_disposed || phase == MatchPhase.finished) return;
    _search?.cancel();
    _clock?.cancel();
    _busy = false;
    result = outcome;
    phase = MatchPhase.finished;
    player.result(outcome);
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _search?.cancel();
    _clock?.cancel();
    super.dispose();
  }
}
