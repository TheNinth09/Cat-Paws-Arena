/// Core value types for the arena engine: configuration, match state,
/// moves, events and results.
///
/// Everything in this file is immutable. Lists exposed by [MatchState] and
/// events are unmodifiable; callers cannot mutate engine state through them.
library;

/// Stable player identifier. Never a display name or device id.
enum PlayerSlot {
  first,
  second;

  /// The other slot in the duel.
  PlayerSlot get other => this == PlayerSlot.first
      ? PlayerSlot.second
      : PlayerSlot.first;
}

/// Final duel outcome, from the perspective of [PlayerSlot.first].
enum MatchOutcome {
  /// `first` scored strictly more points than `second`.
  firstWins,

  /// `second` scored strictly more points than `first`.
  secondWins,

  /// Both players scored the same points.
  draw;
}

/// How a rainbow piece resolves when fired, selected by
/// [MatchConfig.rainbowRule] before the match starts.
enum RainbowRule {
  /// Clears every piece of one colour from the board.
  clearOneColour,

  /// Removes a fixed number of random pieces from the board.
  removeRandomPieces,
}

/// Identifies the agreed power set. The three powers are free and of equal
/// strength; none is sold. There is exactly one ruleset today.
enum PowerRuleset {
  /// Zoomies, Shadow Pounce and Laser Chase, all free and equal.
  threeFreeEqual,
}

/// The three agreed powers, in fixed order.
enum PowerKind {
  /// Clears a chosen row and sends two obstacles to the opponent.
  zoomies,

  /// Clears the most common colour on your own board.
  shadowPounce,

  /// Breaks a fixed number of random pieces and clears your own obstacles.
  laserChase,
}

/// Special pieces created by matches of four or more.
enum SpecialKind {
  /// Created by a straight four. Clears its row or column when fired.
  line,

  /// Created by an L/T/bent five. Clears a 3x3 area when fired.
  bomb,

  /// Created by a straight five or more. Effect depends on
  /// [MatchConfig.rainbowRule].
  rainbow,
}

/// Which line a [SpecialKind.line] piece clears when fired.
///
/// A horizontal four-match creates a piece that clears its **column**; a
/// vertical four-match creates a piece that clears its **row** — the reward
/// is orthogonal to the match that created it.
enum LineOrientation {
  /// Clears every piece in the piece's row.
  row,

  /// Clears every piece in the piece's column.
  column,
}

/// Obstacle kinds that can land on a board at the start of a round.
enum ObstacleKind {
  /// Blocks a cell until a piece next to it is cleared.
  box,

  /// Locks the piece in its cell until that piece is matched.
  yarn,
}

/// A zero-based row/column pair on a board.
///
/// Rows count from the top (`0`) to the bottom (`height - 1`); columns
/// count from the left (`0`) to the right (`width - 1`).
typedef CellPos = ({int row, int col});

/// Score snapshot for the two players.
typedef ScorePair = ({int first, int second});

/// Per-player state hashes for [MatchEnded.finalHashes].
typedef HashPair = ({String first, String second});

/// Immutable match configuration. Both clients must use identical values;
/// the engine never silently clamps a config.
class MatchConfig {
  /// Board width in cells. The agreed duel uses `7`.
  final int boardWidth;

  /// Board height in cells. The agreed duel uses `7`.
  final int boardHeight;

  /// Number of regular piece colours: `5` or `6`.
  final int colourCount;

  /// Number of rounds in the duel. The agreed duel uses `5`.
  final int rounds;

  /// Accepted moves each player gets per round. The agreed duel uses `3`.
  final int movesPerRound;

  /// Rainbow resolution rule.
  final RainbowRule rainbowRule;

  /// Rules/serialization compatibility version. Must equal the engine's
  /// supported version or [newMatch] rejects the config.
  final int engineVersion;

  /// Identifies the power set; the agreed powers are free and equal.
  final PowerRuleset powerConfiguration;

  const MatchConfig({
    this.boardWidth = 7,
    this.boardHeight = 7,
    this.colourCount = 5,
    this.rounds = 5,
    this.movesPerRound = 3,
    this.rainbowRule = RainbowRule.clearOneColour,
    this.engineVersion = kEngineVersion,
    this.powerConfiguration = PowerRuleset.threeFreeEqual,
  });

  /// The agreed duel configuration: 7x7, five colours, five rounds of
  /// three moves, rainbow clears one colour.
  const MatchConfig.duel()
    : boardWidth = 7,
      boardHeight = 7,
      colourCount = 5,
      rounds = 5,
      movesPerRound = 3,
      rainbowRule = RainbowRule.clearOneColour,
      engineVersion = kEngineVersion,
      powerConfiguration = PowerRuleset.threeFreeEqual;

  /// Canonical string identifying this configuration, for logs and
  /// cross-checks. Field order is fixed.
  String get fingerprint =>
      'v$engineVersion|'
      '${boardWidth}x$boardHeight|'
      'c$colourCount|'
      'r$rounds|'
      'm$movesPerRound|'
      'rainbow:${rainbowRule.name}|'
      'powers:${powerConfiguration.name}';

  /// Stable JSON encoding for match documents and move-log headers.
  /// Every field is stored explicitly so [fromJson] can reconstruct an
  /// identical config; no defaults are re-applied on decode.
  Map<String, Object?> toJson() => {
    'engineVersion': engineVersion,
    'boardWidth': boardWidth,
    'boardHeight': boardHeight,
    'colourCount': colourCount,
    'rounds': rounds,
    'movesPerRound': movesPerRound,
    'rainbowRule': rainbowRule.name,
    'powerConfiguration': powerConfiguration.name,
  };

  /// Decodes a config produced by [toJson]. Returns `null` on any
  /// malformed input — missing fields, wrong types or unknown enum
  /// names — so callers can reject corrupt match data instead of
  /// silently falling back to local defaults (forbidden by the
  /// contract). The decoded config still goes through [newMatch]
  /// validation, so out-of-range values are rejected there too.
  static MatchConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    int? intField(String key) {
      final v = json[key];
      return v is int ? v : null;
    }

    final engineVersion = intField('engineVersion');
    final boardWidth = intField('boardWidth');
    final boardHeight = intField('boardHeight');
    final colourCount = intField('colourCount');
    final rounds = intField('rounds');
    final movesPerRound = intField('movesPerRound');
    if (engineVersion == null ||
        boardWidth == null ||
        boardHeight == null ||
        colourCount == null ||
        rounds == null ||
        movesPerRound == null) {
      return null;
    }
    final rainbowRule = RainbowRule.values.asNameMap()[json['rainbowRule']];
    final powerConfiguration = PowerRuleset.values.asNameMap()[
      json['powerConfiguration']
    ];
    if (rainbowRule == null || powerConfiguration == null) return null;
    return MatchConfig(
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      colourCount: colourCount,
      rounds: rounds,
      movesPerRound: movesPerRound,
      rainbowRule: rainbowRule,
      engineVersion: engineVersion,
      powerConfiguration: powerConfiguration,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchConfig &&
      other.boardWidth == boardWidth &&
      other.boardHeight == boardHeight &&
      other.colourCount == colourCount &&
      other.rounds == rounds &&
      other.movesPerRound == movesPerRound &&
      other.rainbowRule == rainbowRule &&
      other.engineVersion == engineVersion &&
      other.powerConfiguration == powerConfiguration;

  @override
  int get hashCode => Object.hash(
    boardWidth,
    boardHeight,
    colourCount,
    rounds,
    movesPerRound,
    rainbowRule,
    engineVersion,
    powerConfiguration,
  );
}

/// Supported rules/serialization version. Bump only via an announced
/// contract change; [MatchConfig.engineVersion] must match it.
const int kEngineVersion = 1;

/// Maximum pending obstacles queued for one player. Obstacles earned beyond
/// this cap are discarded (the oldest queued obstacles are kept).
const int kMaxPendingObstacles = 12;

/// Maximum power charge. Cleared pieces add [kChargePerPiece] charge each,
/// capped at this value.
const int kPowerCost = 500;

/// Charge a [PowerKind.zoomies] activation costs. Powers are free and of
/// equal strength; per-kind costs are the slice-3 balance tuning numbers
/// (see `report/harness.md`). Each cost sits above the charge its own
/// effect regenerates, so no power can fuel itself.
const int kZoomiesChargeCost = 460;

/// Charge a [PowerKind.shadowPounce] activation costs.
const int kShadowPounceChargeCost = 500;

/// Charge a [PowerKind.laserChase] activation costs.
const int kLaserChaseChargeCost = 175;

/// Pieces removed by [PowerKind.laserChase].
const int kLaserBreakCount = 8;

/// Charge cost of firing [power].
int powerChargeCost(PowerKind power) => switch (power) {
  PowerKind.zoomies => kZoomiesChargeCost,
  PowerKind.shadowPounce => kShadowPounceChargeCost,
  PowerKind.laserChase => kLaserChaseChargeCost,
};

/// Charge gained per cleared piece.
const int kChargePerPiece = 4;

/// Points awarded per cleared piece. Flat scoring: no cascade multiplier.
const int kPointsPerPiece = 10;

/// Obstacles sent to the opponent by [PowerKind.zoomies].
const int kZoomiesObstacleCount = 2;

/// Pieces removed by a rainbow under [RainbowRule.removeRandomPieces].
const int kRainbowRemoveCount = 12;

/// A board snapshot. [cells] is row-major, length `width * height`.
///
/// Cell encoding:
/// * `-1` empty — transient only; stable boards never contain it.
/// * `-2` box obstacle occupying the cell (no piece inside).
/// * `0..5` regular colour pieces (`colourCount` decides how many are used).
/// * `20` line piece clearing its row, `21` line piece clearing its column,
///   `22` bomb, `23` rainbow.
/// * any piece code `+ 64` is locked in place by yarn.
class BoardState {
  final int width;
  final int height;
  final List<int> cells;

  /// Per-column refill generator state (Lehmer raw state), parallel to
  /// columns. The refill stream for column `c` of round `r` is derived from
  /// `(seed, r, c)` and is the same for both players; each board stores its
  /// own continuation of that stream.
  final List<int> refillState;

  BoardState._(this.width, this.height, List<int> cells, List<int> refill)
    : cells = List.unmodifiable(cells),
      refillState = List.unmodifiable(refill);

  factory BoardState(
    int width,
    int height,
    List<int> cells,
    List<int> refillState,
  ) {
    assert(cells.length == width * height);
    assert(refillState.length == width);
    return BoardState._(width, height, cells, refillState);
  }

  /// The encoded piece/obstacle at zero-based [row]/[col].
  int cellAt(int row, int col) => cells[row * width + col];
}

/// Complete immutable match state. All lists are unmodifiable.
class MatchState {
  /// Rules/serialization version; equals [MatchConfig.engineVersion].
  final int engineVersion;

  /// The match seed exactly as passed to `newMatch`.
  final int seed;

  /// Immutable configuration shared by both players.
  final MatchConfig config;

  /// Current round, `1..config.rounds`.
  final int round;

  /// Player allowed to move now.
  final PlayerSlot activePlayer;

  /// Accepted moves left this round, indexed by [PlayerSlot.index].
  final List<int> movesRemaining;

  /// Cumulative scores, indexed by [PlayerSlot.index].
  final List<int> scores;

  /// One independent board per player, indexed by [PlayerSlot.index].
  final List<BoardState> boards;

  /// Obstacles each player will receive at the start of their next round,
  /// indexed by [PlayerSlot.index]. Cleared when the round ends.
  final List<List<ObstacleKind>> pendingObstacles;

  /// Power charge `0..kPowerCost`, indexed by [PlayerSlot.index].
  final List<int> powerCharge;

  /// Per-player deterministic effect RNG state (Lehmer), indexed by
  /// [PlayerSlot.index]. Only that player's board events advance it.
  final List<int> rngState;

  /// Final outcome, or `null` while the match is ongoing.
  final MatchOutcome? outcome;

  MatchState._({
    required this.engineVersion,
    required this.seed,
    required this.config,
    required this.round,
    required this.activePlayer,
    required List<int> movesRemaining,
    required List<int> scores,
    required List<BoardState> boards,
    required List<List<ObstacleKind>> pendingObstacles,
    required List<int> powerCharge,
    required List<int> rngState,
    required this.outcome,
  }) : movesRemaining = List.unmodifiable(movesRemaining),
       scores = List.unmodifiable(scores),
       boards = List.unmodifiable(boards),
       pendingObstacles = List.unmodifiable([
         for (final q in pendingObstacles) List<ObstacleKind>.unmodifiable(q),
       ]),
       powerCharge = List.unmodifiable(powerCharge),
       rngState = List.unmodifiable(rngState);

  factory MatchState.create({
    required int seed,
    required MatchConfig config,
    required int round,
    required PlayerSlot activePlayer,
    required List<int> movesRemaining,
    required List<int> scores,
    required List<BoardState> boards,
    required List<List<ObstacleKind>> pendingObstacles,
    required List<int> powerCharge,
    required List<int> rngState,
    MatchOutcome? outcome,
  }) {
    return MatchState._(
      engineVersion: config.engineVersion,
      seed: seed,
      config: config,
      round: round,
      activePlayer: activePlayer,
      movesRemaining: movesRemaining,
      scores: scores,
      boards: boards,
      pendingObstacles: pendingObstacles,
      powerCharge: powerCharge,
      rngState: rngState,
      outcome: outcome,
    );
  }

  /// Whether the match has produced a final outcome.
  bool get isFinished => outcome != null;

  /// Score snapshot as a record.
  ScorePair get scorePair =>
      (first: scores[PlayerSlot.first.index], second: scores[PlayerSlot.second.index]);

  /// Moves left for [player] this round.
  int movesLeft(PlayerSlot player) => movesRemaining[player.index];

  /// Score of [player].
  int scoreOf(PlayerSlot player) => scores[player.index];

  /// Board of [player].
  BoardState boardOf(PlayerSlot player) => boards[player.index];

  /// Charge of [player].
  int chargeOf(PlayerSlot player) => powerCharge[player.index];
}

/// A player action. The acting player is always [MatchState.activePlayer];
/// a move never names a player.
sealed class Move {
  const Move();

  /// Stable JSON-compatible encoding for move logs. No timestamps or object
  /// references; field order is fixed.
  Map<String, Object?> toJson();

  /// Decodes a move produced by [toJson]. Returns `null` on malformed input.
  static Move? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['kind'];
    if (kind == 'swap') {
      final a = _cellFromJson(json['a']);
      final b = _cellFromJson(json['b']);
      if (a == null || b == null) return null;
      return SwapMove(firstCell: a, secondCell: b);
    }
    if (kind == 'power') {
      final power = PowerKind.values.asNameMap()[json['power']];
      if (power == null) return null;
      final row = json['row'];
      if (row != null && row is! int) return null;
      return PowerMove(power: power, targetRow: row as int?);
    }
    return null;
  }

  static CellPos? _cellFromJson(Object? json) {
    if (json is! Map) return null;
    final row = json['row'];
    final col = json['col'];
    if (row is! int || col is! int) return null;
    return (row: row, col: col);
  }
}

/// Swap two orthogonally adjacent cells.
final class SwapMove extends Move {
  final CellPos firstCell;
  final CellPos secondCell;

  const SwapMove({required this.firstCell, required this.secondCell});

  @override
  Map<String, Object?> toJson() => {
    'kind': 'swap',
    'a': {'row': firstCell.row, 'col': firstCell.col},
    'b': {'row': secondCell.row, 'col': secondCell.col},
  };

  @override
  bool operator ==(Object other) =>
      other is SwapMove &&
      other.firstCell == firstCell &&
      other.secondCell == secondCell;

  @override
  int get hashCode => Object.hash(firstCell, secondCell);
}

/// Fire a power. [targetRow] is required by [PowerKind.zoomies] (the row to
/// clear, `0..boardHeight-1`) and must be `null` for the other powers.
final class PowerMove extends Move {
  final PowerKind power;
  final int? targetRow;

  const PowerMove({required this.power, this.targetRow});

  @override
  Map<String, Object?> toJson() => {
    'kind': 'power',
    'power': power.name,
    if (targetRow != null) 'row': targetRow,
  };

  @override
  bool operator ==(Object other) =>
      other is PowerMove && other.power == power && other.targetRow == targetRow;

  @override
  int get hashCode => Object.hash(power, targetRow);
}

/// Immutable gameplay event. Every event carries the acting [player] where
/// relevant; ordering inside a move result is causal and stable.
sealed class GameEvent {
  const GameEvent();
}

/// An accepted swap, emitted before resolution.
final class Swapped extends GameEvent {
  final PlayerSlot player;
  final CellPos firstCell;
  final CellPos secondCell;
  const Swapped({
    required this.player,
    required this.firstCell,
    required this.secondCell,
  });
}

/// A well-formed swap that creates no match and involves no special piece.
/// The state is unchanged; no turn or randomness is consumed.
final class SwapRejected extends GameEvent {
  final PlayerSlot player;
  final CellPos firstCell;
  final CellPos secondCell;
  final String reason;
  const SwapRejected({
    required this.player,
    required this.firstCell,
    required this.secondCell,
    required this.reason,
  });
}

/// Pieces cleared by a colour match. [points] is flat:
/// `cells.length * kPointsPerPiece`.
final class Cleared extends GameEvent {
  final PlayerSlot player;
  final List<CellPos> cells;
  final int points;
  const Cleared({
    required this.player,
    required this.cells,
    required this.points,
  });
}

/// A special piece created by a match. [orientation] is set only for
/// [SpecialKind.line].
final class SpecialCreated extends GameEvent {
  final PlayerSlot player;
  final SpecialKind kind;
  final LineOrientation? orientation;
  final CellPos cell;
  const SpecialCreated({
    required this.player,
    required this.kind,
    required this.orientation,
    required this.cell,
  });
}

/// A special piece fired by a swap. [cells] are the pieces it removed;
/// [points] is flat per piece.
final class SpecialFired extends GameEvent {
  final PlayerSlot player;
  final SpecialKind kind;
  final List<CellPos> cells;
  final int points;
  const SpecialFired({
    required this.player,
    required this.kind,
    required this.cells,
    required this.points,
  });
}

/// One gravity movement of a single piece.
final class Fell extends GameEvent {
  final PlayerSlot player;
  final CellPos from;
  final CellPos to;
  const Fell({required this.player, required this.from, required this.to});
}

/// A deterministic refill piece entering [cell]. [piece] is a regular
/// colour code in `0..colourCount-1`.
final class Refilled extends GameEvent {
  final PlayerSlot player;
  final CellPos cell;
  final int piece;
  const Refilled({required this.player, required this.cell, required this.piece});
}

/// Obstacles earned during [sourceRound] for the opponent's next round.
/// [player] is the player who will receive them.
final class ObstacleQueued extends GameEvent {
  final PlayerSlot player;
  final int sourceRound;
  final int count;
  const ObstacleQueued({
    required this.player,
    required this.sourceRound,
    required this.count,
  });
}

/// Obstacles appearing on [player]'s board at the start of a round.
final class ObstacleLanded extends GameEvent {
  final PlayerSlot player;
  final List<CellPos> cells;
  const ObstacleLanded({required this.player, required this.cells});
}

/// Obstacles consumed: boxes broken by adjacent clears and yarn locks
/// released because their piece was cleared.
final class ObstacleBroken extends GameEvent {
  final PlayerSlot player;
  final List<CellPos> cells;
  const ObstacleBroken({required this.player, required this.cells});
}

/// Power charge changed by [amount] (a signed delta, documented
/// consistently). Emitted only when the charge actually changes.
final class PowerCharged extends GameEvent {
  final PlayerSlot player;
  final int amount;
  const PowerCharged({required this.player, required this.amount});
}

/// A power resolved. [cells] are the affected piece cells and [points] the
/// flat score for removed pieces.
final class PowerFired extends GameEvent {
  final PlayerSlot player;
  final PowerKind power;
  final List<CellPos> cells;
  final int points;
  const PowerFired({
    required this.player,
    required this.power,
    required this.cells,
    required this.points,
  });
}

/// The board was deterministically reshuffled because no legal move
/// remained. [cells] lists every permuted piece cell in row-major order.
final class Shuffled extends GameEvent {
  final PlayerSlot player;
  final List<CellPos> cells;
  final String reason;
  const Shuffled({required this.player, required this.cells, required this.reason});
}

/// A match of four or more awarded one extra move this round.
/// [movesRemaining] is the player's total after the award.
final class ExtraMove extends GameEvent {
  final PlayerSlot player;
  final int round;
  final int movesRemaining;
  const ExtraMove({
    required this.player,
    required this.round,
    required this.movesRemaining,
  });
}

/// A round boundary snapshot. [outcome] is `null` while the match continues
/// and carries the final result on the last round.
final class RoundEnded extends GameEvent {
  final int round;
  final ScorePair scores;
  final MatchOutcome? outcome;
  const RoundEnded({required this.round, required this.scores, required this.outcome});
}

/// Terminal result with per-player final state hashes.
final class MatchEnded extends GameEvent {
  final MatchOutcome outcome;
  final ScorePair scores;
  final HashPair finalHashes;
  const MatchEnded({
    required this.outcome,
    required this.scores,
    required this.finalHashes,
  });
}

/// Stable machine-readable error codes. UI maps these to text; they are
/// never localized inside the engine.
enum EngineErrorCode {
  /// Config failed validation (dimensions, colours, versions, ...).
  invalidConfig,

  /// [MatchConfig.engineVersion] is not supported by this engine.
  unsupportedEngineVersion,

  /// The match already produced an outcome.
  matchFinished,

  /// Move is structurally invalid: bad coordinates, non-adjacent cells,
  /// blocked/locked cells, bad power target, and similar.
  invalidMove,

  /// Power fired without enough charge.
  insufficientCharge,

  /// A replay log step failed; [EngineError.details] carries `position`
  /// and `reason`.
  replayDivergence,
}

/// Typed engine error with a stable [code] and non-localized [message].
class EngineError {
  final EngineErrorCode code;
  final String message;
  final Map<String, Object?> details;

  const EngineError(this.code, this.message, [this.details = const {}]);

  @override
  String toString() => 'EngineError(${code.name}: $message)';
}

/// Result of an engine operation that can reject input.
sealed class EngineResult<T> {
  const EngineResult();
}

/// Successful result carrying [value].
final class EngineOk<T> extends EngineResult<T> {
  final T value;
  const EngineOk(this.value);
}

/// Rejected result carrying a typed [error].
final class EngineFailure<T> extends EngineResult<T> {
  final EngineError error;
  const EngineFailure(this.error);
}

/// Outcome of [applyMove]: the new state, ordered events and the state
/// hash before and after the transition.
class MoveResult {
  final MatchState state;
  final List<GameEvent> events;
  final String hashBefore;
  final String hashAfter;

  const MoveResult({
    required this.state,
    required this.events,
    required this.hashBefore,
    required this.hashAfter,
  });
}

/// Outcome of [replay]: the final state, its hash and how many log entries
/// were applied.
class ReplayResult {
  final MatchState state;
  final String hash;
  final int movesApplied;

  const ReplayResult({
    required this.state,
    required this.hash,
    required this.movesApplied,
  });
}
