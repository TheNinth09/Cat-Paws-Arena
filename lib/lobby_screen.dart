import 'package:flutter/material.dart';

import 'cat_avatar.dart';
import 'catalog.dart';
import 'profile.dart';
import 'shell/daily_board.dart';
import 'shell/house_tour.dart';
import 'shell/reward_calendar.dart';
import 'ui_widgets.dart';

const _cardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xffffe0a0), Color(0xffffedbb), Color(0xffe9ab60)],
);
const _stageGradient = RadialGradient(
  center: Alignment(0, -0.55),
  radius: 1.05,
  colors: [Color(0xfffff6d8), Color(0xfff4d9a0), Color(0xffe2a866)],
);
const _goldGradient = LinearGradient(
  colors: [Color(0xfffff3c4), gold, Color(0xffe8a92e)],
);

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    super.key,
    required this.player,
    required this.onBattle,
    required this.onRoad,
  });
  final Player player;
  final void Function(HouseCat cat) onBattle;
  final VoidCallback onRoad;
  Widget progress() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('trophy-progress'),
        onTap: onRoad,
        borderRadius: BorderRadius.circular(20),
        child: _TrophyCard(player: player),
      ),
    ),
  );
  Widget hero() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _HeroStage(player: player),
      const SizedBox(height: 8),
      label(player.cat, size: 24),
      const SizedBox(height: 4),
      _PowerPill(
        powerNames[player.cat == 'Tzuki'
            ? 0
            : player.cat == 'Bubble'
            ? 1
            : player.power],
      ),
    ],
  );
  Widget controls(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HouseTourCard(player: player, onBattle: onBattle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ReturnButton(
                title: 'CADOU ZILNIC',
                subtitle: '7 zile',
                onTap: () => showRewardCalendar(context, player),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ReturnButton(
                title: 'TABLA ZILEI',
                subtitle: 'scor zilnic',
                onTap: () => showDailyBoard(context, player),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          player.english
              ? 'House cats are labelled bots; matches stay local practice.'
              : 'Pisicile casei sunt boți etichetați; meciurile rămân antrenament local.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: cream,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (constraints.maxHeight < 580 || textScale > 1.3) {
        return ListView(
          key: const PageStorageKey('lobby-scroll'),
          padding: const EdgeInsets.only(bottom: 14),
          children: [
            progress(),
            const SizedBox(height: 4),
            Center(child: hero()),
            const SizedBox(height: 8),
            controls(context),
          ],
        );
      }
      return Column(
        children: [
          progress(),
          Expanded(
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: hero()),
            ),
          ),
          controls(context),
        ],
      );
    },
  );
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon(this.asset);
  final String asset;
  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: _goldGradient,
      border: Border.all(color: ink, width: 2.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x5561312d),
          offset: Offset(0, 3),
          blurRadius: 3,
        ),
      ],
    ),
    child: Center(child: sprite(asset, size: 30)),
  );
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    final ratio = (player.trophies / player.next).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: _cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6651312d),
            offset: Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          _BadgeIcon('icon_trophy'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'TROFEE',
                      style: TextStyle(
                        color: Color(0xff8a5a3b),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        player.room,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xff8a5a3b),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${player.trophies} / ${player.next}',
                      softWrap: false,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xff6c4244),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ink, width: 1.5),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio,
                      heightFactor: 1,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: _goldGradient,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Următoarea recompensă: ${player.next}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff7a4a32),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          sprite('icon_chest', size: 44),
        ],
      ),
    );
  }
}

class _HeroStage extends StatelessWidget {
  const _HeroStage({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 420),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: _stageGradient,
        border: Border.all(color: ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6651312d),
            offset: Offset(0, 5),
            blurRadius: 8,
          ),
        ],
      ),
      child: SizedBox(
        height: 245,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 6,
              left: 14,
              child: Opacity(
                opacity: 0.25,
                child: sprite('tile_paw', size: 30),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 14,
              child: Opacity(
                opacity: 0.25,
                child: sprite('tile_paw', size: 30),
              ),
            ),
            CatCharacter(player, height: 235),
          ],
        ),
      ),
    ),
  );
}

class _HouseTourCard extends StatelessWidget {
  const _HouseTourCard({required this.player, required this.onBattle});

  final Player player;
  final void Function(HouseCat cat) onBattle;

  @override
  Widget build(BuildContext context) {
    final room = houseRoomForTrophies(player.trophies);
    final roomIndex = houseRooms.indexOf(room);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: _cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6651312d),
            offset: Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Turul casei • ${room.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Camera ${roomIndex + 1}/${houseRooms.length}',
                style: const TextStyle(
                  color: Color(0xff8a5a3b),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            player.english
                ? 'Choose a labelled house-cat bot'
                : 'Alege o pisică-bot din casă',
            style: const TextStyle(
              color: Color(0xff8a5a3b),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final cat in room.cats)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _HouseCatButton(
                      player: player,
                      cat: cat,
                      onBattle: onBattle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HouseCatButton extends StatelessWidget {
  const _HouseCatButton({
    required this.player,
    required this.cat,
    required this.onBattle,
  });

  final Player player;
  final HouseCat cat;
  final void Function(HouseCat cat) onBattle;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x66ffffff),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: () => onBattle(cat),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ink, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CatAvatar(houseCatPlayer(player.prefs, cat), size: 42),
            const SizedBox(height: 4),
            Text(
              cat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Nv ${cat.level}',
              style: const TextStyle(
                color: Color(0xff8a5a3b),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'BOT',
              style: TextStyle(
                color: gold,
                fontSize: 9,
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

class _ReturnButton extends StatelessWidget {
  const _ReturnButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x553b2a24),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x55ffc63c), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: cream,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xffe8c9a0),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PowerPill extends StatelessWidget {
  const _PowerPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    constraints: const BoxConstraints(maxWidth: 380),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff7a4a32), Color(0xff5d3a2c)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: gold, width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0x5545312d), offset: Offset(0, 3)),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt, color: gold, size: 18),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: cream,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
