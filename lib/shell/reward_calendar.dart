import 'package:flutter/material.dart';

import '../app_dialogs.dart';
import '../profile.dart';
import '../ui_widgets.dart';
import 'daily_time.dart';

class RewardCalendar {
  RewardCalendar(this.player);

  static const rewards = [100, 150, 200, 300, 400, 600, 1000];
  // Calendar state is namespaced above trophy claim IDs so `Player.save`
  // persists the claim and the coin reward in the same write.
  static const _lastDayBase = 1000000;
  static const _streakBase = 2000000;

  final Player player;

  int _epochDay(DateTime time) =>
      utcDay(time).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  ({int lastEpochDay, int streak}) _read() {
    var lastEpochDay = -1, streak = 0;
    for (final claim in player.claims) {
      if (claim >= _streakBase) {
        streak = claim - _streakBase;
      } else if (claim >= _lastDayBase) {
        lastEpochDay = claim - _lastDayBase;
      }
    }
    return (lastEpochDay: lastEpochDay, streak: streak);
  }

  ({int day, bool claimed}) stateFor(DateTime now) {
    final today = _epochDay(now);
    final data = _read();
    if (data.lastEpochDay == today) {
      return (day: data.streak.clamp(1, rewards.length), claimed: true);
    }
    if (data.lastEpochDay == today - 1) {
      return (day: data.streak % rewards.length + 1, claimed: false);
    }
    return (day: 1, claimed: false);
  }

  int? claim(DateTime now) {
    final state = stateFor(now);
    if (state.claimed) return null;
    final today = _epochDay(now);
    player.claims.removeWhere((claim) => claim >= _lastDayBase);
    player.claims.add(_lastDayBase + today);
    player.claims.add(_streakBase + state.day);
    return rewards[state.day - 1];
  }
}

Future<void> showRewardCalendar(BuildContext context, Player player) =>
    showAppDialog(
      context,
      'Calendarul de recompense',
      RewardCalendarPanel(player: player),
    );

class RewardCalendarPanel extends StatefulWidget {
  const RewardCalendarPanel({super.key, required this.player});

  final Player player;

  @override
  State<RewardCalendarPanel> createState() => _RewardCalendarPanelState();
}

class _RewardCalendarPanelState extends State<RewardCalendarPanel> {
  late final calendar = RewardCalendar(widget.player);
  late ({int day, bool claimed}) state = calendar.stateFor(DateTime.now());

  Future<void> claim() async {
    final amount = calendar.claim(DateTime.now());
    if (amount != null) {
      widget.player.coins += amount;
      await widget.player.save();
    }
    if (!mounted) return;
    setState(() => state = calendar.stateFor(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < RewardCalendar.rewards.length; i++)
            _DayCell(
              day: i + 1,
              amount: RewardCalendar.rewards[i],
              status: state.claimed && state.day == i + 1
                  ? _DayStatus.claimed
                  : i + 1 == state.day
                  ? _DayStatus.next
                  : _DayStatus.future,
            ),
        ],
      ),
      const SizedBox(height: 12),
      ArenaButton(
        text: state.claimed
            ? 'REVENDICAT AZI'
            : 'REVENDICĂ +${RewardCalendar.rewards[state.day - 1]} LĂBUȚE',
        green: !state.claimed,
        onPressed: state.claimed ? null : () => claim(),
      ),
      const SizedBox(height: 6),
      const Text(
        'Recompensele cresc 7 zile; o zi ratată reface seria de la prima zi.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xff8a6a52), fontSize: 12),
      ),
    ],
  );
}

enum _DayStatus { claimed, next, future }

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.amount,
    required this.status,
  });

  final int day, amount;
  final _DayStatus status;

  @override
  Widget build(BuildContext context) => Container(
    width: 82,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: status == _DayStatus.next
          ? const Color(0xffffe9bd)
          : const Color(0xfffffbec),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: status == _DayStatus.claimed
            ? const Color(0xffb9e07a)
            : status == _DayStatus.next
            ? gold
            : const Color(0xffd9b98c),
        width: status == _DayStatus.future ? 1 : 1.6,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ziua $day',
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '+$amount',
          style: const TextStyle(
            color: Color(0xff8a5a3b),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          switch (status) {
            _DayStatus.claimed => 'DEJA',
            _DayStatus.next => 'ASTĂZI',
            _DayStatus.future => '———',
          },
          style: TextStyle(
            color: status == _DayStatus.future ? const Color(0xffa98d74) : ink,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
