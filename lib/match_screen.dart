import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'board_game.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'match_controller.dart';
import 'profile.dart';
import 'ui_widgets.dart';

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
const _emoteItems = [
  ('emote_laugh', 'RÂDE'),
  ('emote_angry', 'FURIE'),
  ('emote_love', 'DRAGOSTE'),
];

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.player, required this.mode});
  final Player player;
  final int mode;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final ArenaMatchController match;
  late final AnimationController fx;
  final _boardKey = GlobalKey<BoardViewState>();
  Timer? emoteTimer;
  String emote = '';
  bool showingDialog = false;
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

  @override
  void initState() {
    super.initState();
    match = ArenaMatchController(p, widget.mode);
    match.eventSink = (events) {
      _boardKey.currentState?.play(events);
    };
    fx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    match.pause(background: state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    emoteTimer?.cancel();
    fx.dispose();
    WidgetsBinding.instance.removeObserver(this);
    match.dispose();
    super.dispose();
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
            const Text(
              'Vei pierde 25 de trofee.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
    if (yes == true) match.finish(-1);
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
            Row(
              children: [
                for (var i = 0; i < _emoteItems.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _EmoteCard(
                      spriteName: _emoteItems[i].$1,
                      caption: _emoteItems[i].$2,
                      onTap: () {
                        Navigator.pop(c);
                        emoteTimer?.cancel();
                        setState(() => emote = _emoteItems[i].$1);
                        emoteTimer = Timer(const Duration(seconds: 2), () {
                          if (mounted) setState(() => emote = '');
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: match,
    builder: (context, _) => PopScope(
      canPop: match.phase == MatchPhase.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) surrender();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
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
        ),
      ),
    ),
  );

  Widget versus() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
    children: [
      Center(
        child: _ModeChip(icon: _modeIcons[modeIndex], text: modeName),
      ),
      const SizedBox(height: 9),
      label('ANTRENAMENT OFFLINE', size: 24),
      const SizedBox(height: 3),
      label('Adversar bot • ±75 trofee', size: 13, color: _muted),
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
                  tag: 'BOT',
                  avatar: const _BotHead(size: 48),
                  name: 'Bubble Bot',
                  detail: '${match.botTrophies} trofee',
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
          label('Se caută adversarul...', size: 15, color: _muted),
        ],
      );
    },
  );

  Widget battle() => Column(
    children: [
      _battleBar(),
      const SizedBox(height: 4),
      _scoreStrip(),
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
              child: _TimerPill(seconds: match.remaining),
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
            score: match.board.score,
          ),
        ),
        const SizedBox(width: 6),
        const _VsBadge(size: 32),
        const SizedBox(width: 6),
        Expanded(
          child: _ScoreChip(
            avatar: const _BotHead(size: 36),
            name: 'Bubble Bot · BOT',
            score: match.botScore,
          ),
        ),
      ],
    ),
  );

  Widget _board() => LayoutBuilder(
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
                    onIdle: match.onBoardIdle,
                    inputEnabled: match.acceptingInput,
                    active: match.phase != MatchPhase.finished,
                    suspended: match.paused,
                  ),
                ),
                if (emote.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IgnorePointer(child: _EmoteBubble(emote)),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

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
            sprite(powers[power], size: 24),
            const SizedBox(width: 8),
            Expanded(child: _ChargeBar(value: match.board.charge / 100)),
            const SizedBox(width: 8),
            SizedBox(
              width: 54,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  match.board.charge >= 100
                      ? 'GATA!'
                      : '${match.board.charge}%',
                  style: TextStyle(
                    color: match.board.charge >= 100
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
                message: powerNames[power],
                child: ArenaButton(
                  text: '${_powerShort[power]} • ${match.board.charge}%',
                  spriteName: powers[power],
                  singleLine: true,
                  onPressed: match.board.charge >= 100
                      ? () => match.firePower(power)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CircleButton(
              size: 46,
              tooltip: 'Emote',
              onTap: emotes,
              child: sprite('emote_laugh', size: 27),
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
              scale: win || draw ? 1 + 0.03 * fx.value : 1,
              child: _ResultEmblem(win: win, draw: draw),
            ),
          ),
        ),
        const SizedBox(height: 10),
        label(
          win
              ? 'VICTORIE!'
              : loss
              ? 'ÎNFRÂNGERE'
              : 'EGALITATE',
          size: 34,
        ),
        const SizedBox(height: 2),
        label(
          '${match.board.score} — ${match.botScore}',
          size: 24,
          color: gold,
        ),
        const SizedBox(height: 14),
        _scoreStrip(),
        const SizedBox(height: 12),
        _resultRewards(win, loss),
        const SizedBox(height: 12),
        ArenaButton(
          text: 'REVANȘĂ',
          green: true,
          spriteName: 'btn_play_paw',
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MatchScreen(player: p, mode: widget.mode),
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
  const _ChargeBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    height: 13,
    decoration: BoxDecoration(
      color: const Color(0xff33231d),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0x66ffc63c), width: 1.2),
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
