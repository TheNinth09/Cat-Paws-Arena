import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_dialogs.dart';
import '../profile.dart';
import '../ui_widgets.dart';
import 'daily_time.dart';

class DailyBoardStore {
  DailyBoardStore(this.prefs);

  static const _key = 'daily_board_v1';

  final SharedPreferences prefs;

  static int seedFor(DateTime time) =>
      utcDay(time).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  static List<int> targetsForSeed(int seed, {int length = 10}) {
    final random = Random(seed);
    return [for (var i = 0; i < length; i++) random.nextInt(3)];
  }

  Map<String, int> _read() {
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      return {
        for (final entry in (jsonDecode(raw) as Map).entries)
          entry.key as String: (entry.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  int bestScore(DateTime now) => _read()[utcDayKey(now)] ?? 0;

  Future<int> recordScore(int score, DateTime now) async {
    final day = utcDayKey(now);
    final scores = _read();
    final best = score > (scores[day] ?? 0) ? score : scores[day] ?? 0;
    scores[day] = best;
    await prefs.setString(_key, jsonEncode(scores));
    return best;
  }
}

Future<void> showDailyBoard(BuildContext context, Player player) =>
    showAppDialog(context, 'Tabla zilei', DailyBoardPanel(player: player));

class DailyBoardPanel extends StatefulWidget {
  const DailyBoardPanel({super.key, required this.player});

  final Player player;

  @override
  State<DailyBoardPanel> createState() => _DailyBoardPanelState();
}

class _DailyBoardPanelState extends State<DailyBoardPanel> {
  static const zoneNames = ['STÂNGA', 'CENTRU', 'DREAPTA'];
  static const zoneColors = [
    Color(0xffe8a01f),
    Color(0xffb9e07a),
    Color(0xff7fb3d5),
  ];

  late final store = DailyBoardStore(widget.player.prefs);
  late final seed = DailyBoardStore.seedFor(DateTime.now());
  late final targets = DailyBoardStore.targetsForSeed(seed);
  late int best = store.bestScore(DateTime.now());

  int index = 0, score = 0, misses = 0;
  bool finished = false;

  Future<void> tap(int zone) async {
    if (finished) return;
    if (zone == targets[index]) {
      score++;
    } else {
      misses++;
    }
    index++;
    if (index >= targets.length) {
      finished = true;
      best = await store.recordScore(score, DateTime.now());
    }
    if (mounted) setState(() {});
  }

  void restart() => setState(() {
    index = 0;
    score = 0;
    misses = 0;
    finished = false;
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Sămânța zilei: $seed',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xff8a6a52),
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Cel mai bun scor: $best/${targets.length}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      if (!finished) ...[
        Text(
          'Apasă: ${zoneNames[targets[index]]}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var zone = 0; zone < zoneNames.length; zone++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _ZoneButton(
                    label: zoneNames[zone],
                    color: zoneColors[zone],
                    onTap: () => tap(zone),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Runda ${index + 1}/${targets.length} • Greșeli: $misses',
            style: const TextStyle(color: Color(0xff8a6a52), fontSize: 12),
          ),
        ),
      ] else ...[
        Text(
          'GATA! Scor: $score/${targets.length} • Greșeli: $misses',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ArenaButton(text: 'JOACĂ DIN NOU', green: true, onPressed: restart),
      ],
    ],
  );
}

class _ZoneButton extends StatelessWidget {
  const _ZoneButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ink, width: 2),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
      ),
    ),
  );
}
