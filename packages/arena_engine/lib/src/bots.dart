/// Deterministic bots for practice matches and the luck harness.
///
/// A bot only ever sees [MatchState] and returns one of its legal moves.
/// Bots are pure: randomness comes from an injected [GameRandom] stream,
/// so a seeded bot plays the same game on every platform.
library;

import 'board.dart';
import 'engine.dart';

/// A deterministic move chooser.
abstract class ArenaBot {
  const ArenaBot();

  /// Display/preset-safe label for logs and reports.
  String get label;

  /// Picks one of [legalMoves]' entries for the active player.
  Move chooseMove(MatchState state);
}

List<Move> _moves(MatchState state) =>
    (legalMoves(state) as EngineOk<List<Move>>).value;

/// How many swaps/powers a bot plays before handing the turn back.
/// Timed turns allow unlimited moves, so bots budget themselves to keep
/// matches lively and deterministic.
int _turnBudget(ArenaBot bot) => switch (bot) {
  RandomBot() => 5,
  GreedyBot() => 8,
  LookaheadBot() => 8,
  PowerBot() => 8,
  _ => 6,
};

/// Ends the turn when the bot's budget is spent or no productive move
/// remains; otherwise returns [pick]'s choice among the real moves.
Move _withinTurn(MatchState state, ArenaBot bot, Move Function() pick) {
  final playable = [
    for (final m in _moves(state))
      if (m is! EndTurnMove) m,
  ];
  if (playable.isEmpty || state.turnMoves >= _turnBudget(bot)) {
    return const EndTurnMove();
  }
  return pick();
}

/// Uniform random legal move. [rng] is the bot's own stream; seed it
/// differently per match side for independent play.
final class RandomBot extends ArenaBot {
  final GameRandom rng;

  RandomBot([int seed = 0]) : rng = GameRandom(seed);

  @override
  String get label => 'random';

  @override
  Move chooseMove(MatchState state) {
    return _withinTurn(state, this, () {
      final playable = [
        for (final m in _moves(state))
          if (m is! EndTurnMove) m,
      ];
      return playable[rng.nextInt(playable.length)];
    });
  }
}

/// Scores a swap by simulating it on a scratch board and counting the
/// first-wave matched cells (special anchors still count: they become
/// pieces). Powers are scored by their real resolution instead.
double _swapEstimate(MatchState state, SwapMove move, int w) {
  final board = MutableBoard.fromState(state.boardOf(state.activePlayer));
  final a = move.firstCell.row * w + move.firstCell.col;
  final b = move.secondCell.row * w + move.secondCell.col;
  final tmp = board.cells[a];
  board.cells[a] = board.cells[b];
  board.cells[b] = tmp;
  final groups = scanMatches(board);
  if (groups.isEmpty) {
    // Involves a special: the blast is worth roughly a row/column/3x3.
    return isSpecialCode(board.cells[a]) || isSpecialCode(board.cells[b])
        ? 60.0
        : 0.0;
  }
  var cells = 0, specials = 0;
  for (final g in groups) {
    cells += g.cells.length;
    if (g.isBent || g.cells.length >= 4) specials++;
  }
  return cells * 10.0 + specials * 25.0;
}

/// Actual points a move produces, from the resulting event stream.
double _movePoints(MoveResult res, PlayerSlot p) {
  var pts = 0.0;
  for (final e in res.events) {
    if (e is Cleared && e.player == p) pts += e.points;
    if (e is SpecialFired && e.player == p) pts += e.points;
    if (e is PowerFired && e.player == p) pts += e.points;
  }
  return pts;
}

/// Cheap analytic estimate of a power's immediate points, used for
/// ranking candidates without a full resolution.
double _powerEstimate(MatchState state, PowerMove move) {
  final board = state.boardOf(state.activePlayer);
  final w = board.width;
  switch (move.power) {
    case PowerKind.zoomies:
      var best = 0;
      for (var r = 0; r < board.height; r++) {
        var n = 0;
        for (var c = 0; c < w; c++) {
          if (isPieceCode(board.cells[r * w + c])) n++;
        }
        if (n > best) best = n;
      }
      return best * 10.0;
    case PowerKind.shadowPounce:
      final counts = List<int>.filled(kPieceColours, 0);
      for (final code in board.cells) {
        if (isColourCode(code)) counts[basePieceCode(code)]++;
      }
      return counts.reduce((a, b) => a > b ? a : b) * 10.0;
    case PowerKind.laserChase:
      final n = board.cells.where(isPieceCode).length;
      return (n < kLaserBreakCount ? n : kLaserBreakCount) * 10.0;
  }
}

/// Picks the move with the largest immediate clear ("largest first
/// clear"). Swap candidates are scored by first-wave match size on a
/// scratch board; the power candidate is scored by its real resolution.
/// Deterministic: ties keep the earliest move in [legalMoves] order.
final class GreedyBot extends ArenaBot {
  const GreedyBot();

  @override
  String get label => 'greedy';

  @override
  Move chooseMove(MatchState state) {
    final w = state.boardOf(state.activePlayer).width;
    return _withinTurn(state, this, () {
      Move best = const SwapMove(
        firstCell: (row: 0, col: 0),
        secondCell: (row: 0, col: 1),
      );
      var bestScore = -1.0;
      var found = false;
      for (final m in _moves(state)) {
        if (m is EndTurnMove) continue;
        final double score;
        if (m is SwapMove) {
          score = _swapEstimate(state, m, w);
        } else {
          final res = applyMove(state, m);
          score = res is EngineOk<MoveResult>
              ? _movePoints(res.value, state.activePlayer)
              : -1;
        }
        if (!found || score > bestScore) {
          found = true;
          bestScore = score;
          best = m;
        }
      }
      return found ? best : const EndTurnMove();
    });
  }
}

/// Board evaluation for the lookahead bot: score difference dominates,
/// then mobility, own specials and charge.
double _evaluate(MatchState state, PlayerSlot player) {
  final me = state.scoreOf(player);
  final them = state.scoreOf(player.other);
  var v = (me - them) * 4.0;
  final board = MutableBoard.fromState(state.boardOf(player));
  v += legalSwapPairs(board).length * 1.5;
  var specials = 0;
  for (final code in board.cells) {
    if (isSpecialCode(code)) specials++;
  }
  v += specials * 6.0;
  v += state.chargeOf(player) * 0.05;
  if (state.isFinished) {
    v += switch (state.outcome) {
      MatchOutcome.firstWins when player == PlayerSlot.first => 500,
      MatchOutcome.secondWins when player == PlayerSlot.second => 500,
      MatchOutcome.draw => 0,
      _ => -500,
    };
  }
  return v;
}

/// One-ply lookahead: tries the top [ownTopK] moves by quick estimate,
/// answers each with the opponent's best quick-estimate reply, and picks
/// the move whose resulting position evaluates best. Deterministic.
final class LookaheadBot extends ArenaBot {
  final int ownTopK;
  final int replyTopK;

  const LookaheadBot({this.ownTopK = 6, this.replyTopK = 4});

  @override
  String get label => 'lookahead';

  double _quickScore(MatchState state, Move m) {
    if (m is SwapMove) {
      return _swapEstimate(
        state,
        m,
        state.boardOf(state.activePlayer).width,
      );
    }
    if (m is PowerMove) return _powerEstimate(state, m);
    return -1;
  }

  List<Move> _topMoves(MatchState state, int k) {
    final scored = [
      for (final m in _moves(state))
        if (m is! EndTurnMove) (m, _quickScore(state, m)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (m, _) in scored.take(k)) m];
  }

  @override
  Move chooseMove(MatchState state) {
    return _withinTurn(state, this, () {
      final me = state.activePlayer;
      Move? best;
      var bestValue = double.negativeInfinity;
      for (final m in _topMoves(state, ownTopK)) {
        final res = applyMove(state, m);
        if (res is! EngineOk<MoveResult>) continue;
        var next = res.value.state;
        // Opponent replies with their best quick move (bounded).
        if (!next.isFinished) {
          final replies = _topMoves(next, replyTopK);
          if (replies.isNotEmpty) {
            final res2 = applyMove(next, replies.first);
            if (res2 is EngineOk<MoveResult>) next = res2.value.state;
          }
        }
        final value = _evaluate(next, me);
        if (value > bestValue) {
          bestValue = value;
          best = m;
        }
      }
      return best ?? const EndTurnMove();
    });
  }
}

/// A bot that fires its configured power whenever the meter is full and
/// the burst beats the best swap, and otherwise plays swap-only greedy.
/// In timed turns each cat has exactly one power ([MatchConfig.powerFor]);
/// this bot fires whatever power the match config gives it.
final class PowerBot extends ArenaBot {
  const PowerBot();

  @override
  String get label => 'power';

  @override
  Move chooseMove(MatchState state) {
    final moves = _moves(state);
    final w = state.boardOf(state.activePlayer).width;
    final slot = state.activePlayer;

    return _withinTurn(state, this, () {
      // Best swap by first-wave estimate.
      Move? bestSwap;
      var bestSwapScore = -1.0;
      for (final m in moves) {
        if (m is! SwapMove) continue;
        final score = _swapEstimate(state, m, w);
        if (score > bestSwapScore) {
          bestSwapScore = score;
          bestSwap = m;
        }
      }
      if (bestSwap == null) return const EndTurnMove();

      // Fire the cat's power only when its estimate beats the best swap.
      if (state.canFirePower(slot)) {
        final est = _powerEstimate(
          state,
          PowerMove(power: state.config.powerFor(slot)),
        );
        if (est >= bestSwapScore) {
          return PowerMove(power: state.config.powerFor(slot));
        }
      }
      return bestSwap;
    });
  }
}

/// House-cat difficulty levels built from the three bots.
enum HouseCatLevel {
  /// Random legal moves.
  easy,

  /// Largest-first-clear greedy.
  medium,

  /// One-ply lookahead.
  hard,
}

/// Builds the bot for a house-cat [level]. [seed] only matters for the
/// random level; pass a per-match value so games vary.
ArenaBot botForLevel(HouseCatLevel level, [int seed = 0]) => switch (level) {
  HouseCatLevel.easy => RandomBot(seed),
  HouseCatLevel.medium => const GreedyBot(),
  HouseCatLevel.hard => const LookaheadBot(),
};
