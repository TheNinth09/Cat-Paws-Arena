import 'package:flutter/material.dart';

import 'profile.dart';
import 'shell/friend_room.dart';
import 'ui_widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
    this.onBattle,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;
  final void Function(int mode)? onBattle;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool globalEvents = true;

  Player get player => widget.player;
  bool get english => player.english;

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('events-scroll'),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
    children: [
      SectionHeading('EVENIMINTE'),
      _toggle(),
      const SizedBox(height: 8),
      if (globalEvents) _globalBanner(context) else _privateEvents(context),
      const SizedBox(height: 10),
      Text(
        english
            ? 'Events and tournaments are parked. No live leaderboard, tournament or online event is connected.'
            : 'Evenimentele și turneele sunt parked. Niciun leaderboard, turneu sau eveniment online live nu este conectat.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xff6b4a32),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _toggle() => Row(
    children: [
      Expanded(
        child: ArenaButton(
          text: 'GLOBAL',
          green: globalEvents,
          secondary: !globalEvents,
          singleLine: true,
          onPressed: () {
            setState(() => globalEvents = true);
          },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ArenaButton(
          text: 'PRIVATE',
          green: !globalEvents,
          secondary: globalEvents,
          singleLine: true,
          onPressed: () {
            setState(() => globalEvents = false);
          },
        ),
      ),
    ],
  );

  Widget _globalBanner(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff9a6242), Color(0xff74463a)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: gold, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x6651312d),
          offset: Offset(0, 4),
          blurRadius: 6,
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            arenaImage(
              'cat_tzuki',
              width: 56,
              height: 56,
              fallback: sprite('tile_star', size: 46),
            ),
            arenaImage(
              'trophy_gold_fish',
              width: 52,
              height: 52,
              fallback: sprite('icon_trophy', size: 46),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english
                        ? 'GLOBAL WEEKEND TOURNAMENT'
                        : 'TURNEUL GLOBAL DE WEEKEND',
                    style: const TextStyle(
                      color: cream,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    english
                        ? 'parked: no live bracket, leaderboard or countdown.'
                        : 'parked: fără bracket live, clasament sau countdown.',
                    style: TextStyle(
                      color: cream.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            arenaImage(
              'cat_bubble',
              width: 56,
              height: 56,
              fallback: sprite('tile_fish', size: 46),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ArenaButton(
          text: english ? 'ENTER TOURNAMENT' : 'INTRĂ ÎN TURNEU',
          green: true,
          onPressed: () {
            widget.onUnavailable(
              english ? 'Global tournaments' : 'Turnee globale',
            );
          },
        ),
      ],
    ),
  );

  Widget _privateEvents(BuildContext context) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          english ? 'PRIVATE EVENTS' : 'EVENIMENTE PRIVATE',
          style: const TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          english
              ? 'Private events are parked/local. Joining by code opens the existing friend-room flow.'
              : 'Evenimentele private sunt parked/locale. Intrarea cu cod deschide fluxul existent de cameră de prieten.',
          style: const TextStyle(
            color: Color(0xff6b4a32),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _privateCard(context, create: true)),
            const SizedBox(width: 10),
            Expanded(child: _privateCard(context, create: false)),
          ],
        ),
      ],
    ),
  );

  Widget _privateCard(BuildContext context, {required bool create}) {
    final title = create
        ? (english ? 'CREATE EVENT' : 'CREEAZĂ EVENIMENT')
        : (english ? 'JOIN WITH CODE' : 'INTRĂ CU COD');
    final button = create
        ? (english ? 'CREATE' : 'CREEAZĂ')
        : (english ? 'JOIN' : 'INTRĂ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: create
              ? const [Color(0xffff8a65), Color(0xffffd54f)]
              : const [Color(0xff7e57c2), Color(0xff42a5f5)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ink, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            create ? Icons.vpn_key : Icons.confirmation_number,
            color: cream,
            size: 42,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: cream,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ArenaButton(
            text: button,
            singleLine: true,
            onPressed: () {
              if (create) {
                widget.onUnavailable(
                  english
                      ? 'Creating private events'
                      : 'Crearea evenimentelor private',
                );
              } else {
                showFriendRoom(context, english: english, player: player);
              }
            },
          ),
        ],
      ),
    );
  }
}
