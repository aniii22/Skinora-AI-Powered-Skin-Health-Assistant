import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/smart_reminders.dart';
import '../utils/format.dart';
import '../widgets/daily_thoughts.dart' show selectedRoutineDay;

typedef SaveOutcome = ({bool ok, String? message});

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  /// Rebuilds the caller whenever state changes.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// For callbacks: does not subscribe.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class AppState extends ChangeNotifier {
  AppState(this.api);
  final ApiClient api;

  // connection
  bool? apiConnected;
  String apiMessage = 'Checking API connection...';
  bool checkingApi = false;

  // loading
  bool loaded = false;
  bool loading = false;
  String? loadError;
  String _loadedDay = '';
  DateTime? _lastLoadedAt;
  int _gen = 0; // bumps on sign-out and sign-in, so late results of the old user are dropped

  // data
  SkinProfile profile = SkinProfile.empty;
  WaterSettings settings = WaterSettings.defaults;
  List<RoutineItem> routine = [];
  List<RoutineDay> routineHistory = [];
  WaterSummary? water;
  List<WaterDay> waterHistory = [];
  List<SleepLog> sleep = [];
  List<JournalEntry> journal = [];
  final Set<int> pendingRoutine = {};

  /// Set when the server answers "Premium required"; main.dart shows the upgrade dialog.
  String? premiumNotice;

  /// Clears all data (used on sign-out / before a new sign-in).
  void reset() {
    _gen++;
    loaded = false;
    loading = false;
    loadError = null;
    _loadedDay = '';
    _lastLoadedAt = null;
    profile = SkinProfile.empty;
    settings = WaterSettings.defaults;
    routine = [];
    routineHistory = [];
    water = null;
    waterHistory = [];
    sleep = [];
    journal = [];
    pendingRoutine.clear();
    notifyListeners();
  }

  DateTime get today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String get todayKey => dayKey(today);

  void init() {
    checkApi();
    loadAll();
  }

  Future<void> retryAll() async {
    await Future.wait([checkApi(), loadAll()]);
  }

  Future<void> checkApi() async {
    if (checkingApi) return;
    checkingApi = true;
    apiMessage = 'Checking API connection...';
    notifyListeners();
    try {
      apiMessage = await api.health();
      apiConnected = true;
    } on ApiException catch (e) {
      apiConnected = false;
      apiMessage = e.message;
    } catch (_) {
      apiConnected = false;
      apiMessage = 'Could not connect to backend';
    } finally {
      checkingApi = false;
      notifyListeners();
    }
  }

  Future<void> loadAll() async {
    if (loading) return;
    loading = true;
    final gen = _gen;
    loadError = null;
    notifyListeners();
    final day = todayKey;
    try {
      final res = await Future.wait<dynamic>([
        api.getProfile(),
        api.getSettings(),
        api.listRoutine(day),
        api.routineHistory(7, day),
        api.waterSummary(day),
        api.waterHistory(7, day),
        api.listSleep(),
        api.listJournal(),
      ], eagerError: true);
      final p = res[0];
      final st = res[1];
      final r = res[2];
      final rh = res[3];
      final w = res[4];
      final wh = res[5];
      final s = res[6];
      final j = res[7];
      if (gen != _gen) return;
      profile = p;
      settings = st;
      routine = r;
      routineHistory = rh;
      water = w;
      waterHistory = wh;
      sleep = s;
      journal = j;
      loaded = true;
      if (_loadedDay.isNotEmpty && _loadedDay != day) {
        selectedRoutineDay.value = today;
      }
      _loadedDay = day;
      _lastLoadedAt = DateTime.now();
      _syncSmartReminders();
    } on ApiException catch (e) {
      if (gen == _gen) loadError = e.message;
    } catch (_) {
      if (gen == _gen) loadError = 'Unexpected response from the server.';
    } finally {
      if (gen == _gen) loading = false;
      notifyListeners();
    }
  }

  /// Re-plans "you have not done this yet" phone reminders from today's data.
  void _syncSmartReminders() {
    if (!loaded) return;
    final t = today;
    bool isToday(DateTime d) =>
        d.year == t.year && d.month == t.month && d.day == t.day;
    SmartReminders.I.refresh(
      api,
      waterMl: water?.totalMl ?? 0,
      goalMl: water?.goalMl ?? settings.goalMl,
      routineDone: routine.where((e) => e.done).length,
      routineTotal: routine.length,
      sleepLogged: sleep.any((e) => isToday(e.wake)),
      journalLogged: journal.any((e) => isToday(e.day)),
    );
  }
  /// Called on app resume / every minute: moves to a fresh day automatically.
  void refreshIfNewDay() {
    if (loaded && _loadedDay != todayKey) loadAll();
  }

  /// Silent background refresh: after a failed load, when the connection was
  /// down, on a new day, or when the data is older than [maxAge].
  void refreshIfNeeded({Duration maxAge = const Duration(minutes: 2)}) {
    if (loading) return;
    if (!loaded) {
      loadAll();
      return;
    }
    if (apiConnected == false) checkApi();
    final last = _lastLoadedAt;
    if (_loadedDay != todayKey ||
        last == null ||
        DateTime.now().difference(last) > maxAge) {
      loadAll();
    }
  }

  /// Runs a mutation; returns an error message or null on success.
  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      _syncSmartReminders();
      return null;
    } on ApiException catch (e) {
      if (e.premiumRequired) premiumNotice = e.message;
      return e.message;
    } catch (_) {
      return 'Unexpected response from the server.';
    } finally {
      notifyListeners();
    }
  }

  // ---- profile ----
  Future<String?> saveProfile(SkinProfile p) => _run(() async {
    profile = await api.saveProfile(p);
  });

  // ---- routine ----
  Future<void> _reloadRoutine() async {
    final gen = _gen;
    final day = todayKey;
    final res = await Future.wait<dynamic>([
      api.listRoutine(day),
      api.routineHistory(7, day),
    ], eagerError: true);
    if (gen != _gen) return;
    routine = res[0];
    routineHistory = res[1];
  }

  Future<String?> addRoutineItem(String period, String title) => _run(() async {
    await api.addRoutineItem(period, title);
    await _reloadRoutine();
  });

  Future<String?> editRoutineItem(RoutineItem item, String title) =>
      _run(() async {
        await api.updateRoutineItem(item.id, item.period, title);
        await _reloadRoutine();
      });

  Future<String?> deleteRoutineItem(RoutineItem item) => _run(() async {
    await api.deleteRoutineItem(item.id);
    await _reloadRoutine();
  });

  Future<String?> setRoutineDone(RoutineItem item, bool done) async {
    if (!pendingRoutine.add(item.id)) return null;
    notifyListeners();
    final err = await _run(() async {
      await api.setCompletion(item.id, todayKey, done);
      await _reloadRoutine();
    });
    pendingRoutine.remove(item.id);
    notifyListeners();
    return err;
  }

  Future<String?> resetRoutineDay() => _run(() async {
    await api.resetRoutineDay(todayKey);
    await _reloadRoutine();
  });

  // ---- water ----
  Future<void> _reloadWater() async {
    final gen = _gen;
    final day = todayKey;
    final res = await Future.wait<dynamic>([
      api.waterSummary(day),
      api.waterHistory(7, day),
    ], eagerError: true);
    if (gen != _gen) return;
    water = res[0];
    waterHistory = res[1];
  }

  Future<String?> addWater(int ml) async {
    if ((water?.totalMl ?? 0) + ml > 5000) {
      notifyListeners();
      return 'Daily limit reached (5000 ml)';
    }
    return _run(() async {
      await api.addWater(todayKey, ml);
      await _reloadWater();
    });
  }

  Future<String?> removeLastWater() => _run(() async {
    await api.removeLastWater(todayKey);
    await _reloadWater();
  });

  Future<String?> saveSettings(int goalMl, int glassMl) => _run(() async {
    settings = await api.saveSettings(goalMl, glassMl);
    await _reloadWater();
  });

  // ---- sleep ----
  Future<String?> saveSleep({
    int? id,
    required DateTime start,
    required DateTime wake,
  }) => _run(() async {
    if (id == null) {
      await api.addSleep(start, wake);
    } else {
      await api.updateSleep(id, start, wake);
    }
    sleep = await api.listSleep();
  });

  Future<String?> deleteSleep(int id) => _run(() async {
    await api.deleteSleep(id);
    sleep = await api.listSleep();
  });

  // ---- journal ----
  Future<SaveOutcome> saveJournal({
    int? id,
    required DateTime day,
    required String notes,
    int? rating,
    XFile? newPhoto,
    bool removePhoto = false,
  }) async {
    String? warning;
    final err = await _run(() async {
      final entry = id == null
          ? await api.addJournal(dayKey(day), notes, rating)
          : await api.updateJournal(id, dayKey(day), notes, rating);
      try {
        if (newPhoto != null) {
          await api.uploadPhoto(entry.id, newPhoto);
        } else if (removePhoto) {
          await api.deletePhoto(entry.id);
        }
      } on ApiException catch (e) {
        if (e.premiumRequired) premiumNotice = e.message;
        warning = 'Entry saved, but the photo change failed: ${e.message}';
      }
      journal = await api.listJournal();
    });
    if (err != null) return (ok: false, message: err);
    return (ok: true, message: warning);
  }

  Future<String?> deleteJournal(int id) => _run(() async {
    await api.deleteJournal(id);
    journal = await api.listJournal();
  });

  // ---- insights & data ----
  Future<Insights> loadInsights(int days) => api.insights(days, todayKey);

  Future<String?> clearAll() => _run(() async {
    await api.clearAllData();
    loaded = false;
    loading = false;
    await loadAll();
  });
}
