import 'package:flutter/material.dart';

import '../ui_widgets.dart';

class ParkedSurface extends StatelessWidget {
  const ParkedSurface({
    super.key,
    required this.title,
    required this.icon,
    required this.english,
    required this.points,
    required this.note,
  });

  final String title;
  final IconData icon;
  final bool english;
  final List<String> points;
  final String note;

  @override
  Widget build(BuildContext context) => ListView(
    key: PageStorageKey('parked-$title'),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
    children: [
      panel(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xfffff3cf), Color(0xfff0cf96)],
                    ),
                    border: Border.all(color: gold, width: 1.5),
                  ),
                  child: Icon(icon, color: ink, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        english ? 'Coming soon' : 'În curând',
                        style: const TextStyle(
                          color: Color(0xff8a6242),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline, color: gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              note,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff8a6242),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
