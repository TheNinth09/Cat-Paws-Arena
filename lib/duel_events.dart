/// Contract event types for the duel board.
///
/// Provisional mirror of the event contract in `docs/contract.md` section 3,
/// defined here until `package:arena_engine` (lane 1) lands and becomes the
/// authoritative source. Field names follow the contract; cells are
/// zero-based row-major indices (`row * width + col`) into the configured
/// board, matching the agreed 7x7 duel (indices 0..48).
library;

/// Stable player identifiers from the contract; never display names.
enum PlayerSlot { first, second }

/// Defined special-piece kinds (contract: `SpecialCreated.kind` is a defined
/// enum, not arbitrary UI text).
enum SpecialKind { none, lineHorizontal, lineVertical, bomb, rainbow }

/// Cosmetic obstacle kinds; the engine decides which kind lands where.
enum ObstacleKind { cardboardBox, slipper, tangledYarn }

/// The three agreed free powers (contract decision 4: equal strength, none
/// sold). Names are provisional until the engine names them.
enum PowerKind { zoomies, shadowPounce, laserChase }

/// Why a swap was rejected; the engine owns the authoritative reason codes,
/// the UI maps them to text.
enum SwapRejectReason {
  notAdjacent,
  blocked,
  noMatch,
  outOfTurn,
  gameOver,
}

enum MatchOutcome { firstWin, secondWin, draw }

/// A single board piece. [kind] indexes the tile sprite set
/// (0..colourCount-1); [special] is the contract's defined special enum.
class BoardPiece {
  const BoardPiece({
    required this.id,
    required this.kind,
    this.special = SpecialKind.none,
  });

  /// Stable identity used to track a piece across events.
  final int id;
  final int kind;
  final SpecialKind special;

  BoardPiece withSpecial(SpecialKind value) => BoardPiece(
    id: id,
    kind: kind,
    special: value,
  );

  @override
  bool operator ==(Object other) =>
      other is BoardPiece && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);
}

/// One cell: an optional piece plus an optional obstacle layer.
class BoardCell {
  const BoardCell({this.piece, this.obstacle});

  final BoardPiece? piece;
  final ObstacleKind? obstacle;

  bool get isEmpty => piece == null && obstacle == null;
}

/// Immutable board contents, row-major, for initial state and assertions.
class BoardSnapshot {
  const BoardSnapshot({
    required this.width,
    required this.height,
    required this.cells,
  });

  final int width;
  final int height;
  final List<BoardCell> cells;

  factory BoardSnapshot.empty({int width = 7, int height = 7}) =>
      BoardSnapshot(
        width: width,
        height: height,
        cells: List.filled(width * height, const BoardCell()),
      );
}

/// Base type for every gameplay event in the contract. All events are
/// immutable value objects with deterministic ordering.
sealed class BoardEvent {
  const BoardEvent();
}

/// Accepted swap before resolution.
final class Swapped extends BoardEvent {
  const Swapped({
    required this.player,
    required this.firstCell,
    required this.secondCell,
  });
  final PlayerSlot player;
  final int firstCell;
  final int secondCell;
}

/// Rejected swap; no state mutation.
final class SwapRejected extends BoardEvent {
  const SwapRejected({
    required this.player,
    required this.firstCell,
    required this.secondCell,
    required this.reason,
  });
  final PlayerSlot player;
  final int firstCell;
  final int secondCell;
  final SwapRejectReason reason;
}

/// Flat points for the cleared pieces (no cascade multiplier).
final class Cleared extends BoardEvent {
  const Cleared({
    required this.player,
    required this.cells,
    required this.points,
  });
  final PlayerSlot player;
  final List<int> cells;
  final int points;
}

/// A special piece was created at [cell].
final class SpecialCreated extends BoardEvent {
  const SpecialCreated({
    required this.player,
    required this.kind,
    required this.cell,
  });
  final PlayerSlot player;
  final SpecialKind kind;
  final int cell;
}

/// A special piece fired; [cells] are the resolved effect cells.
final class SpecialFired extends BoardEvent {
  const SpecialFired({
    required this.player,
    required this.kind,
    required this.cells,
    required this.points,
  });
  final PlayerSlot player;
  final SpecialKind kind;
  final List<int> cells;
  final int points;
}

/// One gravity movement of a cell's contents.
final class Fell extends BoardEvent {
  const Fell({required this.player, required this.from, required this.to});
  final PlayerSlot player;
  final int from;
  final int to;
}

/// A deterministic new piece entered [cell].
final class Refilled extends BoardEvent {
  const Refilled({
    required this.player,
    required this.cell,
    required this.piece,
  });
  final PlayerSlot player;
  final int cell;
  final BoardPiece piece;
}

/// Obstacle earned this round, queued for the opponent's next round.
final class ObstacleQueued extends BoardEvent {
  const ObstacleQueued({
    required this.player,
    required this.sourceRound,
    required this.count,
  });
  final PlayerSlot player;
  final int sourceRound;
  final int count;
}

/// Obstacles appearing at round start. [obstacle] is a provisional additive
/// field so the view can pick the right sprite until the engine freezes kinds.
final class ObstacleLanded extends BoardEvent {
  const ObstacleLanded({
    required this.player,
    required this.cells,
    required this.obstacle,
  });
  final PlayerSlot player;
  final List<int> cells;
  final ObstacleKind obstacle;
}

/// Obstacles cleared or consumed.
final class ObstacleBroken extends BoardEvent {
  const ObstacleBroken({required this.player, required this.cells});
  final PlayerSlot player;
  final List<int> cells;
}

/// [amount] is the resulting total charge (0..100), documented consistently.
final class PowerCharged extends BoardEvent {
  const PowerCharged({required this.player, required this.amount});
  final PlayerSlot player;
  final int amount;
}

/// Validated power resolution.
final class PowerFired extends BoardEvent {
  const PowerFired({
    required this.player,
    required this.power,
    required this.cells,
    required this.points,
  });
  final PlayerSlot player;
  final PowerKind power;
  final List<int> cells;
  final int points;
}

/// Deterministic reshuffle. [pieces] is a provisional additive field carrying
/// the resulting arrangement so the view can resync until engine state sync
/// exists; [reason] is an engine-defined code (e.g. `no_moves`).
final class Shuffled extends BoardEvent {
  const Shuffled({
    required this.player,
    required this.cells,
    required this.reason,
    required this.pieces,
  });
  final PlayerSlot player;
  final List<int> cells;
  final String reason;
  final Map<int, BoardPiece> pieces;
}

/// An extra move was awarded (only if rules award one).
final class ExtraMove extends BoardEvent {
  const ExtraMove({
    required this.player,
    required this.round,
    required this.movesRemaining,
  });
  final PlayerSlot player;
  final int round;
  final int movesRemaining;
}

/// Round boundary snapshot.
final class RoundEnded extends BoardEvent {
  const RoundEnded({required this.round, required this.scores, this.outcome});
  final int round;
  final ({int first, int second}) scores;
  final MatchOutcome? outcome;
}

/// Terminal result.
final class MatchEnded extends BoardEvent {
  const MatchEnded({
    required this.outcome,
    required this.scores,
    required this.finalHashes,
  });
  final MatchOutcome outcome;
  final ({int first, int second}) scores;
  final ({String first, String second}) finalHashes;
}
