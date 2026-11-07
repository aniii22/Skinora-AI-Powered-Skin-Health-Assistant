import '../l10n/l10n.dart';
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
List<String> weekdayNames() {
  switch (Lang.I.code) {
    case 'hi':
      return ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    case 'mr':
      return ['सोम', 'मंगळ', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    default:
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }
}

List<String> get _weekdays => weekdayNames();

/// yyyy-MM-dd in local time (what the API expects).
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDay(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String shortDay(DateTime d) => _weekdays[d.weekday - 1];
String prettyDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
String prettyDateYear(DateTime d) => '${prettyDate(d)} ${d.year}';
String dayLabel(DateTime d) => '${shortDay(d)} ${d.day}';

String formatMinutes(int m) {
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '${r}m';
  if (r == 0) return '${h}h';
  return '${h}h ${r}m';
}

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String glassesText(int ml, int glassMl) {
  if (glassMl <= 0) return '0';
  final v = ml / glassMl;
  return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}
