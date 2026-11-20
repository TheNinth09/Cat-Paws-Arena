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

/// Compile-time switch for the frame-time profiling overlay. Build a release
/// APK/AAB with `--dart-define=CPA_FRAME_PROBE=true` to profile on device.
const kFrameProbeEnabled = bool.fromEnvironment('CPA_FRAME_PROBE');

const _muted = Color(0xffe8c9a0);
const _faint = Color(0xffd8b48f);
const _panelGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xd66b4636), Color(0xd64e322b)],
);
const _barGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xff8a5a44), Color(0xff54342a)],
);

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
    _audio.dispose();
    p.removeListener(_music.sync);
    match.removeListener(_matchListener);
    _music.dispose();
    WidgetsBinding.instance.removeObserver(this);
    match.dispose();
    super.dispose();
  }

  /// Countdown warning for the last five seconds of a turn — one tick
  /// per second boundary, plus music start/stop when the phase changes.
  void _matchListener() {
    _music.sync();
    final s = match.turnSecondsLeft;
    if (s != _lastCountdown) {
      _lastCountdown = s;
      if (s > 0 && s <= 5 && match.phase == MatchPhase.playing) {
        _audio.countdownTick();
      }
    }
  }

  /// Sound + haptic feedback and the full-screen power moment, fired as each
  /// contract event's animation starts on the board.
  void _onBoardEvent(BoardEvent event) {
    _audio.play(event);
    if (event is PowerFired) {
      setState(() => _momentPower = event.power);
      _momentFx.forward(from: 0);
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

  Future<void> pause() async {
    match.pause(modal: true);
    await showSettings(context, p);
    if (mounted) match.pause(modal: false);
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
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: switch (match.phase) {
                      // Searching and result are the same full-bleed scenes
                      // as the VS page — one continuous page, no HUD swap.
                      MatchPhase.searching => versus(),
                      MatchPhase.finished => result(),
                      MatchPhase.playing => Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: battle(),
                      ),
                    },
                  ),
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
    // the card keeps its name clean — the in-match BOT tag stays.
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

  /// VS header from the gameplay mockup: circular portraits with power
  /// meters — the player's ring is green/gold with a yarn icon, the
  /// opponent's is purple with a paw icon. The active side's ring pulses.
  /// Emote bubbles sit beside the portraits.
  Widget _versusHeader() {
    final enginePlaying = match.isEngine && match.phase == MatchPhase.playing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _PortraitPlate(
              avatar: catPortrait(p.cat, size: 50),
              name: p.name,
              score: match.playerScore,
              charge: match.playerCharge,
              ringColor: const Color(0xff7ed957),
              accentColor: gold,
              meterColor: const Color(0xff7ed957),
              iconSprite: 'tile_yarn',
              active: match.playerTurn,
              pulse: fx,
              emote: emote,
            ),
          ),
          const SizedBox(width: 6),
          const _VsBadge(size: 40),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _opponentDetails,
              child: _PortraitPlate(
                avatar: _opponentAvatar(50),
                name: match.botName,
                tag: match.isOnline ? 'PRIETEN' : 'BOT',
                score: match.botScore,
                charge: match.botCharge,
                ringColor: const Color(0xff9d6bff),
                accentColor: const Color(0xffc9a6ff),
                meterColor: const Color(0xff9d6bff),
                iconSprite: 'icon_paw_coin',
                active: enginePlaying && !match.playerTurn && !match.isFlagged,
                pulse: fx,
                emote: opponentEmote,
              ),
            ),
          ),
        ],
      ),
    );
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

  /// Turn strip: whose turn it is, seconds left and queued obstacles.
  /// The turn ends when the 30 s clock expires (the controller writes the
  /// EndTurnMove) — there is no end-early button.
  Widget _turnStrip() {
    final incoming = match.incomingObstacles;
    final yourTurn = match.playerTurn;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x66ffffff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33ffc63c)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: yourTurn
                        ? 'RÂNDUL TĂU'
                        : '${match.botName.toUpperCase()} MUTĂ',
                    style: TextStyle(
                      color: yourTurn ? const Color(0xff3f7d33) : ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text:
                        '  •  ${match.turnSecondsLeft}s'
                        '${incoming.isEmpty ? '' : '  •  ${incoming.length} cutie vin'}',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (match.bonusSeconds > 0)
                    TextSpan(
                      text: '  +${match.bonusSeconds}s',
                      style: const TextStyle(
                        color: Color(0xff3f7d33),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
    return Positioned(
      left: 10,
      right: 10,
      bottom: 8,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
        ),
      ),
    );
  }

  /// Battle HUD: top bar (RENUNȚĂ / turn clock / settings), the VS header
  /// with both power meters, the turn strip (whose turn + end early) and
  /// the wooden board with the preset-emote cat button.
  Widget battle() => Column(
    children: [
      _battleBar(),
      const SizedBox(height: 4),
      _versusHeader(),
      const SizedBox(height: 2),
      _turnStrip(),
      if (match.canClaimForfeit) ...[
        const SizedBox(height: 4),
        _forfeitBanner(),
      ],
      const SizedBox(height: 4),
      Expanded(child: _board()),
      const SizedBox(height: 4),
      _powerDeck(),
    ],
  );

  Widget _battleBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      gradient: _barGradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x66ffc63c), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          offset: Offset(0, 3),
          blurRadius: 8,
        ),
      ],
    ),
    child: Row(
      children: [
        _MiniButton(
          icon: Icons.volunteer_activism,
          text: 'Renunță',
          danger: true,
          onTap: surrender,
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: match.isEngine
                  ? _TurnPill(
                      turn: match.turn,
                      turnsPerPlayer: match.turnsPerPlayer,
                      seconds: match.turnSecondsLeft,
                    )
                  : _TimerPill(seconds: match.remaining),
            ),
          ),
        ),
        _CircleButton(
          size: 40,
          tooltip: 'Setări',
          onTap: pause,
          child: const Icon(Icons.settings, color: cream, size: 21),
        ),
      ],
    ),
  );

  Widget _board() {
    final hint = match.hintSwap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return Center(
          child: Container(
            width: side,
            height: side,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xffa06a45), Color(0xff63432f)],
              ),
              border: Border.all(color: ink, width: 2.5),
              boxShadow: const [
                BoxShadow(
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
                  _tutorialOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Bottom control row under the board: the compact power button (~68%)
  /// with the equipped power icon, its charge bar and a clear label,
  /// next to the dedicated 3D emote button (~29%) — outside the 7×7 grid.
  Widget _powerDeck() {
    final idx = PowerKind.values.indexOf(match.playerPower);
    final charge = match.playerCharge;
    final full = charge >= 100;
    final canFire = full && match.playerTurn && match.acceptingInput;
    return AnimatedBuilder(
      animation: fx,
      builder: (context, _) => Row(
        children: [
          Expanded(
            flex: 68,
            child: GestureDetector(
              key: const Key('power-meter'),
              behavior: HitTestBehavior.opaque,
              onTap: canFire
                  ? () => match.firePower(match.playerPower)
                  : null,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: _panelGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: full ? gold : const Color(0x66ffc63c),
                    width: full ? 1.8 : 1.2,
                  ),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x44000000),
                      offset: Offset(0, 3),
                      blurRadius: 8,
                    ),
                    if (full)
                      BoxShadow(
                        color: const Color(0xffffc63c).withValues(
                          alpha: 0.3 + 0.3 * fx.value,
                        ),
                        blurRadius: 10 + 10 * fx.value,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: arenaImage(
                        powerIcons[idx],
                        width: 36,
                        height: 36,
                        fallback: _PowerBadge(
                          charge: charge / 100,
                          full: full,
                          spriteName: powers[idx],
                          pulse: fx,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              full
                                  ? '${_shortPowerName(idx)} • ACTIVEAZĂ!'
                                  : '${_shortPowerName(idx)} • $charge%',
                              maxLines: 1,
                              style: TextStyle(
                                color: full
                                    ? const Color(0xffb9e07a)
                                    : gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: (charge / 100).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: const Color(0x55ffffff),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                full ? gold : const Color(0xff7ed957),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 29, child: _emoteDeckButton()),
        ],
      ),
    );
  }

  /// Short power name for the compact deck label.
  String _shortPowerName(int idx) =>
      const ['ZOOMIES', 'POUNCE', 'LASER'][idx.clamp(0, 2)];

  /// The dedicated 3D emote button, fully outside the board.
  Widget _emoteDeckButton() => GestureDetector(
    key: const Key('emote-button'),
    behavior: HitTestBehavior.opaque,
    onTap: emotes,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff8fb4e8), Color(0xff3f6db0)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffd9ecff), width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Color(0x4400cfff),
            offset: Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  arenaImage('btn_emote', width: 22, height: 22),
                  const Text(
                    '💬',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            const Text(
              'EMOTE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                shadows: [
                  Shadow(color: Color(0x88000000), offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

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

class _VsBadge extends StatelessWidget {
  const _VsBadge({this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xfffff3c4), gold, Color(0xffe8961f)],
      ),
      border: Border.all(color: ink, width: 3),
      boxShadow: const [
        BoxShadow(color: Color(0x66ffc63c), blurRadius: 18),
        BoxShadow(
          color: Color(0x553c241a),
          offset: Offset(0, 4),
          blurRadius: 6,
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          top: size * 0.07,
          left: size * 0.18,
          right: size * 0.18,
          height: size * 0.3,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x80ffffff), Color(0x00ffffff)],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Text(
            'VS',
            style: TextStyle(
              color: ink,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              height: 1,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 10;
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    final color = urgent ? const Color(0xffff9d8f) : gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff33231d),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: urgent ? const Color(0xffff8d7e) : gold,
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$m:$s',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Turn indicator for the engine duel: turn number out of each player's
/// allotment plus the seconds left on the turn clock.
class _TurnPill extends StatelessWidget {
  const _TurnPill({
    required this.turn,
    required this.turnsPerPlayer,
    required this.seconds,
  });
  final int turn;
  final int turnsPerPlayer;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 10;
    final color = urgent ? const Color(0xffff9d8f) : gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff33231d),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: urgent ? const Color(0xffff8d7e) : gold,
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 15, color: gold),
          const SizedBox(width: 6),
          Text(
            'Tura $turn/${turnsPerPlayer * 2} • ${seconds}s',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular portrait plate from the gameplay mockup: ringed avatar, power
/// meter with a kind icon, name and score. [active] pulses the ring.
class _PortraitPlate extends StatelessWidget {
  const _PortraitPlate({
    required this.avatar,
    required this.name,
    this.tag,
    required this.score,
    required this.charge,
    required this.ringColor,
    required this.accentColor,
    required this.meterColor,
    required this.iconSprite,
    required this.active,
    required this.pulse,
    this.emote = '',
  });

  final Widget avatar;
  final String name;
  final String? tag;
  final int score;
  final int charge;
  final Color ringColor;
  final Color accentColor;
  final Color meterColor;
  final String iconSprite;
  final bool active;
  final Animation<double> pulse;

  /// Sprite name of the emote bubble shown under the plate ('' hides it).
  final String emote;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final glow = active ? 1 + 0.06 * pulse.value : 1.0;
            return Transform.scale(
              scale: glow,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? accentColor : ringColor,
                    width: active ? 3.4 : 2.8,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: meterColor.withValues(alpha: 0.55),
                            blurRadius: 10 + 4 * pulse.value,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 1.2),
                  ),
                  child: ClipOval(child: avatar),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              sprite(iconSprite, size: 15),
              const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (charge / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0x55ffffff),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      charge >= 100 ? accentColor : meterColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                style: const TextStyle(
                  color: cream,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
                  ],
                ),
              ),
              if (tag != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff3a2418),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: accentColor, width: 1),
                  ),
                  child: Text(
                    tag!,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            color: gold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
            ],
          ),
        ),
        ]),
        if (emote.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: -30,
            child: IgnorePointer(
              child: Center(child: _EmoteBubble(emote)),
            ),
          ),
      ],
    );
  }
}

/// House-cat difficulty chip on the VS screen.
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

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.text,
    required this.onTap,
    this.icon,
    this.danger = false,
  });
  final String text;
  final VoidCallback onTap;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: danger
                ? const [
                    Color(0xffffa58f),
                    Color(0xffe0655a),
                    Color(0xffb8402f),
                  ]
                : const [Color(0xff96684c), Color(0xff75503a)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: danger ? const Color(0xff7c2d22) : const Color(0x59ffe9bd),
            width: 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: cream),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: const TextStyle(
                color: cream,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.size,
    required this.onTap,
    required this.child,
    this.tooltip,
  });
  final double size;
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff96684c), Color(0xff64402f)],
            ),
            border: Border.all(color: const Color(0x59ffe9bd), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The power badge inside the battle power control: the chosen power's
/// sprite on a dark disc, ringed by a charge arc that turns gold at 100%
/// and pulses while the meter is full.
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
        final dot = Paint()
          ..color = const Color(0xffff5040).withValues(alpha: 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(
          Offset(dotX, size.height * (0.3 + 0.4 * sweep)),
          r * 0.05,
          dot,
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
