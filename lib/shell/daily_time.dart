String utcDayKey(DateTime time) {
  final u = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}';
}

DateTime utcDay(DateTime time) {
  final u = time.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

String addUtcDays(String dayKey, int days) {
  final parsed = DateTime.parse('${dayKey}T00:00:00.000Z');
  return utcDayKey(DateTime.utc(parsed.year, parsed.month, parsed.day + days));
}
