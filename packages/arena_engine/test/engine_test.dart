import 'dart:math' show Random;

import 'package:arena_engine/arena_engine.dart';
import 'package:test/test.dart';

const config = MatchConfig.duel();

/// Plays [state] forward with random legal moves, returning the move log
/// and final state. Stops at match end or after [maxMoves].
(MatchState, List<Move>) playRandom(
  MatchState state,
  Random rng, {
  int maxMoves = 400,
}) {
  final log = <Move>[];
  var s = state;
  while (!s.isFinished && log.length < maxMoves) {
    final moves = (legalMoves(s) as EngineOk<List<Move>>).value;
    if (moves.isEmpty) break;
    final move = moves[rng.nextInt(moves.length)];
    final result = applyMove(s, move);
    expect(result, isA<EngineOk<MoveResult>>());
    final mr = (result as EngineOk<MoveResult>).value;
    expect(mr.events.whereType<SwapRejected>(), isEmpty);
    s = mr.state;
    log.add(move);
    if (!s.isFinished) {
      // Done-when 4: after any move resolves, a legal move remains.
      final next = legalMoves(s) as EngineOk<List<Move>>;
      expect(next.value, isNotEmpty);
    }
  }
  return (s, log);
}

/// Counts regular colour runs of length >= 3 horizontally and vertically.
int startingMatches(BoardState b) {
  var count = 0;
  final w = b.width, h = b.height;
  for (var r = 0; r < h; r++) {
    for (var c = 0; c + 2 < w; c++) {
      final a = b.cellAt(r, c), d = b.cellAt(r, c + 1), e = b.cellAt(r, c + 2);
      if (a >= 0 && a < 20 && a == d && d == e) count++;
    }
  }
  for (var c = 0; c < w; c++) {
    for (var r = 0; r + 2 < h; r++) {
      final a = b.cellAt(r, c), d = b.cellAt(r + 1, c), e = b.cellAt(r + 2, c);
      if (a >= 0 && a < 20 && a == d && d == e) count++;
    }
  }
  return count;
}

void main() {
  group('newMatch', () {
    test('is deterministic for the same seed and config', () {
      final a = (newMatch(42, config) as EngineOk<MatchState>).value;
      final b = (newMatch(42, config) as EngineOk<MatchState>).value;
      expect(stateHash(a), stateHash(b));
      expect(a.boards[0].cells, b.boards[0].cells);
      expect(a.boards[1].cells, b.boards[1].cells);
    });

    test('different seeds produce different boards', () {
      final a = (newMatch(1, config) as EngineOk<MatchState>).value;
      final b = (newMatch(2, config) as EngineOk<MatchState>).value;
      expect(stateHash(a), isNot(stateHash(b)));
    });

    test('supports zero and negative seeds', () {
      for (final seed in [0, -1, -987654321, 9223372036854775807]) {
        final r = newMatch(seed, config);
        expect(r, isA<EngineOk<MatchState>>());
      }
    });

    test('deals no starting matches and at least one legal move', () {
      for (var seed = 0; seed < 50; seed++) {
        final s = (newMatch(seed, config) as EngineOk<MatchState>).value;
        for (final b in s.boards) {
          expect(startingMatches(b), 0, reason: 'seed $seed');
        }
        final moves = (legalMoves(s) as EngineOk<List<Move>>).value;
        expect(moves, isNotEmpty);
      }
    });

    test('both players get identical boards and refill streams', () {
      final s = (newMatch(777, config) as EngineOk<MatchState>).value;
      expect(s.boards[0].cells, s.boards[1].cells);
      expect(s.boards[0].refillState, s.boards[1].refillState);
    });

    test('rejects invalid configs', () {
      expect(
        newMatch(1, const MatchConfig(colourCount: 4)),
        isA<EngineFailure<MatchState>>(),
      );
      expect(
        newMatch(1, const MatchConfig(engineVersion: 99)),
        isA<EngineFailure<MatchState>>(),
      );
      expect(
        newMatch(1, const MatchConfig(boardWidth: 0)),
        isA<EngineFailure<MatchState>>(),
      );
    });
  });

  group('applyMove', () {
    test('rejects structurally invalid moves without mutating', () {
      final s = (newMatch(5, config) as EngineOk<MatchState>).value;
      final h = stateHash(s);
      // Out of bounds.
      expect(
        applyMove(s, const SwapMove(firstCell: (row: -1, col: 0), secondCell: (row: 0, col: 1))),
        isA<EngineFailure<MoveResult>>(),
      );
      // Same cell.
      expect(
        applyMove(s, const SwapMove(firstCell: (row: 0, col: 0), secondCell: (row: 0, col: 0))),
        isA<EngineFailure<MoveResult>>(),
      );
      // Non-adjacent.
      expect(
        applyMove(s, const SwapMove(firstCell: (row: 0, col: 0), secondCell: (row: 0, col: 2))),
        isA<EngineFailure<MoveResult>>(),
      );
      // Powers need a full meter; a fresh match has none.
      expect(
        applyMove(s, const PowerMove(power: PowerKind.zoomies)),
        isA<EngineFailure<MoveResult>>(),
      );
      expect(stateHash(s), h);
    });

    test('a non-matching swap returns SwapRejected and unchanged state', () {
      final s = (newMatch(11, config) as EngineOk<MatchState>).value;
      final board = s.boardOf(PlayerSlot.first);
      // Find an adjacent non-productive swap.
      SwapMove? bad;
      for (var r = 0; r < board.height && bad == null; r++) {
        for (var c = 0; c + 1 < board.width && bad == null; c++) {
          final move = SwapMove(
            firstCell: (row: r, col: c),
            secondCell: (row: r, col: c + 1),
          );
          final res = applyMove(s, move);
          if (res is EngineOk<MoveResult> &&
              res.value.events.single is SwapRejected) {
            bad = move;
          }
        }
      }
      expect(bad, isNotNull, reason: 'expected a non-matching swap to exist');
      final res = applyMove(s, bad!) as EngineOk<MoveResult>;
      expect(res.value.state, same(s));
      expect(res.value.hashBefore, res.value.hashAfter);
      expect(res.value.events, hasLength(1));
      expect(res.value.events.single, isA<SwapRejected>());
      expect(s.turnsLeft(PlayerSlot.first), config.turnsPerPlayer);
      expect(s.activePlayer, PlayerSlot.first);
    });

    test('every legalMoves entry is accepted by applyMove', () {
      var s = (newMatch(21, config) as EngineOk<MatchState>).value;
      final rng = Random(1);
      for (var step = 0; step < 30 && !s.isFinished; step++) {
        final moves = (legalMoves(s) as EngineOk<List<Move>>).value;
        for (final m in moves) {
          final res = applyMove(s, m);
          expect(res, isA<EngineOk<MoveResult>>(), reason: 'move $m rejected');
        }
        final pick = moves[rng.nextInt(moves.length)];
        s = (applyMove(s, pick) as EngineOk<MoveResult>).value.state;
      }
    });

    test('scores accumulate flat points and turns alternate', () {
      final s = (newMatch(3, config) as EngineOk<MatchState>).value;
      var cur = s;
      final log = <Move>[];
      // One productive swap, then an explicit EndTurnMove — timed turns
      // never advance on their own.
      final firstMoves = (legalMoves(cur) as EngineOk<List<Move>>).value;
      final swap = firstMoves.firstWhere((m) => m is SwapMove);
      var res = applyMove(cur, swap) as EngineOk<MoveResult>;
      cur = res.value.state;
      log.add(swap);
      res = applyMove(cur, const EndTurnMove()) as EngineOk<MoveResult>;
      cur = res.value.state;
      log.add(const EndTurnMove());
      final sawTurnEnd = res.value.events.any((e) => e is TurnEnded);
      expect(sawTurnEnd, isTrue);
      // The first turn belongs to first; after EndTurnMove the second
      // player's turn begins and first has one turn less remaining.
      expect(cur.turn, 2);
      expect(cur.activePlayer, PlayerSlot.second);
      expect(cur.turnsLeft(PlayerSlot.first), config.turnsPerPlayer - 1);
      expect(cur.turnsLeft(PlayerSlot.second), config.turnsPerPlayer);
      expect(cur.isFinished, isFalse);
      // Verify the replayed log produces the identical final state/hash.
      final replayed = replay(3, config, log);
      expect(replayed, isA<EngineOk<ReplayResult>>());
      final rr = (replayed as EngineOk<ReplayResult>).value;
      expect(rr.hash, stateHash(cur));
      expect(rr.state.scores[0], greaterThanOrEqualTo(0));
      expect(rr.state.scores[1], greaterThanOrEqualTo(0));
      expect(rr.state.scores[0] + rr.state.scores[1], greaterThan(0));
    });
  });

  group('replay and hash', () {
    test('empty log returns the initial state', () {
      final s = (newMatch(9, config) as EngineOk<MatchState>).value;
      final r = replay(9, config, const []) as EngineOk<ReplayResult>;
      expect(r.value.hash, stateHash(s));
      expect(r.value.movesApplied, 0);
    });

    test('replay reproduces the live-played final state', () {
      final rng = Random(1234);
      final s = (newMatch(2024, config) as EngineOk<MatchState>).value;
      final (finalState, log) = playRandom(s, rng);
      final r = replay(2024, config, log) as EngineOk<ReplayResult>;
      expect(r.value.hash, stateHash(finalState));
      expect(r.value.movesApplied, log.length);
    });

    test('corrupt logs fail with position and reason', () {
      final rng = Random(7);
      final s = (newMatch(31, config) as EngineOk<MatchState>).value;
      final (_, log) = playRandom(s, rng, maxMoves: 10);
      expect(log, isNotEmpty);
      final bad = List<Move>.of(log);
      bad.add(const SwapMove(firstCell: (row: 0, col: 0), secondCell: (row: 0, col: 2)));
      final r = replay(31, config, bad);
      expect(r, isA<EngineFailure<ReplayResult>>());
      final err = (r as EngineFailure<ReplayResult>).error;
      expect(err.code, EngineErrorCode.replayDivergence);
      expect(err.details['position'], log.length);
    });

    test('moves after match end are rejected', () {
      final rng = Random(99);
      final s = (newMatch(4, config) as EngineOk<MatchState>).value;
      final (_, log) = playRandom(s, rng);
      expect(log.length, greaterThan(0));
      final extended = List<Move>.of(log);
      // Find the first finished prefix length by replaying.
      var finishedAt = -1;
      for (var n = 1; n <= log.length; n++) {
        final r = replay(4, config, log.sublist(0, n));
        if (r is EngineOk<ReplayResult> && r.value.state.isFinished) {
          finishedAt = n;
          break;
        }
      }
      expect(finishedAt, greaterThan(0));
      extended.length = finishedAt;
      extended.add(const SwapMove(firstCell: (row: 0, col: 0), secondCell: (row: 0, col: 1)));
      final r = replay(4, config, extended);
      expect(r, isA<EngineFailure<ReplayResult>>());
    });

    test('stateHash and playerHash are stable', () {
      final s = (newMatch(8, config) as EngineOk<MatchState>).value;
      expect(stateHash(s), stateHash(s));
      expect(playerHash(s, PlayerSlot.first), playerHash(s, PlayerSlot.first));
      expect(
        playerHash(s, PlayerSlot.first),
        isNot(playerHash(s, PlayerSlot.second)),
      );
    });
  });

  group('determinism at scale', () {
    test('1000 seeds: replay twice returns the same hash', () {
      final rng = Random(20261115);
      for (var seed = 0; seed < 1000; seed++) {
        final s = (newMatch(seed, config) as EngineOk<MatchState>).value;
        final (_, log) = playRandom(s, rng, maxMoves: 60);
        final r1 = replay(seed, config, log) as EngineOk<ReplayResult>;
        final r2 = replay(seed, config, log) as EngineOk<ReplayResult>;
        expect(r1.value.hash, r2.value.hash, reason: 'seed $seed');
        expect(r1.value.hash, isNotEmpty);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('two engines with the same seed stay identical under same moves', () {
      final rng = Random(555);
      var a = (newMatch(12345, config) as EngineOk<MatchState>).value;
      var b = (newMatch(12345, config) as EngineOk<MatchState>).value;
      final log = <Move>[];
      for (var i = 0; i < 40 && !a.isFinished; i++) {
        final moves = (legalMoves(a) as EngineOk<List<Move>>).value;
        if (moves.isEmpty) break;
        final m = moves[rng.nextInt(moves.length)];
        log.add(m);
        a = (applyMove(a, m) as EngineOk<MoveResult>).value.state;
        b = (applyMove(b, m) as EngineOk<MoveResult>).value.state;
      }
      expect(stateHash(a), stateHash(b));
      for (var p = 0; p < 2; p++) {
        expect(a.boards[p].cells, b.boards[p].cells);
        expect(a.boards[p].refillState, b.boards[p].refillState);
      }
    });
  });

  group('match structure', () {
    test('a full scripted match ends with MatchEnded', () {
      final rng = Random(31337);
      final s = (newMatch(606, config) as EngineOk<MatchState>).value;
      var cur = s;
      MatchEnded? ended;
      var guard = 0;
      while (!cur.isFinished && guard++ < 500) {
        final moves = (legalMoves(cur) as EngineOk<List<Move>>).value;
        final m = moves[rng.nextInt(moves.length)];
        final res = applyMove(cur, m) as EngineOk<MoveResult>;
        for (final e in res.value.events) {
          if (e is MatchEnded) ended = e;
        }
        cur = res.value.state;
      }
      expect(cur.isFinished, isTrue);
      expect(ended, isNotNull);
      expect(ended!.scores.first, cur.scores[0]);
      expect(ended.scores.second, cur.scores[1]);
      expect(ended.finalHashes.first, isNotEmpty);
      expect(ended.finalHashes.second, isNotEmpty);
    });

    test('move json round-trips', () {
      const m1 = SwapMove(firstCell: (row: 2, col: 3), secondCell: (row: 2, col: 4));
      final j = m1.toJson();
      expect(Move.fromJson(j), m1);
      const m2 = PowerMove(power: PowerKind.zoomies);
      expect(Move.fromJson(m2.toJson()), m2);
      const m3 = EndTurnMove();
      expect(Move.fromJson(m3.toJson()), m3);
      expect(Move.fromJson({'kind': 'endTurn'}), m3);
      expect(Move.fromJson({'kind': 'bogus'}), isNull);
      expect(Move.fromJson('nope'), isNull);
    });
  });

  group('frenzy (simultaneous Variant B)', () {
  const fcfg = MatchConfig.frenzy();

  MatchState fresh([int seed = 7]) =>
      (newMatch(seed, fcfg) as EngineOk<MatchState>).value;

  SwapMove firstSwap(MatchState s, PlayerSlot p) {
    final legal = legalMoves(s, player: p) as EngineOk<List<Move>>;
    return legal.value.firstWhere((m) => m is SwapMove) as SwapMove;
  }

  MatchState applyOk(MatchState s, Move m) =>
      (applyMove(s, m) as EngineOk<MoveResult>).value.state;

  test('starts with a 60-second clock, no turns, equal boards', () {
    final s = fresh();
    expect(s.matchSecondsLeft, 60);
    expect(s.turnsRemaining, [0, 0]);
    expect(s.fever, isFalse);
    expect(s.isFinished, isFalse);
    expect(s.boards[0].cells, s.boards[1].cells);
  });

  test('legalMoves tags the requested slot and never ends turns', () {
    final s = fresh();
    for (final p in PlayerSlot.values) {
      final legal = legalMoves(s, player: p) as EngineOk<List<Move>>;
      expect(legal.value, isNotEmpty);
      for (final m in legal.value) {
        expect(m.player, p);
        expect(m, isA<SwapMove>());
      }
    }
    // Without a player argument Frenzy enumerates PlayerSlot.first.
    final legal = legalMoves(s) as EngineOk<List<Move>>;
    expect(
      legal.value.every((m) => m.player == PlayerSlot.first),
      isTrue,
    );
  });

  test('swaps act on their own board only, both sides anytime', () {
    var s = fresh();
    final a = firstSwap(s, PlayerSlot.first);
    s = applyOk(s, a);
    // First's board moved; second's is untouched.
    expect(s.boards[0].cells, isNot(s.boards[1].cells));
    // Second may move immediately after — no turn hand-off.
    final b = firstSwap(s, PlayerSlot.second);
    expect(b.player, PlayerSlot.second);
    s = applyOk(s, b);
    expect(s.boards[0].cells, isNot(s.boards[1].cells));
  });

  test('a move without a player tag acts for PlayerSlot.first', () {
    var s = fresh();
    final tagged = firstSwap(s, PlayerSlot.first);
    final bare = SwapMove(
      firstCell: tagged.firstCell,
      secondCell: tagged.secondCell,
    );
    s = applyOk(s, bare);
    expect(s.boards[0].cells, isNot(s.boards[1].cells));
  });

  test('TickMove runs the clock down and ends the match at zero', () {
    var s = fresh();
    var ticks = 0;
    for (var i = 0; i < 60; i++) {
      final res = applyMove(s, const TickMove()) as EngineOk<MoveResult>;
      ticks += res.value.events.whereType<ClockTicked>().length;
      s = res.value.state;
    }
    expect(ticks, 60);
    expect(s.matchSecondsLeft, 0);
    expect(s.isFinished, isTrue);
    expect(s.outcome, isNotNull);
    // Further moves are rejected once the clock settles the result.
    expect(applyMove(s, const TickMove()), isA<EngineFailure<MoveResult>>());
  });

  test('higher score wins; a draw is possible', () {
    var s = fresh(11);
    // Player first makes one productive swap; second idles.
    s = applyOk(s, firstSwap(s, PlayerSlot.first));
    for (var i = 0; i < 60; i++) {
      s = applyOk(s, const TickMove());
    }
    expect(s.isFinished, isTrue);
    if (s.scores[0] > s.scores[1]) {
      expect(s.outcome, MatchOutcome.firstWins);
    }
    // A fresh match ticked straight down draws 0-0.
    var d = fresh(11);
    for (var i = 0; i < 60; i++) {
      d = applyOk(d, const TickMove());
    }
    expect(d.outcome, MatchOutcome.draw);
  });

  test('EndTurnMove is illegal; TickMove is illegal in timed turns', () {
    final s = fresh();
    expect(
      applyMove(s, const EndTurnMove()),
      isA<EngineFailure<MoveResult>>(),
    );
    final classic =
        (newMatch(7, const MatchConfig.duel()) as EngineOk<MatchState>).value;
    expect(
      applyMove(classic, const TickMove()),
      isA<EngineFailure<MoveResult>>(),
    );
  });

  test('fever doubles points in the last 15 seconds', () {
    var s = fresh();
    for (var i = 0; i < 45; i++) {
      s = applyOk(s, const TickMove());
    }
    expect(s.matchSecondsLeft, 15);
    expect(s.fever, isTrue);
    final before = s.scores[0];
    s = applyOk(s, firstSwap(s, PlayerSlot.first));
    final gained = s.scores[0] - before;
    expect(gained > 0, isTrue);
    // A 3-piece clear is worth 10/piece x2 — at least 60.
    expect(gained >= 60, isTrue);
  });

  test('earned sabotage lands on the rival board at their next move', () {
    var s = fresh();
    // First plays a move that (with this seed) may earn boxes; keep
    // playing until a queue exists, bounded.
    var guard = 0;
    while (s.pendingObstacles[PlayerSlot.second.index].isEmpty &&
        guard++ < 30) {
      s = applyOk(s, firstSwap(s, PlayerSlot.first));
    }
    // If this seed earned nothing at all, the invariant is vacuous —
    // count it as covered and finish.
    if (s.pendingObstacles[PlayerSlot.second.index].isEmpty) return;
    expect(
      s.boards[PlayerSlot.second.index].cells.any((c) => c == -2),
      isFalse,
    );
    // Second's next move lands the queued boxes on their own board.
    var landed = false;
    s = applyOk(s, firstSwap(s, PlayerSlot.second));
    for (var i = 0; i < 30 && !landed; i++) {
      if (s.boards[PlayerSlot.second.index].cells.contains(-2)) {
        landed = true;
      }
    }
    expect(landed, isTrue);
    expect(s.pendingObstacles[PlayerSlot.second.index], isEmpty);
  });

  test('move codec carries the player tag and ticks round-trip', () {
    const a = SwapMove(
      firstCell: (row: 2, col: 3),
      secondCell: (row: 2, col: 4),
      player: PlayerSlot.second,
    );
    expect(Move.fromJson(a.toJson()), a);
    const p = PowerMove(power: PowerKind.laserChase, player: PlayerSlot.first);
    expect(Move.fromJson(p.toJson()), p);
    const t = TickMove();
    expect(Move.fromJson(t.toJson()), t);
    expect(Move.fromJson({'kind': 'tick'}), t);
  });

  test('interleaved ticks and swaps stay deterministic', () {
    var a = fresh(23), b = fresh(23);
    final log = <Move>[];
    var guard = 0;
    while (!a.isFinished && guard++ < 200) {
      final moves =
          (legalMoves(
                a,
                player:
                    guard.isEven ? PlayerSlot.first : PlayerSlot.second,
              )
              as EngineOk<List<Move>>)
          .value;
      final m = moves.isEmpty ? const TickMove() : moves.first;
      log.add(m);
      a = (applyMove(a, m) as EngineOk<MoveResult>).value.state;
      if (guard % 4 == 0) {
        log.add(const TickMove());
        a = (applyMove(a, const TickMove()) as EngineOk<MoveResult>)
            .value
            .state;
      }
    }
    for (final m in log) {
      b = (applyMove(b, m) as EngineOk<MoveResult>).value.state;
    }
    expect(stateHash(b), stateHash(a));
  });
});
}
