import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_dialogs.dart';
import 'board_game.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'duel_audio.dart';
import 'duel_events.dart';
import 'match_controller.dart';
import 'online/emotes.dart';
import 'profile.dart';
import 'shell/house_tour.dart';
import 'ui_widgets.dart';
import 'vs_screen.dart';
import 'widgets/battle_hud.dart';
import 'widgets/board_vfx_overlay.dart';

/// Compile-time switch for the frame-time profiling overlay. Build a release
/// APK/AAB with `--dart-define=CPA_FRAME_PROBE=true` to profile on device.
const kFrameProbeEnabled = bool.fromEnvironment('CPA_FRAME_PROBE');

const _muted = Color(0xffe8c9a0);
const _faint = Color(0xffd8b48f);

/// Preset emotes offered in the duel. Only these wire values ever leave the
/// device (contract: preset emotes only, never free text). The new
/// `assets/images/` sticker art backs six presets; generated sprites stay
/// as fallbacks and the caption disambiguates at send time.
const _emoteItems = [
  ('emote_happy', 'SALUT', Emote.hello),
  ('emote_surprised', 'WOW', Emote.wow),
  ('emote_cheer', 'BRAVO', Emote.goodGame),
  ('emote_surprised', 'OPS', Emote.oops),
  ('emote_happy', 'MERCI', Emote.thanks),
  ('emote_laugh', 'PURR', Emote.purr),
];

/// Sprite shown for a received preset emote.
String emoteSpriteFor(Emote emote) => switch (emote) {
  Emote.hello || Emote.thanks => 'emote_happy',
  Emote.wow || Emote.oops => 'emote_surprised',
  Emote.goodGame => 'emote_cheer',
  Emote.purr => 'emote_laugh',
};

/// New-art name -> generated fallback, for sticker images.
const _emoteFallback = {
  'emote_happy': 'emote_love',
  'emote_cheer': 'emote_laugh',
  'emote_surprised': 'emote_laugh',
  'emote_laugh': 'emote_laugh',
};

/// Sticker image: `assets/images/` art first, generated sprite fallback.
Widget _emoteImage(String name, double size) => arenaImage(
  name,
  width: size,
  height: size,
  fallback: sprite(_emoteFallback[name] ?? name, size: size),
);

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.player,
    required this.mode,
    this.botLevel,
    this.legacyRace,
    this.opponent,
    this.online,
    this.seed,
  });
  final Player player;
  final int mode;

  /// Test hook: fixed engine seed; null picks a random one.
  final int? seed;

  /// House-cat difficulty (0–2); defaults to the controller's pick.
  final int? botLevel;

  /// Test hook: forces the legacy 90-second race regardless of the
  /// `CPA_LEGACY_RACE` dart-define.
  final bool? legacyRace;

  /// House Tour opponent (lane-4 request): when set, the duel starts
  /// against this house cat instead of a rotating house bot.
  final HouseCat? opponent;

  /// Live friend-duel session (lane-5 `MatchSession` wrapped in
  /// [OnlineDuel]): when set, the duel runs online 1v1.
  final OnlineDuel? online;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final ArenaMatchController match;
  late final AnimationController fx;
  late final DuelAudio _audio;
  late final DuelMusic _music;
  final _vfx = BoardVfxController();
  int _lastCountdown = -1;
  late final AnimationController _momentFx;
  final _boardKey = GlobalKey<BoardViewState>();
  Timer? emoteTimer;
  String emote = '';
  String opponentEmote = '';
  Timer? opponentEmoteTimer;
  StreamSubscription<Emote>? _emoteSub;
  bool showingDialog = false;
  PowerKind? _momentPower;
  Player get p => widget.player;
  int get power {
    final raw = p.cat == 'Tzuki'
        ? 0
        : p.cat == 'Bubble'
        ? 1
        : p.power;
    return raw >= 0 && raw < powers.length ? raw : 0;
  }

  int get modeIndex =>
      widget.mode >= 0 && widget.mode < modeNames.length ? widget.mode : 0;
  String get modeName => modeNames[modeIndex];

  /// Debug-only escape hatch: keeps the old 90-second race reachable via
  /// `--dart-define=CPA_LEGACY_RACE=true` until Gate 1 is decided.
  static const _legacyRace = bool.fromEnvironment('CPA_LEGACY_RACE');

  @override
  void initState() {
    super.initState();
    match = ArenaMatchController(
      p,
      widget.mode,
      botLevel: widget.botLevel ?? 1,
      legacyRace: widget.legacyRace ?? _legacyRace,
      opponent: widget.opponent == null
          ? null
          : BotOpponent(
              name: widget.opponent!.name,
              trophies: widget.opponent!.trophies,
              level: widget.opponent!.level,
            ),
      online: widget.online,
      seed: widget.seed,
    );
    match.eventSink = (events) {
      _boardKey.currentState?.play(events);
    };
    _emoteSub = match.opponentEmotes.listen((e) {
      if (!mounted) return;
      setState(() => opponentEmote = emoteSpriteFor(e));
      opponentEmoteTimer?.cancel();
      opponentEmoteTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => opponentEmote = '');
      });
    });
    _audio = DuelAudio(enabled: () => p.sfx, hapticsEnabled: () => p.haptics);
    _music = DuelMusic(enabled: () => p.music);
    p.addListener(_music.sync);
    match.addListener(_matchListener);
    _music.sync();
    _momentFx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    fx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    match.pause(background: state != AppLifecycleState.resumed);
    _music.setBackgrounded(state != AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      // Catch up on opponent moves and match-record changes missed while
      // the app was suspended (the 20 s poll covers the rest).
      unawaited(match.refreshOnline());
    }
  }

  @override
  void dispose() {
    emoteTimer?.cancel();
    opponentEmoteTimer?.cancel();
    _emoteSub?.cancel();
    fx.dispose();
    _momentFx.dispose();
    _vfx.dispose();
    _audio.dispose();
    p.removeListener(_music.sync);
    match.removeListener(_matchListener);
    _music.dispose();
    WidgetsBinding.instance.removeObserver(this);
    match.dispose();
    super.dispose();
  }

  /// Countdown warning for the last four seconds of a turn — one tick
  /// per second boundary, plus music start/stop when the phase changes.
  void _matchListener() {
    _music.sync();
    final s = match.turnSecondsLeft;
    if (s != _lastCountdown) {
      _lastCountdown = s;
      if (s > 0 && s <= 4 && match.phase == MatchPhase.playing) {
        _audio.countdownTick();
      }
    }
  }

  /// Sound + haptic feedback, the non-blocking board VFX layer and the
  /// full-screen power moment, fired as each contract event's animation
  /// starts on the board.
  void _onBoardEvent(BoardEvent event) {
    _audio.play(event);
    _emitVfx(event);
    if (event is PowerFired) {
      setState(() => _momentPower = event.power);
      _momentFx.forward(from: 0);
    }
  }

  /// Maps contract events onto the non-blocking overlay: particles on
  /// clears, beams on rockets, shockwaves on bombs/copters, the laser
  /// cross, and floating score labels. Positions arrive as flat cell
  /// indices; the painter wants (col, row) grid coordinates.
  void _emitVfx(BoardEvent event) {
    Offset at(int i) => Offset((i % 7).toDouble(), (i ~/ 7).toDouble());
    Offset centroid(List<int> cells) {
      var x = 0.0, y = 0.0;
      for (final i in cells) {
        x += i % 7;
        y += i ~/ 7;
      }
      return Offset(x / cells.length, y / cells.length);
    }

    switch (event) {
      case Cleared(:final cells, :final points):
        for (final i in cells.take(10)) {
          _vfx.emit(BoardVfxEvent(type: BoardVfxType.tilePop, normalizedPos: at(i)));
        }
        if (cells.isNotEmpty && points > 0) {
          _vfx.emit(
            BoardVfxEvent(
              type: BoardVfxType.tilePop,
              normalizedPos: centroid(cells),
              color: const Color(0x00000000),
              label: '+$points',
            ),
          );
        }
      case SpecialFired(:final cells, :final kind, :final points):
        if (cells.isEmpty) return;
        final c = centroid(cells);
        final type = switch (kind) {
          SpecialKind.lineHorizontal => BoardVfxType.rocketRow,
          SpecialKind.lineVertical => BoardVfxType.rocketCol,
          SpecialKind.bomb => BoardVfxType.bombShockwave,
          SpecialKind.copter => BoardVfxType.bombShockwave,
          SpecialKind.rainbow => BoardVfxType.zoomiesBurst,
          SpecialKind.none => BoardVfxType.tilePop,
        };
        _vfx.emit(
          BoardVfxEvent(
            type: type,
            normalizedPos: c,
            label: points > 0 ? '+$points' : null,
            duration: const Duration(milliseconds: 560),
          ),
          shake: kind == SpecialKind.bomb ? 0.5 : 0.25,
        );
      case ObstacleBroken(:final cells, :final points):
        for (final i in cells.take(8)) {
          _vfx.emit(
            BoardVfxEvent(
              type: BoardVfxType.boxBreak,
              normalizedPos: at(i),
              color: const Color(0xffd9a05b),
            ),
          );
        }
        if (cells.isNotEmpty && points > 0) {
          _vfx.emit(
            BoardVfxEvent(
              type: BoardVfxType.boxBreak,
              normalizedPos: centroid(cells),
              color: const Color(0x00000000),
              label: '+$points',
            ),
          );
        }
      case PowerFired(:final cells, :final power, :final points):
        if (cells.isEmpty) return;
        final c = centroid(cells);
        final type = switch (power) {
          PowerKind.laserChase => BoardVfxType.laserCross,
          PowerKind.shadowPounce => BoardVfxType.shadowClaw,
          PowerKind.zoomies => BoardVfxType.zoomiesBurst,
        };
        _vfx.emit(
          BoardVfxEvent(
            type: type,
            normalizedPos: c,
            label: points > 0 ? '+$points' : null,
            duration: const Duration(milliseconds: 620),
          ),
          shake: 0.4,
        );
      case Shuffled():
        _vfx.emit(
          BoardVfxEvent(
            type: BoardVfxType.zoomiesBurst,
            normalizedPos: const Offset(3, 3),
            duration: const Duration(milliseconds: 350),
          ),
        );
      default:
        break;
    }
  }

  /// Cancels the pre-match search and leaves: no duel ever started, so
  /// no confirmation and no penalty. The PopScope only allows the pop
  /// after `leaveSearch` flips the phase to finished on the next build.
  void _leaveSearch() {
    match.leaveSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> surrender() async {
    if (showingDialog || match.phase == MatchPhase.finished) return;
    showingDialog = true;
    match.pause(modal: true);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Renunți la meci?',
          textAlign: TextAlign.center,
          style: TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            arenaImage(
              'emote_surprised',
              width: 62,
              height: 62,
              fallback: sprite('emote_angry', size: 62),
            ),
            const SizedBox(height: 8),
            Text(
              match.isOnline
                  ? 'Meciul se anulează pentru amândoi — fără recompense.'
                  : 'Vei pierde 25 de trofee.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff8a6242),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(
              'CONTINUĂ',
              style: TextStyle(
                color: Color(0xff8a6242),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'RENUNȚĂ',
              style: TextStyle(
                color: Color(0xffb23c31),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    showingDialog = false;
    match.pause(modal: false);
    if (yes == true) match.forfeit();
  }

  void emotes() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0x55a97153),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Alege un emote',
              style: TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
              children: [
                for (final item in _emoteItems)
                  // Only emotes unlocked on the trophy road can be sent.
                  if (p.unlockedEmotes.contains(item.$3.wire))
                    _EmoteCard(
                    spriteName: item.$1,
                    caption: item.$2,
                    onTap: () {
                      Navigator.pop(c);
                      emoteTimer?.cancel();
                      setState(() => emote = item.$1);
                      emoteTimer = Timer(const Duration(seconds: 2), () {
                        if (mounted) setState(() => emote = '');
                      });
                      match.sendEmote(item.$3);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: match,
      builder: (context, _) => PopScope(
        canPop: match.phase == MatchPhase.finished,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (match.phase == MatchPhase.searching) {
            _leaveSearch();
          } else {
            surrender();
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              if (match.phase == MatchPhase.playing) ...[
                Positioned.fill(
                  child: arenaImage(
                    'bg_arena_battle',
                    fit: BoxFit.cover,
                    fallback: RoomBackground(
                      tier: p.tier,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x6620130e),
                    ),
                  ),
                ),
              ],
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: switch (match.phase) {
                    // Searching and result are the same full-bleed scenes
                    // as the VS page — one continuous page, no HUD swap.
                    // Both manage their own inner SafeArea so their art can
                    // climb behind the system bars instead of leaving brown
                    // scaffold bands at the top and bottom.
                    MatchPhase.searching => versus(),
                    MatchPhase.finished => result(),
                    MatchPhase.playing => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: battle(),
                      ),
                    ),
                  },
                ),
              ),
                if (_momentPower != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _momentFx,
                        builder: (context, _) => PowerMoment(
                          power: _momentPower!,
                          t: _momentFx.value,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
    return kFrameProbeEnabled ? FrameTimeOverlay(child: content) : content;
  }

  /// The searching phase reuses the VS [MatchupScene] so moving from the
  /// pre-match page into the match reads as a single continuous screen.
  Widget versus() => MatchupScene(
    english: p.english,
    modeText: match.isOnline ? 'PRIETEN ONLINE' : 'ANTRENAMENT OFFLINE',
    playerName: p.name,
    playerTrophies: p.trophies,
    playerBadge: p.english ? 'YOU' : 'TU',
    playerPortrait: duelCatArt(p, size: 118),
    opponentName: match.botName,
    opponentTrophies: match.botTrophies,
    // The 'ANTRENAMENT OFFLINE' mode pill above already labels the bot;
    // the card and the in-match HUD keep the name clean (spec §5).
    opponentBadge: match.isOnline ? 'PRIETEN' : '',
    opponentPortrait: Center(child: _opponentAvatar(84)),
    opponentSubtitle: match.isOnline
        ? 'Prieten'
        : match.opponent == null
        ? null
        : match.botLevelName,
    statusText: match.isOnline
        ? 'Se pregătește meciul...'
        : 'Se caută adversarul...',
    cancelKey: const ValueKey('match-cancel'),
    cancelText: 'RENUNȚĂ',
    // Cancelling the search just leaves — no duel ever started, so no
    // confirmation and no penalty.
    onCancel: _leaveSearch,
    middle: match.isEngine && match.opponent == null && !match.isOnline
        ? _botLevelPicker()
        : null,
    pulse: fx,
  );

  /// Opponent avatar: the friend's cat loadout for online duels, the
  /// resident house cat's look for House Tour battles, otherwise the
  /// generic bot head.
  Widget _opponentAvatar(double size) {
    final online = widget.online;
    return online != null
        ? catPortrait(online.opponent.cat, size: size)
        : catPortrait('${widget.opponent ?? ''}', size: size);
  }

  /// House-cat difficulty, pickable while the VS phase searches.
  Widget _botLevelPicker() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < ArenaMatchController.botLevelNames.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _LevelChip(
            label: ArenaMatchController.botLevelNames[i],
            selected: match.botLevel == i,
            onTap: () => match.botLevel = i,
          ),
        ),
    ],
  );

  /// Reference top HUD: portrait columns (name, ringed avatar, score
  /// plate) flanking the turn banner, the clock and the round badge.
  /// The active side's ring glows — gold for the player, blue for the
  /// opponent; the opponent plate carries the sabotage `xN` badge.
  Widget _battleTopHud() {
    final yourTurn = match.playerTurn;
    final enginePlaying = match.isEngine && match.phase == MatchPhase.playing;
    final seconds = match.isEngine ? match.turnSecondsLeft : match.remaining;
    final total = match.isEngine ? match.turnSecondsTotal : 90;
    final round = ((match.turn - 1) ~/ 2 + 1).clamp(1, match.turnsPerPlayer);
    final roundsUsed = (match.turnsPerPlayer -
            match.playerTurnsLeft +
            (yourTurn ? 1 : 0))
        .clamp(0, match.turnsPerPlayer);
    return BattleTopHud(
      playerAvatar: catPortrait(p.cat, size: 52),
      playerName: p.name,
      playerScore: match.playerScore,
      playerActive: enginePlaying ? yourTurn : true,
      roundsUsed: roundsUsed,
      roundsTotal: match.turnsPerPlayer,
      playerIncoming: match.incomingObstacles.length,
      playerEmote: emote.isEmpty ? null : _EmoteBubble(emote),
      opponentAvatar: _opponentAvatar(52),
      opponentName: match.botName,
      opponentScore: match.botScore,
      opponentActive: enginePlaying && !yourTurn && !match.isFlagged,
      opponentIncoming: match.outgoingObstacles,
      opponentEmote: opponentEmote.isEmpty ? null : _EmoteBubble(opponentEmote),
      onOpponentTap: _opponentDetails,
      banner: !match.isEngine
          ? 'LUPTĂ!'
          : yourTurn
          ? 'TURA TA'
          : 'TURA LUI ${match.botName.toUpperCase()}',
      seconds: seconds,
      clockProgress: total > 0 ? seconds / total : 0,
      round: round,
      pulse: fx,
      onSettingsTap: _pauseMenu,
    );
  }

  /// Gear menu during the duel: resume, open the shared settings sheet
  /// (music/SFX/haptics) or surrender the match.
  Future<void> _pauseMenu() async {
    match.pause(modal: true);
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0x55a97153),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              ArenaButton(
                text: 'CONTINUĂ',
                onPressed: () => Navigator.pop(c, 'resume'),
              ),
              const SizedBox(height: 8),
              ArenaButton(
                text: 'SETĂRI',
                onPressed: () => Navigator.pop(c, 'settings'),
              ),
              const SizedBox(height: 8),
              ArenaButton(
                key: const Key('pause-surrender'),
                text: 'RENUNȚĂ',
                onPressed: () => Navigator.pop(c, 'surrender'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (pick == 'settings') await showSettings(context, p);
    if (!mounted) return;
    match.pause(modal: false);
    if (pick == 'surrender') surrender();
  }

  /// Small popup with the opponent's match-provided details — never
  /// fabricated stats: house cats show BOT + level/difficulty + trophies;
  /// online friends show the preset-safe fields the match carries.
  void _opponentDetails() {
    final online = match.online;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff6b4636),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: gold, width: 1.4),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _opponentAvatar(64),
            const SizedBox(height: 8),
            label(match.botName, size: 18),
            const SizedBox(height: 2),
            label(online != null ? 'PRIETEN' : 'BOT', size: 12, color: _muted),
            const SizedBox(height: 10),
            _StatRow(icon: 'icon_trophy', text: '${match.botTrophies} trofee'),
            if (online != null)
              _StatRow(
                icon: powers[online.opponent.power.clamp(0, powers.length - 1)],
                text:
                    powerNames[online.opponent.power.clamp(
                      0,
                      powerNames.length - 1,
                    )],
              )
            else if (match.opponent != null)
              _StatRow(
                icon: 'icon_paw_coin',
                text:
                    'Nivel ${match.opponent!.level} • '
                    '${ArenaMatchController.botLevelNames[match.botLevel]}',
              )
            else
              _StatRow(
                icon: 'icon_paw_coin',
                text:
                    'Dificultate ${ArenaMatchController.botLevelNames[match.botLevel]}',
              ),
          ],
        ),
      ),
    );
  }

  /// Bottom action bar strictly under the board: the 3D power button
  /// (~70%) with the equipped power icon, charge bar and ACTIVEAZĂ! at
  /// 100%, beside the 3D turquoise EMOTE button (~30%).
  Widget _bottomActionBar() {
    final idx = PowerKind.values.indexOf(match.playerPower).clamp(0, 2);
    final charge = match.playerCharge;
    return BattleBottomActionBar(
      powerIcon: powerIcons[idx],
      powerFallback: _PowerBadge(
        charge: charge / 100,
        full: charge >= 100,
        spriteName: powers[idx],
        pulse: fx,
      ),
      powerLabel: const ['ZOOMIES', 'POUNCE', 'LASER'][idx],
      charge: charge,
      canFire:
          charge >= 100 && match.playerTurn && match.acceptingInput,
      onPower: () => match.firePower(match.playerPower),
      onEmote: emotes,
      pulse: fx,
    );
  }

  /// 24-hour slow-play claim: offered only after `session.deadline` has
  /// passed with the turn on the opponent (lane-5 match-sync contract).
  Widget _forfeitBanner() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: ArenaButton(
      text: 'Adversarul a întârziat — revendică victoria',
      green: true,
      singleLine: true,
      onPressed: () => unawaited(match.claimForfeit()),
    ),
  );

  /// First-match coach mark: explains the three-move round and highlights
  /// a suggested swap on the board.
  Widget _tutorialOverlay() {
    if (!match.tutorialActive) return const SizedBox.shrink();
    final texts = [
      'Prima ta luptă! Ai 15 secunde pe rând — tura se termină singură.',
      'Schimbă două piese alăturate de aceeași culoare. Urmează indicatorul auriu!',
      'Când bara de putere e plină, atinge-o ca s-o declanșezi!',
    ];
    final text = texts[match.playerMoves.clamp(0, texts.length - 1)];
    // In-flow coach mark between the HUD and the board — it never sits
    // over the 7×7 cells and never eats a button.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xee3a2418),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold, width: 1.3),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: cream,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  /// Battle scene from the mockup: the reference top HUD (portraits,
  /// turn banner, clock, round badge), the luminous-framed 7×7 board
  /// and the bottom action bar — nothing sits over the board's cells.
  Widget battle() => Column(
    children: [
      _battleTopHud(),
      if (match.tutorialActive) _tutorialOverlay(),
      if (match.canClaimForfeit) ...[
        const SizedBox(height: 4),
        _forfeitBanner(),
      ],
      const SizedBox(height: 8),
      Expanded(child: _board()),
      const SizedBox(height: 8),
      _bottomActionBar(),
    ],
  );

  Widget _board() {
    final hint = match.hintSwap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        // Luminous frame: gold while the player holds the turn, blue
        // while the opponent does.
        final yours = match.playerTurn || !match.isEngine;
        final frame = yours ? gold : const Color(0xff7ec8ff);
        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: side,
            height: side,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: yours
                    ? const [Color(0xffb57f2e), Color(0xff7a4f1e)]
                    : const [Color(0xff5f83b8), Color(0xff35507a)],
              ),
              border: Border.all(color: frame, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: frame.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Color(0x66000000),
                  offset: Offset(0, 5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BoardView(
                      key: _boardKey,
                      initial: match.initialSnapshot,
                      onSwapAttempt: match.tryMove,
                      onEvent: _onBoardEvent,
                      onIdle: match.onBoardIdle,
                      inputEnabled: match.myTurnInput,
                      active: match.phase != MatchPhase.finished,
                      suspended: match.paused,
                      hintCells: hint == null ? null : {hint.$1, hint.$2},
                    ),
                  ),
                  // Non-blocking VFX layer: particles, beams, shockwaves
                  // and floating labels render over the 7×7 grid without
                  // eating gestures (IgnorePointer inside the widget).
                  Positioned.fill(
                    child: BoardVfxOverlay(controller: _vfx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Full-bleed result scene like the reference win/lose pages: room art
  /// behind, warm tint for victory / cool tint for defeat, big cartoon
  /// title, the cat front and centre with the golden fish on a win, the
  /// stakes panel and the two actions.
  Widget result() {
    final aborted = match.abortReason != null;
    final flagged = match.isFlagged;
    final outcome = match.result ?? 0;
    final win = outcome > 0;
    final loss = outcome < 0;
    final draw = !win && !loss;
    final title = aborted
        ? (flagged ? 'REZULTAT INVALIDAT' : 'MECI ÎNTRERUPT')
        : win
        ? 'VICTORIE!'
        : loss
        ? 'ÎNFRÂNGERE'
        : 'EGALITATE';
    final titleColor = loss ? const Color(0xff9fd4ff) : gold;
    return Stack(
      fit: StackFit.expand,
      children: [
        arenaImage(
          'bg_living_room',
          fit: BoxFit.cover,
          fallback: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xff241d3f), Color(0xff3a2a5e)],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: loss
                  ? const [
                      Color(0xd91d2f5e),
                      Color(0xa61d2f5e),
                      Color(0xe6141f42),
                    ]
                  : const [
                      Color(0xc23d2a12),
                      Color(0x8f3d2a12),
                      Color(0xe62a1a0c),
                    ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: fx,
                  builder: (context, child) => Transform.scale(
                    scale: win || draw || aborted ? 1 + 0.04 * fx.value : 1,
                    child: child,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            color: loss
                                ? const Color(0xff12254a)
                                : const Color(0xff6b3a12),
                            offset: const Offset(0, 3),
                          ),
                          const Shadow(
                            color: Color(0xaa000000),
                            offset: Offset(0, 6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (aborted) ...[
                  const SizedBox(height: 4),
                  label(
                    _abortText(match.abortReason!),
                    size: 13,
                    color: _muted,
                  ),
                ],
                const SizedBox(height: 4),
                label(
                  '${match.playerScore} — ${match.botScore}',
                  size: 26,
                  color: Colors.white,
                ),
                if (match.isEngine) ...[
                  const SizedBox(height: 2),
                  label(
                    'vs ${match.botName} (${match.isOnline ? 'PRIETEN' : 'BOT'}) • '
                    '${match.turnsPerPlayer} turnuri',
                    size: 12,
                    color: _muted,
                  ),
                ],
                const Spacer(),
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      duelCatArt(p, size: 190),
                      if (win)
                        Positioned(
                          right: 4,
                          bottom: 34,
                          child: Transform.rotate(
                            angle: .12,
                            child: arenaImage(
                              'trophy_gold_fish',
                              height: 74,
                              fit: BoxFit.contain,
                              fallback: sprite('icon_trophy', size: 64),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (aborted)
                  _abortRewards()
                else if (match.isOnline && match.rewardsPending)
                  _pendingRewards()
                else if (match.isOnline && !match.rewardsCounted)
                  _deniedRewards()
                else
                  _resultRewards(win, loss),
                const SizedBox(height: 12),
                if (!aborted && !match.isOnline)
                  ArenaButton(
                    text: 'REVANȘĂ',
                    green: true,
                    spriteName: 'btn_play_paw',
                    onPressed: match.isEngine
                        ? match.rematch
                        : () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MatchScreen(player: p, mode: widget.mode),
                            ),
                          ),
                  ),
                ArenaButton(
                  text: 'ACASĂ',
                  secondary: true,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 4),
                label(modeName, size: 11, color: _faint),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _abortText(OnlineAbort reason) => switch (reason) {
    OnlineAbort.flagged =>
      'Verificarea meciului a eșuat — meci neverificat, fără recompense.',
    OnlineAbort.connectionLost =>
      'Conexiunea s-a pierdut — meci anulat, fără recompense.',
    OnlineAbort.surrendered => 'Ai părăsit meciul — fără recompense.',
  };

  Widget _abortRewards() => panel(
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'Fără trofee și fără lăbuțe la meciurile anulate.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xff8a6242),
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  /// Online result while both phones' finals are still arriving.
  Widget _pendingRewards() => panel(
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'Se confirmă rezultatul cu adversarul…',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xff8a6242),
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  /// Online result that settled without counting: finals disagreed or a
  /// flag landed — trophies and paws are never awarded.
  Widget _deniedRewards() => panel(
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'REZULTAT NEVERIFICAT — fără trofee, fără lăbuțe.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xff8a6242),
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  /// Wooden rewards board like the reference result pages: on a win the
  /// two columns list trophies and paws; a defeat stays calm — a single
  /// '-25 Trofee' row, matching the contract stakes exactly.
  Widget _resultRewards(bool win, bool loss) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff8a5a34), Color(0xff6b422a), Color(0xff54311f)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffd9a05f), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: loss
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                sprite('icon_trophy', size: 30),
                const SizedBox(width: 9),
                const Text(
                  '-25 Trofee',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xffffd0c4),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            )
          : win
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _rewardColumn('icon_trophy', '+30', 'TROFEE'),
                Container(
                  width: 1.4,
                  height: 40,
                  color: const Color(0x66d9a05f),
                ),
                _rewardColumn('icon_paw_coin', '+150', 'LĂBUȚE'),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                sprite('icon_trophy', size: 30),
                const SizedBox(width: 9),
                const Text(
                  '0 Trofee',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xfff0d9b0),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _rewardColumn(String icon, String value, String caption) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          sprite(icon, size: 26),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xffffe28b),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 1))],
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        caption,
        style: const TextStyle(
          color: Color(0xfff0d9b0),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    ],
  );
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? const Color(0xff8a5a3b) : const Color(0x33ffffff),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? gold : const Color(0x55ffc63c),
          width: selected ? 1.8 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? cream : _muted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _PowerBadge extends StatelessWidget {
  const _PowerBadge({
    required this.charge,
    required this.full,
    required this.spriteName,
    required this.pulse,
  });

  final double charge;
  final bool full;
  final String spriteName;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (context, _) => Transform.scale(
      scale: full ? 1 + 0.06 * pulse.value : 1,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: charge.clamp(0.0, 1.0),
                strokeWidth: 4.5,
                backgroundColor: const Color(0x44ffffff),
                valueColor: AlwaysStoppedAnimation<Color>(
                  full ? gold : const Color(0xff7ed957),
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff33231d),
                border: Border.all(
                  color: full ? gold : const Color(0x66ffc63c),
                  width: 1.4,
                ),
              ),
              child: Center(child: sprite(spriteName, size: 24)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One icon + text row inside the opponent-details popup.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.text});
  final String icon, text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        sprite(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: cream,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmoteBubble extends StatelessWidget {
  const _EmoteBubble(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: const Color(0xe8fff3d0),
      shape: BoxShape.circle,
      border: Border.all(color: ink, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          offset: Offset(0, 3),
          blurRadius: 6,
        ),
      ],
    ),
    child: _emoteImage(name, 42),
  );
}

class _EmoteCard extends StatelessWidget {
  const _EmoteCard({
    required this.spriteName,
    required this.caption,
    required this.onTap,
  });
  final String spriteName, caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xfff8ecd0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffb57f4e), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x333c241a),
              offset: Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _emoteImage(spriteName, 56),
            const SizedBox(height: 6),
            Text(
              caption,
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Full-screen moment for a fired power: golden ZOOM! trail for Zoomies, a
/// purple vortex for Shadow Pounce, a sweeping red laser dot for Laser Chase.
/// Driven by [t] in 0..1 from the caller's animation controller.
class PowerMoment extends StatelessWidget {
  const PowerMoment({super.key, required this.power, required this.t});

  final PowerKind power;
  final double t;

  @override
  Widget build(BuildContext context) {
    // Fade in fast, hold, fade out over the last third.
    final opacity =
        (t / 0.12).clamp(0.0, 1.0) * ((1 - t) / 0.3).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      key: Key('power-moment-${power.name}'),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _MomentPainter(power: power, t: t),
            ),
            // Power banner centred inside the frame: emblem + title in a
            // framed pill, with real margins — nothing clips the edges.
            Positioned(
              top: constraints.maxHeight * 0.06,
              left: 14,
              right: 14,
              child: Center(
                child: Transform.scale(
                  scale:
                      0.6 +
                      0.5 *
                          Curves.easeOutBack.transform(
                            (t / 0.25).clamp(0.0, 1.0),
                          ),
                  child: _PowerBanner(power: power),
                ),
              ),
            ),
            // Board VFX: the power's effect sprite zooms/pulses over the
            // centre of the board, well inside the frame — no edge clips.
            Center(
              child: _EffectBurst(power: power, t: t),
            ),
          ],
        ),
      ),
    );
  }
}

/// Framed banner shown at the top of the power moment: the power's emblem
/// (`assets/images/` art with a graceful fallback chain) and its display
/// name, inside a wooden pill that never reaches the screen edges.
class _PowerBanner extends StatelessWidget {
  const _PowerBanner({required this.power});
  final PowerKind power;

  /// Emblem candidates per power, tried in order under `assets/images/`.
  static const _emblems = {
    PowerKind.zoomies: ['zoomies_emblem', 'power_zoomies'],
    PowerKind.shadowPounce: ['power_shadow_pounce'],
    PowerKind.laserChase: ['power_laser_chase'],
  };

  /// First bundled candidate wins; missing art hides gracefully (the
  /// banner keeps its title text either way).
  Widget _emblem(List<String> names) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Image.asset(
      'assets/images/${names.first}.png',
      width: 40,
      height: 40,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _emblem(names.sublist(1)),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff8a5a44), Color(0xff54342a)],
      ),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: gold, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x77000000),
          offset: Offset(0, 4),
          blurRadius: 10,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _emblem(_emblems[power] ?? const []),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              powerNames[power.index].toUpperCase(),
              style: const TextStyle(
                color: Color(0xffffd166),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                shadows: [
                  Shadow(color: Color(0xaa7a4a00), blurRadius: 10),
                  Shadow(color: Color(0x66000000), offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The power's board VFX sprite (`assets/images/effect_*.png`): zooms in
/// with a pulse over the first ~40% of the moment, then settles. Alpha
/// art renders cleanly over the board with no edge clipping.
class _EffectBurst extends StatelessWidget {
  const _EffectBurst({required this.power, required this.t});
  final PowerKind power;
  final double t;

  @override
  Widget build(BuildContext context) {
    final idx = power.index.clamp(0, powerEffects.length - 1);
    final inT = (t / 0.4).clamp(0.0, 1.0);
    final scale =
        0.5 +
        0.75 * Curves.easeOutBack.transform(inT) -
        0.15 * Curves.easeInOut.transform(((t - 0.4) / 0.6).clamp(0.0, 1.0));
    final pulse = t > 0.4 && t < 0.75 ? 1 + 0.06 * math.sin(t * math.pi * 10) : 1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide * 0.55;
        return Transform.scale(
          scale: scale * pulse,
          child: arenaImage(
            powerEffects[idx],
            width: side,
            height: side,
            fallback: const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _MomentPainter extends CustomPainter {
  _MomentPainter({required this.power, required this.t});

  final PowerKind power;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide;
    switch (power) {
      case PowerKind.zoomies:
        // Golden radial streaks racing outward.
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.012
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 14; i++) {
          final a = i * math.pi / 7 + t * math.pi * 0.6;
          final reach = r * (0.18 + 0.5 * ((t + i * 0.07) % 1));
          paint.color = Color.lerp(
            const Color(0xffffe08a),
            const Color(0xffc8862a),
            (i / 14),
          )!.withValues(alpha: 0.75 * (1 - t * 0.6));
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * r * 0.08,
            c + Offset(math.cos(a), math.sin(a)) * reach,
            paint,
          );
        }
      case PowerKind.shadowPounce:
        // Purple vortex: spiral arms winding inward.
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.02
          ..strokeCap = StrokeCap.round;
        for (var arm = 0; arm < 3; arm++) {
          final path = Path();
          for (var s = 0; s <= 40; s++) {
            final u = s / 40;
            final ang =
                arm * math.pi * 2 / 3 + u * math.pi * 3 + t * math.pi * 4;
            final rad = r * (0.5 - 0.42 * u) * (1 - t * 0.25);
            final pt = c + Offset(math.cos(ang), math.sin(ang)) * rad;
            if (s == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          paint.color = const Color(0xffb46bff)
              .withValues(alpha: 0.8 * (1 - t * 0.5));
          canvas.drawPath(path, paint);
        }
        paint.style = PaintingStyle.fill;
        paint.color = const Color(0xff4a1d8f).withValues(alpha: 0.35);
        canvas.drawCircle(c, r * 0.16 * (1 - t * 0.4), paint);
      case PowerKind.laserChase:
        // Red laser dot sweeping a beam across the screen.
        final sweep = (math.sin(t * math.pi * 2) + 1) / 2;
        final dotX = size.width * sweep;
        final beam = Paint()
          ..color = const Color(0xffff3b30).withValues(alpha: 0.5)
          ..strokeWidth = r * 0.008;
        canvas.drawLine(Offset(dotX, 0), Offset(dotX, size.height), beam);
        final dotC = Offset(dotX, size.height * (0.3 + 0.4 * sweep));
        canvas.drawCircle(
          dotC,
          r * 0.05,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xffff5040).withValues(alpha: 0.95),
                const Color(0xffff5040).withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: dotC, radius: r * 0.05)),
        );
    }
  }

  @override
  bool shouldRepaint(_MomentPainter old) => old.t != t || old.power != power;
}

/// Debug-only frame-time probe: shows FPS and worst frame ms so a human can
/// profile a release build on a real phone. Enabled at compile time with
/// `--dart-define=CPA_FRAME_PROBE=true`; hidden entirely otherwise.
class FrameTimeOverlay extends StatefulWidget {
  const FrameTimeOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<FrameTimeOverlay> createState() => _FrameTimeOverlayState();
}

class _FrameTimeOverlayState extends State<FrameTimeOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  Duration _windowStart = Duration.zero;
  int _frames = 0;
  double _worstMs = 0;
  double _fps = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (elapsed < _last) {
      _last = elapsed;
      return;
    }
    final dt = elapsed - _last;
    _last = elapsed;
    if (_windowStart == Duration.zero) _windowStart = elapsed;
    _frames++;
    final ms = dt.inMicroseconds / 1000;
    if (ms > _worstMs) _worstMs = ms;
    final windowMs = (elapsed - _windowStart).inMicroseconds / 1000;
    if (windowMs >= 500) {
      _fps = _frames * 1000 / windowMs;
      _frames = 0;
      _worstMs = 0;
      _windowStart = elapsed;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      Positioned(
        top: 2,
        right: 6,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xcc000000),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_fps.toStringAsFixed(0)} FPS · ${_worstMs.toStringAsFixed(1)} ms',
              key: const Key('frame-probe'),
              style: const TextStyle(
                color: Color(0xff2e7d32),
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
