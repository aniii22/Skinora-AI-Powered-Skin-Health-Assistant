import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api_client.dart';

/// Real phone notifications (Android). Reminders are read from the server
/// and scheduled on the phone, so they appear even when the app is closed.
class LocalNotifier {
  LocalNotifier._();
  static final LocalNotifier I = LocalNotifier._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _syncing = false;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'skinora_reminders',
      'Reminders',
      channelDescription: 'Water and skincare reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      final a = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await a?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('LocalNotifier init failed: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!supported) return;
    await init();
    if (_ready) await _plugin.cancelAll();
  }

  /// Shows one notification now, and one more in 1 minute.
  Future<void> testNow() async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    await _plugin.show(
      2000000000,
      'Skinora test',
      'Phone notifications are working.',
      _details,
    );
    await _plugin.zonedSchedule(
      2000000001,
      'Skinora scheduled test',
      'This one was scheduled 1 minute ago.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  int _min(String s) {
    if (s.length != 5) return 0;
    return (int.tryParse(s.substring(0, 2)) ?? 0) * 60 +
        (int.tryParse(s.substring(3, 5)) ?? 0);
  }

  bool _inQuiet(int t, String start, String end) {
    final s = _min(start), e = _min(end);
    if (s == e) return false;
    if (s < e) return t >= s && t < e;
    return t >= s || t < e;
  }

  tz.TZDateTime _next(int weekday, int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    while (d.weekday != weekday || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Reads reminders from the server and (re)schedules them on the phone.
  Future<void> syncFromServer(ApiClient api) async {
    if (!supported || _syncing) return;
    _syncing = true;
    try {
      await init();
      if (!_ready) return;
      final m = (await api.request('GET', '/api/reminders')) as Map<String, dynamic>;
      final prefs = (m['prefs'] as Map<String, dynamic>?) ?? {};
      var glass = 250;
      try {
        final s = (await api.request('GET', '/api/settings')) as Map<String, dynamic>;
        glass = (s['glass_ml'] as num?)?.toInt() ?? 250;
      } catch (_) {}

      for (final p in await _plugin.pendingNotificationRequests()) {
        if (p.id < 1000000) await _plugin.cancel(p.id);
      }
      if (prefs['all_enabled'] == false) return;
      final quietOn = prefs['quiet_enabled'] == true;
      final qs = (prefs['quiet_start'] as String?) ?? '22:00';
      final qe = (prefs['quiet_end'] as String?) ?? '07:00';

      for (final e in (m['items'] as List)) {
        final r = e as Map<String, dynamic>;
        if (r['enabled'] != true) continue;
        final id = (r['id'] as num).toInt();
        final kind = r['kind'] as String;
        final time = r['time'] as String;
        final days = (r['days'] as num).toInt();
        final minutes = _min(time);
        if (quietOn && _inQuiet(minutes, qs, qe)) continue;

        var title = ((r['title'] as String?) ?? '').isEmpty
            ? 'Reminder'
            : r['title'] as String;
        var body = 'Time for your reminder.';
        if (kind == 'water') {
          title = 'Time to drink water';
          body = 'Have a glass ($glass ml) to stay on track.';
        } else if (kind == 'morning') {
          title = 'Morning skincare routine';
          body = 'Time for your morning routine.';
        } else if (kind == 'evening') {
          title = 'Evening skincare routine';
          body = 'Time for your evening routine.';
        }

        for (var i = 0; i < 7; i++) {
          if ((days & (1 << i)) == 0) continue;
          await _plugin.zonedSchedule(
            id * 10 + (i + 1),
            title,
            body,
            _next(i + 1, minutes ~/ 60, minutes % 60),
            _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    } catch (e) {
      debugPrint('LocalNotifier sync failed: $e');
    } finally {
      _syncing = false;
    }
  }
}