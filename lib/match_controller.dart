import 'dart:async';
import 'dart:math';

import 'package:arena_engine/arena_engine.dart' as engine;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arena.dart';
import 'duel_events.dart';
import 'engine_events.dart';
import 'house_bot.dart';
import 'profile.dart';

enum MatchPhase { searching, playing, finished }

/// Owns match timers, pause reasons, one-time rewards and the event queue
/// for both duel formats:
///
/// * engine duel (default): `packages/arena_engine`, five rounds of three
///   moves per player against a [HouseBot];
/// * legacy 90-second race ([legacyRace]): kept behind a debug switch
///   until the humans decide Gate 1.
///
/// This class never animates; contract events go to the board view through
/// [eventSink] and the view calls [onBoardIdle] when its queue drains.
class ArenaMatchController extends ChangeNotifier {
  ArenaMatchController(
    this.player,
    this.mode, {
    int botLevel = 1,
    this.legacyRace = false,
    int? seed,
  }) : _botLevel = botLevel.clamp(0, 2) {
    _seed = seed ?? Random().nextInt(1 << 30);
    botTrophies = max(0, player.trophies + Random().nextInt(151) - 75);
    board.slot = PlayerSlot.first;
    bot.slot = PlayerSlot.second;
    board.obstacleKind = _obstacleKindFor(player.tier);
    bot.obstacleKind = ObstacleKind.tangledYarn;
    board.takeEvents();
    bot.takeEvents();
    if (legacyRace) {
      initialSnapshot = board.snapshot();
      remaining = mode == 1 ? 45 : 90;
      _search = Timer(const Duration(seconds: 3), _startLegacy);
    } else {
      // Engine state is created when the VS phase ends so the bot level
      // can still be picked on the versus screen.
      _search = Timer(const Duration(seconds: 3), _startEngine);
      _loadTutorialFlag();
    }
  }

  static ObstacleKind _obstacleKindFor(int tier) => switch (tier) {
    0 => ObstacleKind.cardboardBox,
    1 => ObstacleKind.slipper,
    _ => ObstacleKind.tangledYarn,
  };

  static const botNames = ['Pisi Fundal', 'Bubble Bot', 'Vulpița'];
  static const botLevelNames = ['Ușor', 'Mediu', 'Greu'];

  final Player player;
  final int mode;
  final bool legacyRace;
  final board = MatchBoard(), bot = MatchBoard();

  int _botLevel;
  int get botLevel => _botLevel;
  set botLevel(int value) {
    final v = value.clamp(0, 2);
    if (v == _botLevel) return;
    _botLevel = v;
    _bot = HouseBot(level: v, seed: _botSeed);
    refresh();
  }

  String get botName => botNames[_botLevel];
  String get botLevelName => botLevelNames[_botLevel];

  late int _seed;
  int get seed => _seed;

  // --- engine state -----------------------------------------------------

  engine.MatchState? _state;
  EngineViewAdapter? _adapter;
  HouseBot? _bot;
  int _botSeed = 0;
  int _playerMoves = 0;
  int _acceptedMoves = 0;
  int _botMoves = 0;
  bool _zoomiesArmed = false;
  bool _tutorialDone = true;
  DateTime? _matchStart;

  bool get isEngine => !legacyRace;

  /// Board contents for [BoardView]; stable for the match lifetime.
  late BoardSnapshot initialSnapshot;

  /// Set by the screen to receive contract events for the player board.
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
  bool _disposed = false, _background = false, _modal = false, _started = false;
  Timer? _search, _clock;
  bool get paused => _background || _modal;
  bool get acceptingInput =>
      phase == MatchPhase.playing &&
      !paused &&
      !_busy &&
      (!isEngine ||
          (_state != null &&
              !_state!.isFinished &&
              _state!.activePlayer == engine.PlayerSlot.first));

  // --- unified HUD getters ----------------------------------------------

  int get playerScore =>
      isEngine ? _state?.scoreOf(engine.PlayerSlot.first) ?? 0 : board.score;
  int get playerCharge =>
      isEngine ? _state?.chargeOf(engine.PlayerSlot.first) ?? 0 : board.charge;
  int get botScore =>
      isEngine ? _state?.scoreOf(engine.PlayerSlot.second) ?? 0 : bot.score;
  int get round => isEngine ? _state?.round ?? 1 : 1;
  int get totalRounds => isEngine ? _state?.config.rounds ?? 5 : 1;
  int get movesLeft =>
      isEngine ? _state?.movesLeft(engine.PlayerSlot.first) ?? 0 : -1;
  bool get zoomiesArmed => _zoomiesArmed;

  /// Obstacles the player will receive at the start of the next round.
  List<ObstacleKind> get incomingObstacles {
    if (!isEngine) return const [];
    final pending =
        _state?.pendingObstacles[engine.PlayerSlot.first.index] ??
        const <engine.ObstacleKind>[];
    return [
      for (final k in pending)
        k == engine.ObstacleKind.yarn
            ? ObstacleKind.tangledYarn
            : ObstacleKind.cardboardBox,
    ];
  }

  /// Accepted player moves so far (tutorial progress).
  int get playerMoves => _playerMoves;

  /// First-match tutorial: true during the player's first three moves.
  bool get tutorialActive =>
      isEngine && !_tutorialDone && _playerMoves < 3 && phase == MatchPhase.playing;

  /// A suggested legal swap (flat cell pair) for the tutorial hint.
  (int, int)? get hintSwap {
    if (!tutorialActive || _state == null) return null;
    final legal = engine.legalMoves(_state!);
    if (legal is! engine.EngineOk<List<engine.Move>>) return null;
    final w = _state!.config.boardWidth;
    for (final m in legal.value) {
      if (m is engine.SwapMove) {
        return (
          m.firstCell.row * w + m.firstCell.col,
          m.secondCell.row * w + m.secondCell.col,
        );
      }
    }
    return null;
  }

  /// All legal swap pairs (flat indices) for the active player; test hook.
  @visibleForTesting
  List<(int, int)> get legalSwaps {
    if (!isEngine || _state == null) return const [];
    final legal = engine.legalMoves(_state!);
    if (legal is! engine.EngineOk<List<engine.Move>>) return const [];
    final w = _state!.config.boardWidth;
    return [
      for (final m in legal.value)
        if (m is engine.SwapMove)
          (m.firstCell.row * w + m.firstCell.col, m.secondCell.row * w + m.secondCell.col),
    ];
  }

  void refresh() {
    if (!_disposed) notifyListeners();
  }

  void pause({bool? background, bool? modal}) {
    if (background != null) _background = background;
    if (modal != null) _modal = modal;
    refresh();
  }

  // --- match start --------------------------------------------------------

  void _startLegacy() {
    phase = MatchPhase.playing;
    _matchStart = DateTime.now();
    refresh();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _startEngine() {
    if (_started) return;
    _started = true;
    _botSeed = _seed ^ 0x5f3759df;
    _bot = HouseBot(level: _botLevel, seed: _botSeed);
    final res = engine.newMatch(_seed, const engine.MatchConfig.duel());
    if (res is engine.EngineOk<engine.MatchState>) {
      _state = res.value;
      _adapter = EngineViewAdapter(
        width: _state!.config.boardWidth,
        height: _state!.config.boardHeight,
      );
      initialSnapshot = _adapter!.snapshotOf(_state!, engine.PlayerSlot.first);
      _matchStart = DateTime.now();
      _zoomiesArmed = false;
      phase = MatchPhase.playing;
    } else {
      phase = MatchPhase.finished;
      result = 0;
    }
    refresh();
  }

  Future<void> _loadTutorialFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _tutorialDone = prefs.getBool('cpa_duel_tutorial_done') ?? false;
      refresh();
    } on Object {
      _tutorialDone = true;
    }
  }

  void _markTutorialDone() {
    if (_tutorialDone) return;
    _tutorialDone = true;
    SharedPreferences.getInstance()
        .then((p) => p.setBool('cpa_duel_tutorial_done', true))
        .ignore();
  }

  // --- moves ---------------------------------------------------------------

  /// Player attempted an adjacent swap (flat cell indices).
  void tryMove(int a, int b) {
    if (!acceptingInput) return;
    if (isEngine) {
      _zoomiesArmed = false;
      final w = _state!.config.boardWidth;
      _applyEngine(
        engine.SwapMove(
          firstCell: (row: a ~/ w, col: a % w),
          secondCell: (row: b ~/ w, col: b % w),
        ),
        isPlayerMove: true,
      );
      return;
    }
    if (!board.adjacent(a, b)) {
      board.rejectSwap(a, b, 'not-adjacent');
    } else if (board.cells[a] < 0 || board.cells[b] < 0) {
      board.rejectSwap(a, b, 'blocked');
    } else if (!board.swap(a, b)) {
      board.rejectSwap(a, b, 'no-match');
    } else {
      final attacks = board.attacks;
      board.resolve();
      if (board.attacks > attacks) bot.obstacle();
    }
    bot.takeEvents();
    _emit();
  }

  /// Fires a power. [targetRow] is required for [PowerKind.zoomies] on the
  /// engine path; the legacy race picks its own row.
  void firePower(PowerKind power, {int? targetRow}) {
    if (!acceptingInput) return;
    if (isEngine) {
      if (power == PowerKind.zoomies && targetRow == null) {
        // First tap arms row targeting; a second tap cancels it.
        _zoomiesArmed = !_zoomiesArmed;
        refresh();
        return;
      }
      _zoomiesArmed = false;
      _applyEngine(
        engine.PowerMove(
          power: switch (power) {
            PowerKind.zoomies => engine.PowerKind.zoomies,
            PowerKind.shadowPounce => engine.PowerKind.shadowPounce,
            PowerKind.laserChase => engine.PowerKind.laserChase,
          },
          targetRow: targetRow,
        ),
        isPlayerMove: true,
      );
      return;
    }
    if (board.charge < 100) return;
    final kind = switch (power) {
      PowerKind.zoomies => 0,
      PowerKind.shadowPounce => 1,
      PowerKind.laserChase => 2,
    };
    board.firePower(kind, power: power);
    final attacks = board.attacks;
    board.resolve();
    if (board.attacks > attacks) bot.obstacle();
    bot.takeEvents();
    _emit();
  }

  void _applyEngine(engine.Move move, {required bool isPlayerMove}) {
    final prev = _state!;
    final res = engine.applyMove(prev, move);
    if (res is engine.EngineFailure<engine.MoveResult>) {
      if (move is engine.SwapMove) {
        final w = prev.config.boardWidth;
        _emit([
          SwapRejected(
            player: PlayerSlot.first,
            firstCell: move.firstCell.row * w + move.firstCell.col,
            secondCell: move.secondCell.row * w + move.secondCell.col,
            reason: res.error.code.name,
          ),
        ]);
      }
      refresh();
      return;
    }
    final mr = (res as engine.EngineOk<engine.MoveResult>).value;
    _state = mr.state;
    final events = _adapter!.adaptMove(mr, before: prev);
    final accepted = events.any((e) => e is Swapped || e is PowerFired);
    if (isPlayerMove && accepted) {
      _playerMoves++;
      _acceptedMoves++;
      if (_playerMoves >= 3) _markTutorialDone();
    } else if (!isPlayerMove) {
      _botMoves++;
    }
    _emit(events);
    if (_state!.isFinished) {
      _finishEngine();
      return;
    }
    _maybeBotTurn();
  }

  void _maybeBotTurn() {
    final s = _state;
    if (s == null || s.isFinished || s.activePlayer != engine.PlayerSlot.second) {
      return;
    }
    _applyEngine(_bot!.choose(s), isPlayerMove: false);
  }

  void _finishEngine() {
    final outcome = switch (_state!.outcome) {
      engine.MatchOutcome.firstWins => 1,
      engine.MatchOutcome.secondWins => -1,
      _ => 0,
    };
    final secs = _matchStart == null
        ? 0
        : DateTime.now().difference(_matchStart!).inSeconds;
    debugPrint(
      'CPA duel finished: ${_acceptedMoves + _botMoves} moves, '
      '${secs}s, botLevel=$_botLevel, seed=$_seed, outcome=$outcome',
    );
    finish(outcome);
  }

  /// Called by the board view when its animation queue has drained.
  void onBoardIdle() {
    if (_busy) {
      _busy = false;
      refresh();
    }
  }

  void _emit([List<BoardEvent>? events]) {
    final out = events ?? board.takeEvents();
    if (out.isEmpty) {
      refresh();
      return;
    }
    if (!isEngine) bot.takeEvents();
    _busy = true;
    if (_eventSink != null) {
      _eventSink!(out);
    } else {
      _pending.addAll(out);
    }
    refresh();
  }

  void tick() {
    if (_disposed || paused || phase != MatchPhase.playing || isEngine) return;
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

  /// Restarts the match with a fresh seed (engine) or fresh boards
  /// (legacy). Goes back through the VS phase.
  void rematch() {
    if (_disposed || phase != MatchPhase.finished) return;
    _search?.cancel();
    _clock?.cancel();
    if (isEngine) {
      _seed = Random().nextInt(1 << 30);
      _state = null;
      _adapter = null;
      _playerMoves = 0;
      _acceptedMoves = 0;
      _botMoves = 0;
      _zoomiesArmed = false;
      _busy = false;
      _started = false;
    } else {
      board.score = 0;
      bot.score = 0;
      board.charge = 0;
      bot.charge = 0;
      board.reset();
      bot.reset();
      board.takeEvents();
      bot.takeEvents();
      remaining = mode == 1 ? 45 : 90;
      _busy = false;
    }
    result = null;
    phase = MatchPhase.searching;
    _search = Timer(const Duration(seconds: 3), isEngine ? _startEngine : _startLegacy);
    refresh();
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
