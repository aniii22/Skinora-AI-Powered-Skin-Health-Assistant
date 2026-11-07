import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'api_client.dart';
import 'local_notifier.dart';

/// Smart "you haven't done this yet" reminders for today.
/// Call [refresh] after the app loads and after every water/routine/sleep/journal change.
class SmartReminders {
  SmartReminders._();
  static final SmartReminders I = SmartReminders._();

  static const _base = 1000000; // ids _base.._base+999 belong to this class
  bool _busy = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'skinora_smart',
      'Smart reminders',
      channelDescription: 'Reminders for tasks you have not finished today',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

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

  Future<void> refresh(
    ApiClient api, {
    required int waterMl,
    required int goalMl,
    required int routineDone,
    required int routineTotal,
    required bool sleepLogged,
    required bool journalLogged,
  }) async {
    if (!LocalNotifier.I.supported || _busy) return;
    _busy = true;
    try {
      await LocalNotifier.I.init();
      final plugin = FlutterLocalNotificationsPlugin();

      final pending = await plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _base && p.id < _base + 1000) await plugin.cancel(p.id);
      }

      var allEnabled = true, quietOn = false;
      var qs = '22:00', qe = '07:00';
      try {
        final m = (await api.request('GET', '/api/reminders')) as Map<String, dynamic>;
        final prefs = (m['prefs'] as Map<String, dynamic>?) ?? {};
        allEnabled = prefs['all_enabled'] != false;
        quietOn = prefs['quiet_enabled'] == true;
        qs = (prefs['quiet_start'] as String?) ?? qs;
        qe = (prefs['quiet_end'] as String?) ?? qe;
      } catch (_) {}
      if (!allEnabled) return;

      final now = tz.TZDateTime.now(tz.local);
      bool ok(tz.TZDateTime t) =>
          t.isAfter(now) &&
          t.day == now.day &&
          !(quietOn && _inQuiet(t.hour * 60 + t.minute, qs, qe));
      tz.TZDateTime at(int h, int m) =>
          tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);

      Future<void> put(int id, tz.TZDateTime t, String title, String body) async {
        if (!ok(t)) return;
        await plugin.zonedSchedule(
          _base + id,
          title,
          body,
          t,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      // Water: every 2 hours from now until the goal is met.
      if (goalMl > 0 && waterMl < goalMl) {
        final left = goalMl - waterMl;
        for (var i = 1; i <= 6; i++) {
          await put(
            i,
            now.add(Duration(hours: 2 * i)),
            'Time to drink water',
            'You have had $waterMl of $goalMl ml today. $left ml to go.',
          );
        }
      }

      // Routine: unfinished steps.
      if (routineTotal > 0 && routineDone < routineTotal) {
        final left = routineTotal - routineDone;
        final body = '$left routine step${left == 1 ? '' : 's'} still pending today.';
        await put(10, at(11, 0), 'Skincare routine', body);
        await put(11, at(15, 0), 'Skincare routine', body);
        await put(12, at(20, 0), 'Do not skip your routine', body);
      }

      // Sleep.
      if (!sleepLogged) {
        await put(20, at(10, 0), 'Log your sleep', 'Add last night\'s sleep to keep your insights accurate.');
      }
      await put(21, at(21, 30), 'Wind down for bed', 'Good sleep helps your skin. Start winding down.');

      // Journal.
      if (!journalLogged) {
        await put(30, at(20, 30), 'Skin journal', 'How does your skin feel today? Add a quick note or mood.');
      }
    } catch (e) {
      debugPrint('SmartReminders failed: $e');
    } finally {
      _busy = false;
    }
  }
}
