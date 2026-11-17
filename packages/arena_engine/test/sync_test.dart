import 'dart:math' show Random;

import 'package:arena_engine/arena_engine.dart';
import 'package:test/test.dart';

const config = MatchConfig.duel();

/// Plays a full match with [rng]-driven legal moves, collecting
/// [MoveLogEntry] records exactly as an online client would write them:
/// contiguous index, the move and the post-move state hash.
(List<MoveLogEntry>, MatchState) playLogged(
  int seed,
  Random rng, {
  MatchConfig cfg = config,
}) {
  var state = (newMatch(seed, cfg) as EngineOk<MatchState>).value;
  final entries = <MoveLogEntry>[];
  while (!state.isFinished && entries.length < 600) {
    final moves = (legalMoves(state) as EngineOk<List<Move>>).value;
    if (moves.isEmpty) break;
    final move = moves[rng.nextInt(moves.length)];
    final res = applyMove(state, move);
    expect(res, isA<EngineOk<MoveResult>>());
    final mr = (res as EngineOk<MoveResult>).value;
    expect(mr.events.whereType<SwapRejected>(), isEmpty);
    entries.add(
      MoveLogEntry(index: entries.length, move: move, hashAfter: mr.hashAfter),
    );
    state = mr.state;
  }
  return (entries, state);
}

void main() {
  group('MatchConfig json', () {
    test('round-trips the duel config', () {
      final json = config.toJson();
      final back = MatchConfig.fromJson(json);
      expect(back, config);
      expect(back!.fingerprint, config.fingerprint);
    });

    test('round-trips a non-default config', () {
      const custom = MatchConfig(
        boardWidth: 8,
        boardHeight: 6,
        colourCount: 6,
        turnsPerPlayer: 3,
        turnSeconds: 12,
        rainbowRule: RainbowRule.removeRandomPieces,
        engineVersion: kEngineVersion,
        powerConfiguration: PowerRuleset.threeFreeEqual,
        firstPower: PowerKind.laserChase,
        secondPower: PowerKind.shadowPounce,
      );
      expect(MatchConfig.fromJson(custom.toJson()), custom);
    });

    test('rejects malformed configs instead of defaulting', () {
      expect(MatchConfig.fromJson(null), isNull);
      expect(MatchConfig.fromJson('duel'), isNull);
      expect(MatchConfig.fromJson(const {'boardWidth': 7}), isNull);
      final missing = Map<String, Object?>.of(config.toJson())
        ..remove('colourCount');
      expect(MatchConfig.fromJson(missing), isNull);
      final badType = Map<String, Object?>.of(config.toJson())
        ..['turnsPerPlayer'] = 'five';
      expect(MatchConfig.fromJson(badType), isNull);
      final badEnum = Map<String, Object?>.of(config.toJson())
        ..['rainbowRule'] = 'explode';
      expect(MatchConfig.fromJson(badEnum), isNull);
      final badPower = Map<String, Object?>.of(config.toJson())
        ..['powerConfiguration'] = 'paidPowers';
      expect(MatchConfig.fromJson(badPower), isNull);
    });

    test('decoded config still goes through newMatch validation', () {
      final json = Map<String, Object?>.of(config.toJson())
        ..['colourCount'] = 4;
      final decoded = MatchConfig.fromJson(json)!;
      final res = newMatch(1, decoded);
      expect(res, isA<EngineFailure<MatchState>>());
      expect(
        (res as EngineFailure<MatchState>).error.code,
        EngineErrorCode.invalidConfig,
      );
    });
  });

  group('MoveLogEntry json', () {
    test('round-trips swap and power moves', () {
      const swap = SwapMove(
        firstCell: (row: 0, col: 0),
        secondCell: (row: 0, col: 1),
      );
      const power = PowerMove(power: PowerKind.zoomies);
      const laser = PowerMove(power: PowerKind.laserChase);
      const endTurn = EndTurnMove();
      for (final entry in [
        const MoveLogEntry(index: 0, move: swap),
        const MoveLogEntry(index: 7, move: power, hashAfter: 'abc123'),
        const MoveLogEntry(index: 9, move: laser),
        const MoveLogEntry(index: 10, move: endTurn),
      ]) {
        final back = MoveLogEntry.fromJson(entry.toJson());
        expect(back, entry);
      }
    });

    test('rejects malformed entries', () {
      expect(MoveLogEntry.fromJson(null), isNull);
      expect(MoveLogEntry.fromJson('x'), isNull);
      expect(MoveLogEntry.fromJson(const {'index': -1, 'move': {}}), isNull);
      expect(
        MoveLogEntry.fromJson(const {'index': 0, 'move': {'kind': 'warp'}}),
        isNull,
      );
      expect(
        MoveLogEntry.fromJson(const {
          'index': 0,
          'move': {'kind': 'power', 'power': 'teleport'},
        }),
        isNull,
      );
      expect(
        MoveLogEntry.fromJson(const {
          'index': 0,
          'move': {'kind': 'swap', 'a': {'row': 0}, 'b': {'row': 0, 'col': 1}},
        }),
        isNull,
      );
      expect(
        MoveLogEntry.fromJson(const {
          'index': 0,
          'move': {'kind': 'swap', 'a': {'row': 0, 'col': 0}, 'b': {'row': 0, 'col': 1}},
          'hashAfter': 42,
        }),
        isNull,
      );
    });
  });

  group('replayEntries', () {
    test('reproduces replay() on a full logged match', () {
      final (entries, finalState) = playLogged(1234, Random(7));
      expect(entries, isNotEmpty);
      final res = replayEntries(1234, config, entries);
      expect(res, isA<EngineOk<ReplayResult>>());
      final rr = (res as EngineOk<ReplayResult>).value;
      expect(rr.state.isFinished, isTrue);
      expect(rr.hash, stateHash(finalState));
      expect(rr.movesApplied, entries.length);

      // Same log through the bare-move replay agrees.
      final bare = replay(
        1234,
        config,
        [for (final e in entries) e.move],
      );
      expect(
        (bare as EngineOk<ReplayResult>).value.hash,
        rr.hash,
      );
    });

    test('rejects index gaps, duplicates and out-of-order entries', () {
      final (entries, _) = playLogged(99, Random(3));
      expect(entries.length, greaterThan(3));

      MoveLogEntry shifted(int i) =>
          MoveLogEntry(index: i + 1, move: entries[i].move);

      // Gap: first entry claims index 1.
      var bad = [for (var i = 0; i < entries.length; i++) shifted(i)];
      var res = replayEntries(99, config, bad);
      expect(res, isA<EngineFailure<ReplayResult>>());
      expect(
        (res as EngineFailure<ReplayResult>).error.details['reason'],
        'index-not-contiguous',
      );

      // Duplicate: swap positions 1 and 2 -> indices out of order.
      bad = List.of(entries);
      final t = bad[1];
      bad[1] = bad[2];
      bad[2] = t;
      res = replayEntries(99, config, bad);
      expect(res, isA<EngineFailure<ReplayResult>>());
      expect(
        (res as EngineFailure<ReplayResult>).error.details['reason'],
        'index-not-contiguous',
      );
    });

    test('rejects a tampered hashAfter as hash-mismatch', () {
      final (entries, _) = playLogged(55, Random(11));
      final tampered = List.of(entries);
      tampered[1] = MoveLogEntry(
        index: 1,
        move: tampered[1].move,
        hashAfter: 'deadbeefdeadbeef',
      );
      final res = replayEntries(55, config, tampered);
      expect(res, isA<EngineFailure<ReplayResult>>());
      final err = (res as EngineFailure<ReplayResult>).error;
      expect(err.details['reason'], 'hash-mismatch');
      expect(err.details['position'], 1);
    });

    test('rejects moves after the match ends', () {
      final (entries, _) = playLogged(77, Random(5));
      final extra = MoveLogEntry(
        index: entries.length,
        move: entries.first.move,
      );
      final res = replayEntries(77, config, [...entries, extra]);
      expect(res, isA<EngineFailure<ReplayResult>>());
      expect(
        (res as EngineFailure<ReplayResult>).error.details['reason'],
        'moves-after-finish',
      );
    });

    test('rejects a log built for a different seed as divergence', () {
      final (entries, _) = playLogged(1, Random(2));
      final res = replayEntries(2, config, entries);
      expect(res, isA<EngineFailure<ReplayResult>>());
      expect(
        (res as EngineFailure<ReplayResult>).error.code,
        EngineErrorCode.replayDivergence,
      );
    });

    test('accepts entries without hashAfter', () {
      final (entries, _) = playLogged(31, Random(13));
      final bare = [
        for (final e in entries)
          MoveLogEntry(index: e.index, move: e.move),
      ];
      final res = replayEntries(31, config, bare);
      expect(res, isA<EngineOk<ReplayResult>>());
    });
  });

  group('sync hashes', () {
    test('initialSyncHashes matches newMatch + syncHashes', () {
      final init = initialSyncHashes(2024, config);
      expect(init, isA<EngineOk<SyncHashes>>());
      final hashes = (init as EngineOk<SyncHashes>).value;
      final state = (newMatch(2024, config) as EngineOk<MatchState>).value;
      expect(hashes.state, stateHash(state));
      expect(hashes.first, playerHash(state, PlayerSlot.first));
      expect(hashes.second, playerHash(state, PlayerSlot.second));
    });

    test('initialSyncHashes propagates config errors', () {
      final bad = initialSyncHashes(1, const MatchConfig(colourCount: 4));
      expect(bad, isA<EngineFailure<SyncHashes>>());
    });

    test('syncHashes agree with MatchEnded.finalHashes', () {
      final (_, finalState) = playLogged(808, Random(17));
      final hashes = syncHashes(finalState);
      expect(hashes.state, stateHash(finalState));
      expect(finalState.outcome, isNotNull);
      // Per-player hashes are stable digests of each side's view.
      expect(hashes.first, playerHash(finalState, PlayerSlot.first));
      expect(hashes.second, playerHash(finalState, PlayerSlot.second));
      expect(hashes.first, isNot(hashes.second));
    });
  });

  group('isLegalMove', () {
    test('matches legalMoves membership', () {
      final state = (newMatch(4, config) as EngineOk<MatchState>).value;
      final legal =
          (legalMoves(state) as EngineOk<List<Move>>).value;
      final probe = legal.first;
      final yes = isLegalMove(state, probe);
      expect(yes, isA<EngineOk<bool>>());
      expect((yes as EngineOk<bool>).value, isTrue);

      final bogus = SwapMove(
        firstCell: (row: 0, col: 0),
        secondCell: (row: 6, col: 6),
      );
      final no = isLegalMove(state, bogus);
      expect(no, isA<EngineOk<bool>>());
      expect((no as EngineOk<bool>).value, isFalse);
    });
  });

  group('summarizeLog', () {
    test('buckets a full match per turn and player', () {
      final (entries, finalState) = playLogged(314, Random(19));
      final res = summarizeLog(314, config, entries);
      expect(res, isA<EngineOk<LogSummary>>());
      final summary = (res as EngineOk<LogSummary>).value;

      expect(summary.outcome, finalState.outcome);
      expect(summary.stateHash, stateHash(finalState));
      expect(summary.playerHashes.first,
          playerHash(finalState, PlayerSlot.first));
      expect(summary.playerHashes.second,
          playerHash(finalState, PlayerSlot.second));

      // Every accepted entry appears exactly once across the buckets.
      var accepted = 0;
      var byTurn = <int, int>{};
      for (final t in summary.turns) {
        accepted += t.firstAccepted.length + t.secondAccepted.length;
        byTurn[t.turn] =
            t.firstAccepted.length + t.secondAccepted.length;
      }
      expect(accepted, entries.length);
      expect(byTurn.keys, orderedEquals(byTurn.keys.toList()..sort()));
      // All ten turns were played (five each).
      expect(summary.turns.length, 2 * config.turnsPerPlayer);
      // Each turn belongs to exactly one player, alternating.
      for (var i = 0; i < summary.turns.length; i++) {
        final t = summary.turns[i];
        expect(t.turn, i + 1);
        final firstCount =
            t.firstAccepted.length + t.firstRejected.length;
        final secondCount =
            t.secondAccepted.length + t.secondRejected.length;
        if (i.isEven) {
          expect(firstCount, greaterThan(0));
          expect(secondCount, 0);
        } else {
          expect(secondCount, greaterThan(0));
          expect(firstCount, 0);
        }
      }
    });

    test('distinguishes rejected swap attempts', () {
      // Find a non-productive adjacent swap on the initial board.
      var state = (newMatch(6, config) as EngineOk<MatchState>).value;
      final w = state.boardOf(state.activePlayer).width;
      final h = state.boardOf(state.activePlayer).height;
      Move? rejectedMove;
      for (var r = 0; r < h && rejectedMove == null; r++) {
        for (var c = 0; c + 1 < w && rejectedMove == null; c++) {
          final probe = SwapMove(
            firstCell: (row: r, col: c),
            secondCell: (row: r, col: c + 1),
          );
          final res = applyMove(state, probe);
          if (res is EngineOk<MoveResult> &&
              res.value.events.single is SwapRejected) {
            rejectedMove = probe;
          }
        }
      }
      expect(rejectedMove, isNotNull, reason: 'need a non-productive swap');

      // A legal follow-up move so the log stays valid.
      final legal =
          (legalMoves(state) as EngineOk<List<Move>>).value;
      final followUp = legal.firstWhere(
        (m) => m != rejectedMove,
        orElse: () => legal.first,
      );

      final entries = [
        MoveLogEntry(index: 0, move: rejectedMove!),
        MoveLogEntry(index: 1, move: followUp),
      ];
      final res = summarizeLog(6, config, entries);
      expect(res, isA<EngineOk<LogSummary>>());
      final summary = (res as EngineOk<LogSummary>).value;
      final turn = summary.turns.single;
      expect(turn.firstRejected, hasLength(1));
      expect(turn.firstRejected.single.move, rejectedMove);
      expect(turn.firstRejected.single.reason, 'no-match');
      expect(turn.firstAccepted, [followUp]);
      expect(turn.secondAccepted, isEmpty);
    });

    test('rejects the same corruptions as replayEntries', () {
      final (entries, _) = playLogged(88, Random(23));
      final bad = [for (final e in entries) MoveLogEntry(index: e.index + 1, move: e.move)];
      final res = summarizeLog(88, config, bad);
      expect(res, isA<EngineFailure<LogSummary>>());
      expect(
        (res as EngineFailure<LogSummary>).error.details['reason'],
        'index-not-contiguous',
      );
    });

    test('empty log summarizes the initial state', () {
      final res = summarizeLog(9, config, const []);
      expect(res, isA<EngineOk<LogSummary>>());
      final summary = (res as EngineOk<LogSummary>).value;
      final init = (newMatch(9, config) as EngineOk<MatchState>).value;
      expect(summary.stateHash, stateHash(init));
      expect(summary.outcome, isNull);
      expect(summary.turns, isEmpty);
    });
  });

  group('json-level log decode', () {
    test('entries decoded from raw json replay identically', () {
      final (entries, finalState) = playLogged(500, Random(29));
      // Simulate a Firestore round-trip: maps in, maps out.
      final raw = [for (final e in entries) e.toJson()];
      final decoded = [
        for (final j in raw) MoveLogEntry.fromJson(j)!,
      ];
      final res = replayEntries(500, config, decoded);
      expect(res, isA<EngineOk<ReplayResult>>());
      expect(
        (res as EngineOk<ReplayResult>).value.hash,
        stateHash(finalState),
      );
    });
  });
}
