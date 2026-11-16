import 'dart:async';
import 'dart:math';

import 'package:arena_engine/arena_engine.dart' as engine;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arena.dart';
import 'duel_events.dart';
import 'engine_events.dart';
import 'house_bot.dart';
import 'online/cloud_profile.dart';
import 'online/emotes.dart';
import 'online/match_store.dart';
import 'online/match_sync.dart';
import 'online/online_backend.dart';
import 'online/online_config.dart';
import 'profile.dart';

enum MatchPhase { searching, playing, finished }

/// Opponent identity agreed when a friend match is created: preset display
/// name, trophies and the cat loadout fields used for the avatar. Peer-
/// visible strings are preset IDs only — never typed names (contract §4).
class OnlineOpponentInfo {
  const OnlineOpponentInfo({
    required this.name,
    required this.trophies,
    required this.cat,
    this.fur = 0,
    this.eyes = 0,
    this.ears = 1,
    this.pattern = 0,
    this.accessory = '',
    this.power = 0,
  });

  /// Preset display name (from the preset list, resolved by the online
  /// layer); safe to render to this player.
  final String name;
  final int trophies;

  /// Cat selection: `'Tzuki'`, `'Bubble'` or `'Custom'` plus palette
  /// indices, mirroring the [Player] visual fields.
  final String cat;
  final int fur, eyes, ears, pattern;
  final String accessory;
  final int power;

  /// Builds the VS/result identity from the opponent's cloud profile.
  /// Custom cats keep no peer-visible preset name in the cloud save, so
  /// they are labelled with the generic 'Pisică' — never typed text.
  factory OnlineOpponentInfo.fromCloudProfile(CloudProfile? profile) {
    if (profile == null) {
      return const OnlineOpponentInfo(
        name: 'Pisică',
        trophies: 0,
        cat: 'Custom',
      );
    }
    return OnlineOpponentInfo(
      name: switch (profile.cat) {
        'Tzuki' => 'Tzuki',
        'Bubble' => 'Bubble',
        _ => 'Pisică',
      },
      trophies: profile.trophies,
      cat: profile.cat,
      fur: profile.fur,
      eyes: profile.eyes,
      ears: profile.ears,
      pattern: profile.pattern,
      accessory: profile.accessory,
      power: profile.power,
    );
  }
}

/// Everything the duel presentation needs from a friend match, assembled
/// from lane 5's `lib/online` match sync (`MatchSession` + `CloudStore`).
/// The session owns the shared seed/move-log state and flags mismatches;
/// the controller replays opponent moves for animation only.
class OnlineDuel {
  const OnlineDuel({
    required this.session,
    required this.cloud,
    required this.uid,
    required this.opponent,
  });

  /// Open (or resumed) friend-match session for this device.
  final MatchSession session;

  /// Cloud store for preset emotes; the same object backs [MatchSession].
  final CloudStore cloud;

  /// This device's account uid, used to filter own emote echoes.
  final String uid;

  /// Opponent identity for the VS/result screens.
  final OnlineOpponentInfo opponent;

  /// Opens the match session for [link] and resolves the opponent's cloud
  /// profile. Lane 4 calls this once the room flow produced a [MatchLink].
  static Future<OnlineDuel> open(
    OnlineServices services,
    MatchLink link,
  ) async {
    final session = await services.openMatch(link.matchId);
    final uid = session.uid;
    final record = session.record;
    final opponentUid = record.slotOf(uid) == engine.PlayerSlot.first
        ? record.guestUid
        : record.hostUid;
    CloudProfile? profile;
    try {
      final raw = await services.store.readProfile(opponentUid);
      if (raw != null) profile = CloudProfile.fromJson(raw);
    } on Object {
      profile = null;
    }
    return OnlineDuel(
      session: session,
      cloud: services.store,
      uid: uid,
      opponent: OnlineOpponentInfo.fromCloudProfile(profile),
    );
  }
}

/// Why an online duel ended without a scored result. [flagged] covers
/// every integrity failure (hash mismatch, illegal move, bad log, final
/// mismatch — the `MatchFlag` detail stays on the session); the rest are
/// local aborts. None of them awards trophies or paws.
enum OnlineAbort { flagged, surrendered, connectionLost }

/// Fixed house-cat opponent for House Tour battles (lane-4 request):
/// the match starts against this cat instead of the rotating house bots.
class BotOpponent {
  const BotOpponent({
    required this.name,
    required this.trophies,
    required this.level,
  });

  final String name;
  final int trophies;

  /// House-cat progression level (1–12); mapped to bot difficulty 0–2.
  final int level;

  /// Difficulty bucket: levels 1–4 easy, 5–8 medium, 9–12 hard.
  int get botLevel => ((level - 1) ~/ 4).clamp(0, 2);
}

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
    this.opponent,
    int? seed,
    this.online,
  }) : _botLevel = botLevel.clamp(0, 2) {
    _seed = seed ?? Random().nextInt(1 << 30);
    botTrophies = online?.opponent.trophies ??
        opponent?.trophies ??
        max(0, player.trophies + Random().nextInt(151) - 75);
    _localSlot = online?.session.slot ?? engine.PlayerSlot.first;
    board.slot = PlayerSlot.first;
    bot.slot = PlayerSlot.second;
    board.obstacleKind = _obstacleKindFor(player.tier);
    bot.obstacleKind = ObstacleKind.tangledYarn;
    board.takeEvents();
    bot.takeEvents();
    if (legacyRace && online == null) {
      initialSnapshot = board.snapshot();
      remaining = mode == 1 ? 45 : 90;
      _search = Timer(const Duration(seconds: 3), _startLegacy);
    } else {
      // Engine state is created when the VS phase ends so the bot level
      // can still be picked on the versus screen. Online sessions are
      // subscribed now so opponent moves during VS are already inside
      // `session.state` when [_startOnline] adopts it.
      _search = Timer(const Duration(seconds: 3), _startEngine);
      _loadTutorialFlag();
      _attachOnline();
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

  /// Fixed house-cat opponent, or null for the rotating house bots.
  final BotOpponent? opponent;

  /// Live friend-duel session (lane-5 `MatchSession`), or null for
  /// local/house-cat play.
  final OnlineDuel? online;

  int _botLevel;
  int get botLevel => opponent?.botLevel ?? _botLevel;
  set botLevel(int value) {
    if (opponent != null || isOnline) return;
    final v = value.clamp(0, 2);
    if (v == _botLevel) return;
    _botLevel = v;
    _bot = HouseBot(level: v, seed: _botSeed);
    refresh();
  }

  String get botName => isOnline
      ? online!.opponent.name
      : opponent?.name ?? botNames[_botLevel];
  String get botLevelName => isOnline
      ? 'Prieten'
      : opponent == null
      ? botLevelNames[_botLevel]
      : 'Casa';

  late int _seed;
  int get seed => isOnline ? online!.session.record.seed : _seed;

  // --- engine state -----------------------------------------------------

  engine.MatchState? _state;
  EngineViewAdapter? _adapter;
  HouseBot? _bot;
  int _botSeed = 0;
  int _playerMoves = 0;
  int _acceptedMoves = 0;
  int _remoteMoves = 0;
  bool _zoomiesArmed = false;
  bool _tutorialDone = true;
  DateTime? _matchStart;

  // --- online duel state --------------------------------------------------

  /// Engine slot this client plays (host = first, guest = second).
  engine.PlayerSlot _localSlot = engine.PlayerSlot.first;

  /// Engine slot of the remote opponent.
  engine.PlayerSlot get _opponentSlot => _localSlot.other;

  /// Number of accepted log moves already reflected in [_state]. The
  /// session may be ahead (it applies moves the moment they verify);
  /// input and rendering only trust the caught-up shadow state.
  int _onlineCursor = 0;

  final List<StreamSubscription<dynamic>> _onlineSubs = [];
  Timer? _pollTimer, _onlineClock, _settleTimer;
  bool _syncing = false, _syncAgain = false, _localFlag = false;
  bool _rewardsSettled = false, _rewardsCounted = false;
  DateTime? _lastOnlineMoveAt;

  /// Set when an online duel ends without a scored result; null for normal
  /// finishes and all local modes.
  OnlineAbort? abortReason;

  bool get isOnline => online != null;

  /// True for integrity-flagged finishes (a `MatchFlag` on the session or
  /// a local hash/ legality failure); flagged matches award nothing.
  bool get isFlagged =>
      _localFlag ||
      online?.session.flag != null ||
      abortReason == OnlineAbort.flagged;

  /// The opponent's preset emotes (empty for local modes). Own echoes are
  /// filtered out by uid.
  Stream<Emote> get opponentEmotes {
    final s = online;
    if (s == null) return const Stream<Emote>.empty();
    return s.cloud
        .emotes(s.session.matchId)
        .where((e) => e.senderUid != s.uid)
        .map((e) => e.emote);
  }

  /// Seconds left on the suggested live-move timer (contract: 30 s per
  /// move, display only — the match never auto-passes a turn).
  int? get liveMoveSecondsLeft {
    if (!isOnline || phase != MatchPhase.playing || _lastOnlineMoveAt == null) {
      return null;
    }
    final left = liveMoveLimit.inSeconds -
        DateTime.now().difference(_lastOnlineMoveAt!).inSeconds;
    return left < 0 ? 0 : left;
  }

  /// True once the 24-hour slow-play deadline passed and it is the
  /// opponent's move — the UI may offer [claimForfeit].
  bool get canClaimForfeit {
    final s = online?.session;
    if (s == null || phase != MatchPhase.playing) return false;
    final deadline = s.deadline;
    return deadline != null &&
        DateTime.now().isAfter(deadline) &&
        !s.isMyTurn &&
        !s.isOver;
  }

  bool get isEngine => !legacyRace || isOnline;

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
  bool get acceptingInput {
    if (phase != MatchPhase.playing || paused || _busy) return false;
    if (!isEngine) return true;
    if (_state == null || _state!.isFinished) return false;
    if (isOnline) {
      final s = online!.session;
      // Input only when the shadow state is caught up with the session —
      // otherwise an opponent move could be skipped visually.
      return s.isMyTurn && _onlineCursor == s.movesApplied;
    }
    return _state!.activePlayer == _localSlot;
  }

  /// True while the remote opponent holds the turn or their moves are
  /// still animating (online duels only).
  bool get opponentTurn =>
      isOnline &&
      phase == MatchPhase.playing &&
      _state != null &&
      !isFlagged &&
      !online!.session.isOver &&
      !online!.session.isMyTurn;

  // --- unified HUD getters ----------------------------------------------

  int get playerScore =>
      isEngine ? _state?.scoreOf(_localSlot) ?? 0 : board.score;
  int get playerCharge =>
      isEngine ? _state?.chargeOf(_localSlot) ?? 0 : board.charge;
  int get botScore =>
      isEngine ? _state?.scoreOf(_opponentSlot) ?? 0 : bot.score;
  int get round => isEngine ? _state?.round ?? 1 : 1;
  int get totalRounds => isEngine ? _state?.config.rounds ?? 5 : 1;
  int get movesLeft =>
      isEngine ? _state?.movesLeft(_localSlot) ?? 0 : -1;
  bool get zoomiesArmed => _zoomiesArmed;

  /// Obstacles the player will receive at the start of the next round.
  List<ObstacleKind> get incomingObstacles {
    if (!isEngine) return const [];
    final pending =
        _state?.pendingObstacles[_localSlot.index] ??
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

  /// Current engine state hash; test hook for cross-client comparison.
  @visibleForTesting
  String? get stateHashForTest =>
      _state == null ? null : engine.stateHash(_state!);

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
    if (isOnline) {
      _startOnline();
      return;
    }
    final res = engine.newMatch(_seed, const engine.MatchConfig.duel());
    if (res is engine.EngineOk<engine.MatchState>) {
      _state = res.value;
      _adapter = EngineViewAdapter(
        width: _state!.config.boardWidth,
        height: _state!.config.boardHeight,
        localSlot: _localSlot,
      );
      initialSnapshot = _adapter!.snapshotOf(_state!, _localSlot);
      _matchStart = DateTime.now();
      _zoomiesArmed = false;
      phase = MatchPhase.playing;
      _botSeed = _seed ^ 0x5f3759df;
      _bot = HouseBot(level: botLevel, seed: _botSeed);
    } else {
      phase = MatchPhase.finished;
      result = 0;
    }
    refresh();
  }

  /// Online start: the session already replayed the whole move log, so the
  /// shadow state is simply its current state and the cursor its applied
  /// count. Moves the friend made during the versus phase are already
  /// inside — no catch-up animation is owed.
  void _startOnline() {
    final s = online!.session;
    _state = s.state;
    _onlineCursor = s.movesApplied;
    _adapter = EngineViewAdapter(
      width: _state!.config.boardWidth,
      height: _state!.config.boardHeight,
      localSlot: _localSlot,
    );
    initialSnapshot = _adapter!.snapshotOf(_state!, _localSlot);
    _matchStart = DateTime.now();
    _lastOnlineMoveAt = s.lastMoveAt?.toLocal() ?? DateTime.now();
    _zoomiesArmed = false;
    _pollTimer = s.poll(
      const Duration(seconds: 20),
      onChange: (_) => unawaited(_syncOnline()),
    );
    _onlineClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (phase == MatchPhase.playing) refresh();
    });
    phase = MatchPhase.playing;
    if (_state!.isFinished || s.isOver) {
      // The match ended while this client was still on the versus screen
      // (forfeit claim or a finished log); settle straight to the result.
      _finishOnline(_outcomeFor(_state!.outcome));
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
    if (isOnline && isPlayerMove) {
      unawaited(_playOnline(move));
      return;
    }
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
    _commitEngineMove(
      (res as engine.EngineOk<engine.MoveResult>).value,
      prev,
      isPlayerMove: isPlayerMove,
    );
  }

  /// Shared tail of every engine transition (local, bot or remote): adopt
  /// the new state, adapt events for this client's board, count the move,
  /// then hand the turn back to the bot or wait for the friend.
  void _commitEngineMove(
    engine.MoveResult mr,
    engine.MatchState prev, {
    required bool isPlayerMove,
  }) {
    _state = mr.state;
    final events = _adapter!.adaptMove(mr, before: prev);
    final accepted = mr.hashAfter != mr.hashBefore;
    if (isPlayerMove && accepted) {
      _playerMoves++;
      _acceptedMoves++;
      if (_playerMoves >= 3) _markTutorialDone();
    } else if (!isPlayerMove && accepted) {
      _remoteMoves++;
    }
    _emit(events);
    if (_state!.isFinished) {
      _finishEngine();
      return;
    }
    if (!isOnline) _maybeBotTurn();
  }

  void _maybeBotTurn() {
    if (isOnline) return;
    final s = _state;
    if (s == null || s.isFinished || s.activePlayer != engine.PlayerSlot.second) {
      return;
    }
    _applyEngine(_bot!.choose(s), isPlayerMove: false);
  }

  // --- online duel ---------------------------------------------------------

  /// Subscribes to the session's verified move stream and the shared match
  /// record (flags, finals, forfeit claims). Runs from construction so
  /// moves played during the versus phase are already inside
  /// `session.state` when [_startOnline] adopts it.
  void _attachOnline() {
    final duel = online;
    if (duel == null) return;
    final session = duel.session;
    _onlineSubs.addAll(<StreamSubscription<dynamic>>[
      session.watch().listen(
        _onOnlineRecord,
        onError: (_) => _endOnline(OnlineAbort.connectionLost),
        onDone: () => unawaited(_syncOnline()),
      ),
      session.store.watchMatch(session.matchId).listen(
        (_) => unawaited(_evaluateOnlineRecord()),
        onError: (_) {},
      ),
    ]);
  }

  /// Plays this client's move through the session: the engine transition
  /// is computed locally for the event list, then appended to the shared
  /// log so the friend replays it identically. A rejected swap returns a
  /// `MoveResult` without touching the log — local UI feedback only.
  Future<void> _playOnline(engine.Move move) async {
    final duel = online;
    if (duel == null || _disposed) return;
    final session = duel.session;
    _busy = true;
    refresh();
    try {
      final mr = await session.play(move);
      if (_disposed || phase == MatchPhase.finished) return;
      _onlineCursor = session.movesApplied;
      _lastOnlineMoveAt = DateTime.now();
      _commitEngineMove(mr, _state!, isPlayerMove: true);
      unawaited(_syncOnline());
    } on MatchException {
      // The turn moved on underneath us (flag, forfeit or a refresh);
      // resync quietly instead of aborting.
      _busy = false;
      refresh();
      unawaited(_syncOnline());
      unawaited(_evaluateOnlineRecord());
    } on Object {
      _endOnline(OnlineAbort.connectionLost);
    }
  }

  /// One verified opponent move from `session.watch()`. Replayed through
  /// `arena_engine` for the animation events; the post-move hash is
  /// checked again locally — a mismatch flags the match (contract §7).
  void _onOnlineRecord(MoveRecord rec) {
    if (_disposed || phase == MatchPhase.finished || _state == null) return;
    if (rec.index < _onlineCursor) return;
    if (rec.index == _onlineCursor) {
      _applyOnlineRecord(rec);
    } else {
      // A gap: earlier accepted moves have not reached the shadow yet.
      unawaited(_syncOnline());
    }
  }

  void _applyOnlineRecord(MoveRecord rec) {
    final prev = _state!;
    final move = engine.Move.fromJson(rec.move);
    final res = move == null ? null : engine.applyMove(prev, move);
    final mr = res is engine.EngineOk<engine.MoveResult> ? res.value : null;
    if (mr == null || mr.hashAfter != rec.hashAfter) {
      _flagOnline();
      return;
    }
    _lastOnlineMoveAt = DateTime.now();
    _commitEngineMove(mr, prev, isPlayerMove: false);
    _onlineCursor++;
  }

  /// Replays every session-accepted move the shadow has not seen, in log
  /// order. Covers moves applied silently by `refresh()`/`poll()` and any
  /// gap the live watch stream skipped. Safe under concurrent triggers.
  Future<void> _syncOnline() async {
    final duel = online;
    if (duel == null || _disposed || _state == null) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        if (_disposed || phase == MatchPhase.finished) return;
        final session = duel.session;
        final target = session.movesApplied;
        if (_onlineCursor >= target) break;
        final log = await session.store.readMoves(session.matchId);
        if (_disposed || phase == MatchPhase.finished) return;
        final pending = [
          for (final m in log)
            if (m.index >= _onlineCursor && m.index < target) m,
        ]..sort((a, b) => a.index.compareTo(b.index));
        for (final rec in pending) {
          if (_disposed || phase == MatchPhase.finished) return;
          if (rec.index < _onlineCursor) continue;
          if (rec.index != _onlineCursor) {
            _flagOnline();
            return;
          }
          _applyOnlineRecord(rec);
        }
      } while (_syncAgain);
    } on Object {
      _endOnline(OnlineAbort.connectionLost);
    } finally {
      _syncing = false;
    }
  }

  /// Re-reads the match record after any store change: flags end the
  /// duel unscored, forfeit claims finish it, and finals settle rewards.
  Future<void> _evaluateOnlineRecord() async {
    final duel = online;
    if (duel == null || _disposed) return;
    final session = duel.session;
    try {
      await session.refresh();
    } on Object {
      return; // transient read failure; the poll timer retries
    }
    if (_disposed) return;
    unawaited(_syncOnline());
    if (session.flag != null || session.record.flag != null) {
      _flagOnline();
      return;
    }
    final winner = session.record.forfeitWinner;
    if (winner != null &&
        phase == MatchPhase.playing &&
        _state != null &&
        _state!.outcome == null) {
      _finishForfeit(winner);
      return;
    }
    if (phase == MatchPhase.finished && abortReason == null) {
      _settleOnlineRewards();
    }
  }

  /// Integrity failure on this client or a `MatchFlag` from either side:
  /// the match is over and awards nothing.
  void _flagOnline() {
    _localFlag = true;
    _endOnline(OnlineAbort.flagged);
  }

  /// Ends an online duel without scored rewards — flagged integrity
  /// failures and local aborts award nothing.
  void _endOnline(OnlineAbort reason) {
    if (_disposed || phase == MatchPhase.finished) return;
    abortReason = reason;
    _search?.cancel();
    _clock?.cancel();
    _pollTimer?.cancel();
    _onlineClock?.cancel();
    _busy = false;
    phase = MatchPhase.finished;
    refresh();
  }

  /// Surrender/leave. Local modes score a loss; online duels void the
  /// match locally (no rewards) — there is no resign move in the shared
  /// log, so the opponent's client simply stops hearing from this one and
  /// the 24-hour forfeit rule applies on their side.
  void forfeit() {
    if (isOnline) {
      _endOnline(OnlineAbort.surrendered);
    } else {
      finish(-1);
    }
  }

  /// Sends one preset emote to the online opponent; no-op for local modes.
  void sendEmote(Emote emote) {
    final duel = online;
    if (duel == null) return;
    duel.cloud
        .sendEmote(duel.session.matchId, duel.uid, emote)
        .ignore();
  }

  /// Catch-up after app resume: refresh the record, replay unseen moves.
  Future<void> refreshOnline() => _evaluateOnlineRecord();

  /// Claims the win when the opponent let the 24-hour limit pass.
  Future<void> claimForfeit() async {
    final duel = online;
    if (duel == null || _disposed || !canClaimForfeit) return;
    try {
      await duel.session.claimForfeit();
    } on Object {
      return;
    }
    await _evaluateOnlineRecord();
  }

  /// Awards the finished online result only once both phones wrote the
  /// same final (or a forfeit decided it) and nobody flagged the match —
  /// `session.counts`. Until then the result screen shows a pending note.
  void _settleOnlineRewards() {
    if (!isOnline || _rewardsSettled || abortReason != null) return;
    final session = online!.session;
    final record = session.record;
    final decided =
        session.flag != null ||
        record.flag != null ||
        record.finals.length == PlayerSlot.values.length ||
        record.forfeitWinner != null;
    if (!decided) {
      _settleTimer ??= Timer(const Duration(seconds: 20), () {
        _rewardsSettled = true;
        _rewardsCounted = false;
        refresh();
      });
      return;
    }
    _settleTimer?.cancel();
    _rewardsSettled = true;
    _rewardsCounted =
        session.flag == null &&
        record.flag == null &&
        (session.counts || record.forfeitWinner != null);
    if (_rewardsCounted) {
      player.result(result ?? 0);
    }
    refresh();
  }

  /// True while an online result waits for both finals (or a flag).
  bool get rewardsPending =>
      isOnline &&
      phase == MatchPhase.finished &&
      abortReason == null &&
      !_rewardsSettled;

  /// True once an online result settled and may award trophies/paws —
  /// both finals agreed (or a forfeit decided) and nobody flagged.
  bool get rewardsCounted => _rewardsCounted;

  void _finishForfeit(engine.PlayerSlot winner) {
    debugPrint('CPA duel finished: forfeit win for ${winner.name}');
    _finishOnline(winner == _localSlot ? 1 : -1);
  }

  /// Maps the engine outcome to this client's perspective: a guest
  /// (PlayerSlot.second) wins when the engine says secondWins.
  int _outcomeFor(engine.MatchOutcome? outcome) =>
      switch ((outcome, _localSlot)) {
        (engine.MatchOutcome.firstWins, engine.PlayerSlot.first) => 1,
        (engine.MatchOutcome.firstWins, engine.PlayerSlot.second) => -1,
        (engine.MatchOutcome.secondWins, engine.PlayerSlot.first) => -1,
        (engine.MatchOutcome.secondWins, engine.PlayerSlot.second) => 1,
        _ => 0,
      };

  void _finishEngine() {
    final outcome = _outcomeFor(_state!.outcome);
    final secs = _matchStart == null
        ? 0
        : DateTime.now().difference(_matchStart!).inSeconds;
    debugPrint(
      'CPA duel finished: ${_acceptedMoves + _remoteMoves} moves, '
      '${secs}s, ${isOnline ? 'online' : 'botLevel=$botLevel'}, '
      'seed=$seed, outcome=$outcome',
    );
    if (isOnline) {
      _finishOnline(outcome);
    } else {
      finish(outcome);
    }
  }

  /// Ends an online duel on a scored outcome. Rewards are deferred to
  /// [_settleOnlineRewards] — they are only awarded once both phones'
  /// finals agree (or a forfeit decided the match) and nobody flagged it.
  void _finishOnline(int outcome) {
    _search?.cancel();
    _clock?.cancel();
    _pollTimer?.cancel();
    _onlineClock?.cancel();
    _busy = false;
    result = outcome;
    phase = MatchPhase.finished;
    _settleOnlineRewards();
    refresh();
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
  /// (legacy). Goes back through the VS phase. Online duels cannot
  /// rematch locally — a rematch is a new match record (contract §3), so
  /// the button is hidden and this is a no-op for them.
  void rematch() {
    if (_disposed || phase != MatchPhase.finished || isOnline) return;
    _search?.cancel();
    _clock?.cancel();
    if (isEngine) {
      _seed = Random().nextInt(1 << 30);
      _state = null;
      _adapter = null;
      _playerMoves = 0;
      _acceptedMoves = 0;
      _remoteMoves = 0;
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
    if (_disposed) return;
    _disposed = true;
    _search?.cancel();
    _clock?.cancel();
    _pollTimer?.cancel();
    _onlineClock?.cancel();
    _settleTimer?.cancel();
    for (final sub in _onlineSubs) {
      sub.cancel();
    }
    _onlineSubs.clear();
    super.dispose();
  }
}
