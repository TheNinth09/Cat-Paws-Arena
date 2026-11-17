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
const _modeIcons = [Icons.group, Icons.bolt, Icons.shield, Icons.emoji_events];
const _powerShort = ['ZOOMIES', 'SHADOW POUNCE', 'LASER CHASE'];

/// Preset emotes offered in the duel. Only these wire values ever leave the
/// device (contract: preset emotes only, never free text). Three sprites
/// back six presets; the caption disambiguates at send time.
const _emoteItems = [
  ('emote_laugh', 'SALUT', Emote.hello),
  ('emote_laugh', 'WOW', Emote.wow),
  ('emote_love', 'BRAVO', Emote.goodGame),
  ('emote_angry', 'OPS', Emote.oops),
  ('emote_love', 'MERCI', Emote.thanks),
  ('emote_love', 'PURR', Emote.purr),
];

/// Sprite shown for a received preset emote.
String emoteSpriteFor(Emote emote) => switch (emote) {
  Emote.hello || Emote.wow => 'emote_laugh',
  Emote.oops => 'emote_angry',
  _ => 'emote_love',
};

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
    _audio = DuelAudio(enabled: () => p.sfx);
    _momentFx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
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
    WidgetsBinding.instance.removeObserver(this);
    match.dispose();
    super.dispose();
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
            sprite('emote_angry', size: 62),
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
        if (!didPop) surrender();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    children: [
                      if (match.phase != MatchPhase.playing)
                        PlayerHud(
                          avatar: CatAvatar(p, size: 46),
                          name: p.name,
                          trophies: p.trophies,
                          coins: p.coins,
                          onProfile: () => showPlayerProfile(context, p),
                          onRoad: () => showTrophyRoad(context, p),
                          onShop: () => showAppDialog(
                            context,
                            'Lăbuțe',
                            const Text(
                              'Pachetele sunt disponibile în fila Magazin din ecranul principal.',
                            ),
                          ),
                          onMenu: () => showSettings(context, p),
                        ),
                      Expanded(
                        child: RoomBackground(
                          tier: p.tier,
                          dim: true,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                            child: switch (match.phase) {
                              MatchPhase.searching => versus(),
                              MatchPhase.playing => battle(),
                              MatchPhase.finished => result(),
                            },
                          ),
                        ),
                      ),
                    ],
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
    ),
    );
    return kFrameProbeEnabled ? FrameTimeOverlay(child: content) : content;
  }

  Widget versus() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
    children: [
      Center(
        child: _ModeChip(icon: _modeIcons[modeIndex], text: modeName),
      ),
      const SizedBox(height: 9),
      label(match.isOnline ? 'PRIETEN ONLINE' : 'ANTRENAMENT OFFLINE', size: 24),
      const SizedBox(height: 3),
      label(
        match.isOnline
            ? 'Meci prieteni • provocare 1v1'
            : 'Adversar bot • ±75 trofee',
        size: 13,
        color: _muted,
      ),
      const SizedBox(height: 18),
      Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _FighterCard(
                  tag: 'TU',
                  avatar: CatAvatar(p, size: 48),
                  name: p.name,
                  detail: '${p.trophies} trofee',
                ),
              ),
              const SizedBox(width: 56),
              Expanded(
                child: _FighterCard(
                  tag: match.isOnline ? 'PRIETEN' : 'BOT',
                  avatar: _opponentAvatar(48),
                  name: match.botName,
                  detail:
                      '${match.botLevelName} • ${match.botTrophies} trofee',
                ),
              ),
            ],
          ),
          AnimatedBuilder(
            animation: fx,
            builder: (context, _) => Transform.scale(
              scale: 1 + 0.07 * fx.value,
              child: const _VsBadge(size: 66),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (match.isEngine && match.opponent == null && !match.isOnline)
        _botLevelPicker(),
      if (match.isEngine && match.opponent == null && !match.isOnline)
        const SizedBox(height: 10),
      _rewardsPanel(),
      const SizedBox(height: 14),
      _searching(),
      const SizedBox(height: 14),
      ArenaButton(text: 'RENUNȚĂ', danger: true, onPressed: surrender),
      const SizedBox(height: 4),
    ],
  );

  Widget _rewardsPanel() => panel(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            sprite('icon_trophy', size: 26),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'RECOMPENSE',
                style: TextStyle(
                  color: Color(0xff8a5a3b),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _rewardLine('icon_trophy', 'Victorie', '+30 trofee'),
        _rewardLine('icon_paw_coin', 'Bonus', '+150 lăbuțe'),
        const SizedBox(height: 6),
        const Text(
          'Egalitate: 0 trofee • Înfrângere: -25 trofee',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff8a6242),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _rewardLine(String icon, String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        sprite(icon, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            key,
            style: const TextStyle(
              color: ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xff9a5b23),
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _searching() => AnimatedBuilder(
    animation: fx,
    builder: (context, _) {
      Widget dot(int i) {
        final wave = 0.5 + 0.5 * math.sin((fx.value * 2 - i * 0.33) * math.pi);
        return Transform.translate(
          offset: Offset(0, -3 * wave),
          child: Opacity(
            opacity: 0.3 + 0.7 * wave,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: gold,
                boxShadow: [BoxShadow(color: Color(0x66ffc63c), blurRadius: 6)],
              ),
            ),
          ),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                dot(i),
                if (i < 2) const SizedBox(width: 9),
              ],
            ],
          ),
          const SizedBox(height: 9),
          label(
            match.isOnline ? 'Se pregătește meciul...' : 'Se caută adversarul...',
            size: 15,
            color: _muted,
          ),
        ],
      );
    },
  );

  /// Opponent avatar: the friend's cat loadout for online duels, the
  /// resident house cat's look for House Tour battles, otherwise the
  /// generic bot head.
  Widget _opponentAvatar(double size) {
    final online = widget.online;
    if (online != null) {
      // Synthetic player carrying only the opponent's visual fields; it is
      // never saved, exactly like houseCatPlayer for house cats.
      final spec = Player(p.prefs)
        ..name = online.opponent.name
        ..cat = online.opponent.cat
        ..trophies = online.opponent.trophies
        ..coins = 0
        ..fur = online.opponent.fur
        ..eyes = online.opponent.eyes
        ..ears = online.opponent.ears
        ..pattern = online.opponent.pattern
        ..accessory = online.opponent.accessory
        ..power = online.opponent.power
        ..photo = null;
      return CatAvatar(spec, size: size, allowPhoto: false);
    }
    return widget.opponent == null
        ? _BotHead(size: size)
        : CatAvatar(houseCatPlayer(p.prefs, widget.opponent!), size: size);
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
    final enginePlaying =
        match.isEngine && match.phase == MatchPhase.playing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _PortraitPlate(
              avatar: CatAvatar(p, size: 50),
              name: p.name,
              score: match.playerScore,
              charge: match.playerCharge,
              ringColor: const Color(0xff7ed957),
              accentColor: gold,
              meterColor: const Color(0xff7ed957),
              iconSprite: 'tile_yarn',
              active: match.playerTurn,
              emote: emote,
              pulse: fx,
            ),
          ),
          const SizedBox(width: 6),
          const _VsBadge(size: 40),
          const SizedBox(width: 6),
          Expanded(
            child: _PortraitPlate(
              avatar: _opponentAvatar(50),
              name: match.isOnline
                  ? match.botName
                  : '${match.botName} · BOT',
              score: match.botScore,
              charge: match.botCharge,
              ringColor: const Color(0xff9d6bff),
              accentColor: const Color(0xffc9a6ff),
              meterColor: const Color(0xff9d6bff),
              iconSprite: 'icon_paw_coin',
              active: enginePlaying && !match.playerTurn && !match.isFlagged,
              emote: opponentEmote,
              pulse: fx,
            ),
          ),
        ],
      ),
    );
  }

  /// Turn strip: whose turn it is, seconds left and queued obstacles;
  /// the local player can end their turn early with GATA.
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
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (match.isEngine && yourTurn) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: match.endTurn,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff3f7d33),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffbfe6b4)),
                ),
                child: const Text(
                  'GATA',
                  style: TextStyle(
                    color: cream,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
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
      'Prima ta luptă! Ai 30 de secunde pe rând — poți termina devreme cu GATA.',
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

  Widget _scoreStrip() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        Expanded(
          child: _ScoreChip(
            avatar: CatAvatar(p, size: 36),
            name: p.name,
            score: match.playerScore,
          ),
        ),
        const SizedBox(width: 6),
        const _VsBadge(size: 32),
        const SizedBox(width: 6),
        Expanded(
          child: _ScoreChip(
            avatar: _opponentAvatar(36),
            name: match.isOnline
                ? match.botName
                : '${match.botName} · BOT',
            score: match.botScore,
          ),
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
                    inputEnabled: match.acceptingInput,
                    active: match.phase != MatchPhase.finished,
                    suspended: match.paused,
                    hintCells: hint == null ? null : {hint.$1, hint.$2},
                  ),
                ),
                if (opponentEmote.isNotEmpty)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: IgnorePointer(child: _EmoteBubble(opponentEmote)),
                  ),
                if (emote.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IgnorePointer(child: _EmoteBubble(emote)),
                  ),
                // Small white cat button, bottom-right: preset emotes.
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _EmoteCatButton(onTap: emotes),
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

  Widget _powerDeck() => Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: BoxDecoration(
      gradient: _panelGradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x66ffc63c), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44000000),
          offset: Offset(0, 3),
          blurRadius: 8,
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            sprite(powers[PowerKind.values.indexOf(match.playerPower)], size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                key: const Key('power-meter'),
                behavior: HitTestBehavior.opaque,
                onTap: match.playerCharge >= 100 && match.acceptingInput
                    ? () => match.firePower(match.playerPower)
                    : null,
                child: _ChargeBar(
                  value: match.playerCharge / 100,
                  full: match.playerCharge >= 100,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 54,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  match.playerCharge >= 100
                      ? 'GATA!'
                      : '${match.playerCharge}%',
                  style: TextStyle(
                    color: match.playerCharge >= 100
                        ? const Color(0xffb9e07a)
                        : gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: powerNames[PowerKind.values.indexOf(match.playerPower)],
                child: ArenaButton(
                  text: match.playerCharge >= 100
                      ? 'APASĂ PENTRU PUTERE!'
                      : '${_powerShort[PowerKind.values.indexOf(match.playerPower)]} • ${match.playerCharge}%',
                  spriteName:
                      powers[PowerKind.values.indexOf(match.playerPower)],
                  singleLine: true,
                  onPressed: match.playerCharge >= 100 && match.playerTurn
                      ? () => match.firePower(match.playerPower)
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '4 / 5 piese → obstacol • Cascade → combo',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _faint,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget result() {
    final aborted = match.abortReason != null;
    final flagged = match.isFlagged;
    final outcome = match.result ?? 0;
    final win = outcome > 0;
    final loss = outcome < 0;
    final draw = !win && !loss;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      children: [
        Center(
          child: AnimatedBuilder(
            animation: fx,
            builder: (context, _) => Transform.scale(
              scale: win || draw || aborted ? 1 + 0.03 * fx.value : 1,
              child: _ResultEmblem(win: win, draw: draw || aborted),
            ),
          ),
        ),
        const SizedBox(height: 10),
        label(
          aborted
              ? (flagged ? 'REZULTAT INVALIDAT' : 'MECI ÎNTRERUPT')
              : win
              ? 'VICTORIE!'
              : loss
              ? 'ÎNFRÂNGERE'
              : 'EGALITATE',
          size: 30,
        ),
        if (aborted) ...[
          const SizedBox(height: 4),
          label(_abortText(match.abortReason!), size: 13, color: _muted),
        ],
        const SizedBox(height: 2),
        label(
          '${match.playerScore} — ${match.botScore}',
          size: 24,
          color: gold,
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
        const SizedBox(height: 14),
        _scoreStrip(),
        const SizedBox(height: 12),
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
        const SizedBox(height: 6),
        label(modeName, size: 12, color: _faint),
      ],
    );
  }

  static String _abortText(OnlineAbort reason) => switch (reason) {
    OnlineAbort.flagged =>
      'Verificarea meciului a eșuat — meci neverificat, fără recompense.',
    OnlineAbort.connectionLost =>
      'Conexiunea s-a pierdut — meci anulat, fără recompense.',
    OnlineAbort.surrendered =>
      'Ai părăsit meciul — fără recompense.',
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

  Widget _resultRewards(bool win, bool loss) => panel(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            sprite('icon_trophy', size: 30),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                win
                    ? '+30 Trofee • +150 Lăbuțe'
                    : loss
                    ? '-25 Trofee'
                    : '0 Trofee',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            sprite('icon_chest', size: 62),
            const SizedBox(width: 14),
            CatAvatar(p, size: 82),
          ],
        ),
      ],
    ),
  );
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff7a4a32), Color(0xff5d3a2c)],
      ),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: gold, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x5545312d),
          offset: Offset(0, 2),
          blurRadius: 6,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: gold),
        const SizedBox(width: 7),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: cream,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
            shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 1))],
          ),
        ),
      ],
    ),
  );
}

class _FighterCard extends StatelessWidget {
  const _FighterCard({
    required this.tag,
    required this.avatar,
    required this.name,
    required this.detail,
  });
  final String tag, name, detail;
  final Widget avatar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xe66b4636), Color(0xe64e322b)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x66ffc63c), width: 1.4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          offset: Offset(0, 4),
          blurRadius: 8,
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: gold,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ink, width: 1.2),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              color: ink,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 6),
        avatar,
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: cream,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 1))],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            sprite('icon_trophy', size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: gold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BotHead extends StatelessWidget {
  const _BotHead({this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: CatPainter(const Color(0xff2e3040), 1, gold, 1),
    ),
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

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.avatar,
    required this.name,
    required this.score,
  });
  final Widget avatar;
  final String name;
  final int score;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xd66b4636), Color(0xd64e322b)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x66ffc63c), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44000000),
          offset: Offset(0, 2),
          blurRadius: 5,
        ),
      ],
    ),
    child: Row(
      children: [
        avatar,
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: cream,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$score',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
            'Tura $turn • ${seconds}s',
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
    required this.score,
    required this.charge,
    required this.ringColor,
    required this.accentColor,
    required this.meterColor,
    required this.iconSprite,
    required this.active,
    required this.emote,
    required this.pulse,
  });

  final Widget avatar;
  final String name;
  final int score;
  final int charge;
  final Color ringColor;
  final Color accentColor;
  final Color meterColor;
  final String iconSprite;
  final bool active;
  final String emote;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          child: Text(
            name,
            maxLines: 1,
            style: const TextStyle(
              color: cream,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 1))],
            ),
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
        if (emote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: IgnorePointer(child: _EmoteBubble(emote)),
          ),
      ],
    );
  }
}

/// Small white cat button (bottom-right of the board) opening the preset
/// emote sheet. Procedural cat face — no sprite dependency.
class _EmoteCatButton extends StatelessWidget {
  const _EmoteCatButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Emote',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xf5fff8ea),
          border: Border.all(color: ink, width: 1.6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              offset: Offset(0, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: CustomPaint(painter: _CatFacePainter()),
      ),
    ),
  );
}

class _CatFacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..color = const Color(0xff5a3a26);
    // Ears.
    final ear = Path()
      ..moveTo(c.dx - size.width * 0.32, c.dy - size.height * 0.08)
      ..lineTo(c.dx - size.width * 0.30, c.dy - size.height * 0.38)
      ..lineTo(c.dx - size.width * 0.10, c.dy - size.height * 0.20)
      ..close()
      ..moveTo(c.dx + size.width * 0.32, c.dy - size.height * 0.08)
      ..lineTo(c.dx + size.width * 0.30, c.dy - size.height * 0.38)
      ..lineTo(c.dx + size.width * 0.10, c.dy - size.height * 0.20)
      ..close();
    canvas.drawPath(ear, paint);
    // Eyes.
    canvas.drawCircle(
      Offset(c.dx - size.width * 0.13, c.dy - size.height * 0.02),
      size.width * 0.055,
      paint,
    );
    canvas.drawCircle(
      Offset(c.dx + size.width * 0.13, c.dy - size.height * 0.02),
      size.width * 0.055,
      paint,
    );
    // Nose + smile.
    final nose = Paint()..color = const Color(0xffb0607a);
    canvas.drawCircle(Offset(c.dx, c.dy + size.height * 0.10), size.width * 0.05, nose);
  }

  @override
  bool shouldRepaint(_CatFacePainter old) => false;
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

class _ChargeBar extends StatelessWidget {
  const _ChargeBar({required this.value, this.full = false});
  final double value;

  /// Full meter: gold glow so the tap-to-fire affordance reads clearly.
  final bool full;

  @override
  Widget build(BuildContext context) => Container(
    height: 13,
    decoration: BoxDecoration(
      color: const Color(0xff33231d),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: full ? const Color(0xfffff3c4) : const Color(0x66ffc63c),
        width: full ? 1.8 : 1.2,
      ),
      boxShadow: full
          ? const [
              BoxShadow(
                color: Color(0x88ffd166),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ]
          : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xfffff3c4), gold, Color(0xffe8961f)],
              ),
            ),
          ),
        ),
      ),
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
    child: sprite(name, size: 42),
  );
}

class _ResultEmblem extends StatelessWidget {
  const _ResultEmblem({required this.win, required this.draw});
  final bool win, draw;

  @override
  Widget build(BuildContext context) {
    final colors = win
        ? const [Color(0xfffff3c4), gold, Color(0xffe8961f)]
        : draw
        ? const [Color(0xfff2e2c4), Color(0xffd9b98a), Color(0xffc4a06e)]
        : const [Color(0xffc9806a), Color(0xffa5553f), Color(0xff7c3a2e)];
    final icon = win
        ? 'icon_trophy'
        : draw
        ? 'emote_love'
        : 'emote_angry';
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: ink, width: 3),
        boxShadow: [
          BoxShadow(
            color: win ? const Color(0x66ffc63c) : const Color(0x44000000),
            blurRadius: win ? 26 : 12,
            offset: win ? Offset.zero : const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xfffff8e0), Color(0xfff0d6a0)],
            ),
            border: Border.all(color: const Color(0x66b57f4e), width: 1.5),
          ),
          child: Center(child: sprite(icon, size: 60)),
        ),
      ),
    );
  }
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
            sprite(spriteName, size: 56),
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
    final opacity = (t / 0.12).clamp(0.0, 1.0) * ((1 - t) / 0.3).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      key: Key('power-moment-${power.name}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _MomentPainter(power: power, t: t)),
          // Power banner: "MIDNIGHT ZOOMIES"-style title across the top.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.scale(
                scale: 0.6 + 0.5 * Curves.easeOutBack.transform(
                  (t / 0.25).clamp(0.0, 1.0),
                ),
                child: Text(
                  powerNames[power.index].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xffffd166),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(color: Color(0xaa7a4a00), blurRadius: 14),
                      Shadow(color: Color(0x66000000), offset: Offset(0, 3)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Cat runner crossing the board and smashing pieces.
          Positioned.fill(child: _CatRunner(t: t)),
          if (power == PowerKind.zoomies)
            Center(
              child: Transform.scale(
                scale: 0.7 + 0.5 * Curves.easeOutBack.transform(t),
                child: const Text(
                  'ZOOM!',
                  style: TextStyle(
                    color: Color(0xffffd166),
                    fontSize: 84,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(color: Color(0xaa7a4a00), blurRadius: 18),
                      Shadow(color: Color(0x66000000), offset: Offset(0, 3)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cat sprinting across the board during the power moment. Tries the
/// lane-1 runner sprite under `assets/images/cat_run.png`; falls back to
/// a procedural cat when the sprite is absent.
class _CatRunner extends StatelessWidget {
  const _CatRunner({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    // Run window: enter ~12%, cross by ~85% of the moment.
    final u = ((t - 0.12) / 0.73).clamp(0.0, 1.0);
    if (u <= 0 || u >= 1) return const SizedBox.shrink();
    final ease = Curves.easeInOut.transform(u);
    final bounce = math.sin(u * math.pi * 6) * 6 * (1 - u);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final catSize = h * 0.16;
        return Stack(
          children: [
            // Motion streaks behind the runner.
            for (var i = 0; i < 3; i++)
              Positioned(
                left: w * ease - catSize * (1.4 + i * 0.5),
                top: h * 0.62 + bounce + i * 7 - catSize * 0.5,
                child: Container(
                  width: catSize * (0.5 + i * 0.2),
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xffffe08a).withValues(
                      alpha: 0.7 * (1 - u),
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            Positioned(
              left: w * ease - catSize / 2,
              top: h * 0.62 + bounce - catSize / 2,
              child: SizedBox(
                width: catSize,
                height: catSize,
                child: Image.asset(
                  'assets/images/cat_run.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) =>
                      CustomPaint(painter: _RunnerCatPainter()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Procedural running-cat fallback for [_CatRunner].
class _RunnerCatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.shortestSide;
    final body = Paint()..color = const Color(0xfff4a259);
    final dark = Paint()..color = const Color(0xff8a4b2a);
    // Body: leaning ellipse.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.95, height: s * 0.62),
      body,
    );
    // Head.
    canvas.drawCircle(Offset(s * 0.34, -s * 0.18), s * 0.26, body);
    // Ears.
    final ear = Path()
      ..moveTo(s * 0.22, -s * 0.34)
      ..lineTo(s * 0.30, -s * 0.52)
      ..lineTo(s * 0.42, -s * 0.36)
      ..close()
      ..moveTo(s * 0.40, -s * 0.36)
      ..lineTo(s * 0.50, -s * 0.52)
      ..lineTo(s * 0.54, -s * 0.32)
      ..close();
    canvas.drawPath(ear, dark);
    // Eye + legs blur lines.
    canvas.drawCircle(Offset(s * 0.40, -s * 0.20), s * 0.045, dark);
    canvas.restore();
    final leg = Paint()
      ..color = dark.color.withValues(alpha: 0.6)
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(s * 0.05 + i * s * 0.14, s * 0.34),
        Offset(s * 0.02 + i * s * 0.14, s * 0.5),
        leg,
      );
    }
  }

  @override
  bool shouldRepaint(_RunnerCatPainter old) => false;
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
            final ang = arm * math.pi * 2 / 3 + u * math.pi * 3 + t * math.pi * 4;
            final rad = r * (0.5 - 0.42 * u) * (1 - t * 0.25);
            final pt = c + Offset(math.cos(ang), math.sin(ang)) * rad;
            if (s == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          paint.color = const Color(0xffb46bff).withValues(
            alpha: 0.8 * (1 - t * 0.5),
          );
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
        canvas.drawLine(
          Offset(dotX, 0),
          Offset(dotX, size.height),
          beam,
        );
        final dot = Paint()
          ..color = const Color(0xffff5040).withValues(alpha: 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(dotX, size.height * (0.3 + 0.4 * sweep)), r * 0.05, dot);
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
