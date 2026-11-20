import 'package:arena_engine/arena_engine.dart' as engine;

import 'duel_events.dart';

/// Adapts `package:arena_engine` state and events into the view-facing
/// [BoardSnapshot]/[BoardEvent] model consumed by `board_game.dart`.
///
/// The engine tracks piece *codes*, not identities, and emits `CellPos`
/// records; this adapter assigns stable piece ids, flattens positions to
/// `row * width + col` and resolves obstacle kinds from the post-move
/// board. Boards persist across turns, so no reset event is needed at
/// turn boundaries.
///
/// [localSlot] is the engine slot this client plays (host = first, guest =
/// second in online duels). The duel board is shared — both players' moves
/// animate on the same grid; private events (SwapRejected, PowerCharged,
/// ObstacleQueued) stay local-only.
class EngineViewAdapter {
  EngineViewAdapter({
    this.width = 7,
    this.height = 7,
    this.localSlot = engine.PlayerSlot.first,
  });

  final int width;
  final int height;

  /// Engine slot of the human player whose board this view shows.
  final engine.PlayerSlot localSlot;

  /// Events are always emitted for the view's own [PlayerSlot.first]; the
  /// board widget does not distinguish slots.
  static const _viewPlayer = PlayerSlot.first;

  /// Maps an engine slot to the view slot: the human is always
  /// [PlayerSlot.first], the opponent [PlayerSlot.second]. The board is
  /// physically shared — both players' moves animate on the same grid.
  PlayerSlot _vp(engine.PlayerSlot player) =>
      player == localSlot ? PlayerSlot.first : PlayerSlot.second;

  int _nextId = 1;

  int _idx(engine.CellPos p) => p.row * width + p.col;

  SpecialKind _specialKind(engine.SpecialKind kind, engine.LineOrientation? o) =>
      switch (kind) {
        engine.SpecialKind.line => o == engine.LineOrientation.column
            ? SpecialKind.lineVertical
            : SpecialKind.lineHorizontal,
        engine.SpecialKind.bomb => SpecialKind.bomb,
        engine.SpecialKind.copter => SpecialKind.copter,
        engine.SpecialKind.rainbow => SpecialKind.rainbow,
      };

  SpecialKind _firedSpecialKind(engine.SpecialKind kind) =>
      _specialKind(kind, engine.LineOrientation.row);

  PowerKind _powerKind(engine.PowerKind power) => switch (power) {
    engine.PowerKind.zoomies => PowerKind.zoomies,
    engine.PowerKind.shadowPounce => PowerKind.shadowPounce,
    engine.PowerKind.laserChase => PowerKind.laserChase,
  };

  MatchOutcome _outcome(engine.MatchOutcome outcome) => switch (outcome) {
    engine.MatchOutcome.firstWins => MatchOutcome.firstWin,
    engine.MatchOutcome.secondWins => MatchOutcome.secondWin,
    engine.MatchOutcome.draw => MatchOutcome.draw,
  };

  /// Snapshot of [slot]'s board in [state]; assigns fresh piece ids.
  BoardSnapshot snapshotOf(engine.MatchState state, engine.PlayerSlot slot) {
    final b = state.boardOf(slot);
    return BoardSnapshot(
      width: b.width,
      height: b.height,
      cells: [for (final code in b.cells) _cellOf(code)],
    );
  }

  BoardCell _cellOf(int code) {
    if (code == -2) {
      return const BoardCell(obstacle: ObstacleKind.cardboardBox);
    }
    if (code == -1) return const BoardCell();
    var yarn = false;
    var base = code;
    if (base >= 64) {
      yarn = true;
      base -= 64;
    }
    if (base < 0) {
      return yarn
          ? const BoardCell(obstacle: ObstacleKind.tangledYarn)
          : const BoardCell();
    }
    // Special codes pack kind+colour: kind = (base-20) ~/ 8, colour =
    // (base-20) % 8. The piece carries its colour so the painter can
    // badge it — players combine specials with pieces of that colour.
    final kindIdx = base >= 20 ? (base - 20) ~/ 8 : -1;
    final special = switch (kindIdx) {
      0 => SpecialKind.lineHorizontal,
      1 => SpecialKind.lineVertical,
      2 => SpecialKind.bomb,
      3 => SpecialKind.copter,
      4 => SpecialKind.rainbow,
      _ => SpecialKind.none,
    };
    return BoardCell(
      piece: BoardPiece(
        id: _nextId++,
        kind: base >= 20 ? (base - 20) % 8 : base,
        special: special,
      ),
      obstacle: yarn ? ObstacleKind.tangledYarn : null,
    );
  }

  /// Adapts [result] into view events for the human's board. Only events
  /// acting on [localSlot] are kept, plus round/match meta events.
  /// [before] is the pre-move state (unused today, kept for symmetry).
  List<BoardEvent> adaptMove(engine.MoveResult result, {engine.MatchState? before}) {
    final out = <BoardEvent>[];
    final state = result.state;
    for (final e in result.events) {
      switch (e) {
        case engine.Swapped(:final player, :final firstCell, :final secondCell):
          out.add(
            Swapped(
              player: _vp(player),
              firstCell: _idx(firstCell),
              secondCell: _idx(secondCell),
            ),
          );
        case engine.SwapRejected(
          :final player,
          :final firstCell,
          :final secondCell,
          :final reason,
        )
            when player == localSlot:
          out.add(
            SwapRejected(
              player: _viewPlayer,
              firstCell: _idx(firstCell),
              secondCell: _idx(secondCell),
              reason: reason,
            ),
          );
        case engine.Cleared(:final player, :final cells, :final points):
          out.add(
            Cleared(
              player: _vp(player),
              cells: [for (final c in cells) _idx(c)],
              points: points,
            ),
          );
        case engine.SpecialCreated(
          :final player,
          :final kind,
          :final orientation,
          :final cell,
        ):
          out.add(
            SpecialCreated(
              player: _vp(player),
              kind: _specialKind(kind, orientation),
              cell: _idx(cell),
            ),
          );
        case engine.SpecialFired(:final player, :final kind, :final cells, :final points):
          out.add(
            SpecialFired(
              player: _vp(player),
              kind: _firedSpecialKind(kind),
              cells: [for (final c in cells) _idx(c)],
              points: points,
            ),
          );
        case engine.Fell(:final player, :final from, :final to):
          out.add(Fell(player: _vp(player), from: _idx(from), to: _idx(to)));
        case engine.Refilled(:final player, :final cell, :final piece):
          out.add(
            Refilled(
              player: _vp(player),
              cell: _idx(cell),
              piece: BoardPiece(id: _nextId++, kind: piece.clamp(0, 5)),
            ),
          );
        case engine.ObstacleQueued(:final player, :final sourceTurn, :final count)
            when player == localSlot:
          out.add(
            ObstacleQueued(
              player: _viewPlayer,
              sourceTurn: sourceTurn,
              count: count,
            ),
          );
        case engine.ObstacleLanded(:final player, :final cells):
          // The engine event does not carry kinds; resolve each cell from
          // the post-move board and group by kind for the view.
          final board = state.boardOf(player);
          final byKind = <ObstacleKind, List<int>>{};
          for (final c in cells) {
            final code = board.cellAt(c.row, c.col);
            final kind = code == -2
                ? ObstacleKind.cardboardBox
                : code >= 64
                ? ObstacleKind.tangledYarn
                : ObstacleKind.cardboardBox;
            byKind.putIfAbsent(kind, () => []).add(_idx(c));
          }
          for (final entry in byKind.entries) {
            out.add(
              ObstacleLanded(
                player: _vp(player),
                cells: entry.value,
                obstacle: entry.key,
              ),
            );
          }
        case engine.ObstacleBroken(:final player, :final cells):
          out.add(
            ObstacleBroken(
              player: _vp(player),
              cells: [for (final c in cells) _idx(c)],
            ),
          );
        case engine.PowerCharged(:final player)
            when player == localSlot:
          out.add(
            PowerCharged(player: _viewPlayer, amount: state.chargeOf(player)),
          );
        case engine.PowerFired(
          :final player,
          :final power,
          :final cells,
          :final points,
        ):
          out.add(
            PowerFired(
              player: _vp(player),
              power: _powerKind(power),
              cells: [for (final c in cells) _idx(c)],
              points: points,
            ),
          );
        case engine.Shuffled(:final player, :final cells, :final reason):
          final board = state.boardOf(player);
          final pieces = <int, BoardPiece>{};
          for (final c in cells) {
            final i = _idx(c);
            final cell = _cellOf(board.cellAt(c.row, c.col));
            if (cell.piece != null) pieces[i] = cell.piece!;
          }
          out.add(
            Shuffled(
              player: _vp(player),
              cells: [for (final c in cells) _idx(c)],
              reason: reason,
              pieces: pieces,
            ),
          );
        case engine.TurnEnded(:final turn, :final scores, :final outcome):
          out.add(
            TurnEnded(
              turn: turn,
              scores: (first: scores.first, second: scores.second),
              outcome: outcome == null ? null : _outcome(outcome),
            ),
          );
        case engine.MatchEnded(
          :final outcome,
          :final scores,
          :final finalHashes,
        ):
          out.add(
            MatchEnded(
              outcome: _outcome(outcome),
              scores: (first: scores.first, second: scores.second),
              finalHashes: (first: finalHashes.first, second: finalHashes.second),
            ),
          );
        // SwapRejected/PowerCharged/ObstacleQueued stay local-only above;
        // everything else reached the shared board.
        case _:
          break;
      }
    }
    return out;
  }
}
