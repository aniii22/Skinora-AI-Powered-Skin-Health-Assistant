import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../auth/session.dart' show Session;
import '../models/models.dart';
import '../l10n/l10n.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  bool get premiumRequired => status == 402;
  @override
  String toString() => message;
}

/// Typed client for the Skinora Go API.
/// Base URL: flutter run --dart-define=API_BASE_URL=https://your-api.example.com
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _http = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue:
                'https://skinora-ai-powered-skin-health-assistant.onrender.com',
          );

  final http.Client _http;
  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final req = http.Request(method, _uri(path, query));
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    return _finish(req);
  }

  Future<dynamic> _finish(
    http.BaseRequest req, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final token = Session.I.token;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (req is http.MultipartRequest &&
        req.url.path.endsWith('/ai/skin-analysis')) {
      req.fields['lang'] = Lang.I.code;
    }
    http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(req).timeout(timeout),
      );
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } catch (_) {
      throw ApiException(
        'Could not reach the server at $baseUrl. Make sure the backend is running, then try again.',
      );
    }

    dynamic decoded;
    if (res.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        decoded = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded is Map && decoded.containsKey('data')
          ? decoded['data']
          : decoded;
    }
    final String msg;
    if (decoded is Map && decoded['error'] is String) {
      msg = decoded['error'] as String;
    } else if (decoded is Map && decoded['message'] is String) {
      msg = decoded['message'] as String;
    } else {
      msg = 'Request failed (${res.statusCode}).';
    }
    if (res.statusCode == 401) Session.I.expire();
    throw ApiException(msg, res.statusCode);
  }

  /// Generic authenticated call (used by Session for login/register/premium).
  Future<dynamic> request(String method, String path, {Object? body}) =>
      _send(method, path, body: body);

  /// Headers for widgets that load protected files directly (e.g. Image.network).
  Map<String, String> get authHeaders {
    final t = Session.I.token;
    return t == null ? {} : {'Authorization': 'Bearer $t'};
  }

  Map<String, dynamic> _map(dynamic d) => d as Map<String, dynamic>;
  List<T> _list<T>(dynamic d, T Function(Map<String, dynamic>) f) =>
      (d as List).map((e) => f(e as Map<String, dynamic>)).toList();

  // ---- health ----
  Future<String> health() async {
    final m = _map(await _send('GET', '/api/health'));
    if (m['status'] != 'ok')
      throw ApiException('API returned an unexpected status');
    return m['message']?.toString() ?? 'Skinora API is running';
  }

  // ---- profile & settings ----
  Future<SkinProfile> getProfile() async =>
      SkinProfile.fromJson(_map(await _send('GET', '/api/profile')));
  Future<SkinProfile> saveProfile(SkinProfile p) async => SkinProfile.fromJson(
    _map(await _send('PUT', '/api/profile', body: p.toJson())),
  );

  Future<WaterSettings> getSettings() async =>
      WaterSettings.fromJson(_map(await _send('GET', '/api/settings')));
  Future<WaterSettings> saveSettings(int goalMl, int glassMl) async =>
      WaterSettings.fromJson(
        _map(
          await _send(
            'PUT',
            '/api/settings',
            body: {'water_goal_ml': goalMl, 'glass_ml': glassMl},
          ),
        ),
      );

  // ---- routine ----
  Future<List<RoutineItem>> listRoutine(String date) async => _list(
    await _send('GET', '/api/routine', query: {'date': date}),
    RoutineItem.fromJson,
  );

  Future<void> addRoutineItem(String period, String title) => _send(
    'POST',
    '/api/routine/items',
    body: {'period': period, 'title': title},
  );

  Future<void> updateRoutineItem(int id, String period, String title) => _send(
    'PUT',
    '/api/routine/items/$id',
    body: {'period': period, 'title': title},
  );

  Future<void> deleteRoutineItem(int id) =>
      _send('DELETE', '/api/routine/items/$id');

  Future<void> setCompletion(int id, String date, bool done) => _send(
    'PUT',
    '/api/routine/items/$id/completion',
    query: {'date': date},
    body: {'done': done},
  );

  Future<void> resetRoutineDay(String date) =>
      _send('DELETE', '/api/routine/completions', query: {'date': date});

  Future<List<RoutineDay>> routineHistory(int days, String date) async => _list(
    await _send(
      'GET',
      '/api/routine/history',
      query: {'days': '$days', 'date': date},
    ),
    RoutineDay.fromJson,
  );

  // ---- water ----
  Future<WaterSummary> waterSummary(String date) async => WaterSummary.fromJson(
    _map(await _send('GET', '/api/water', query: {'date': date})),
  );

  Future<void> addWater(String date, int ml) => _send(
    'POST',
    '/api/water',
    query: {'date': date},
    body: {'amount_ml': ml},
  );

  Future<void> removeLastWater(String date) =>
      _send('DELETE', '/api/water/last', query: {'date': date});

  Future<List<WaterDay>> waterHistory(int days, String date) async => _list(
    await _send(
      'GET',
      '/api/water/history',
      query: {'days': '$days', 'date': date},
    ),
    WaterDay.fromJson,
  );

  // ---- sleep ----
  Future<List<SleepLog>> listSleep() async =>
      _list(await _send('GET', '/api/sleep'), SleepLog.fromJson);

  Map<String, dynamic> _sleepBody(DateTime start, DateTime wake) => {
    'sleep_start': start.toUtc().toIso8601String(),
    'wake_time': wake.toUtc().toIso8601String(),
  };

  Future<void> addSleep(DateTime start, DateTime wake) =>
      _send('POST', '/api/sleep', body: _sleepBody(start, wake));
  Future<void> updateSleep(int id, DateTime start, DateTime wake) =>
      _send('PUT', '/api/sleep/$id', body: _sleepBody(start, wake));
  Future<void> deleteSleep(int id) => _send('DELETE', '/api/sleep/$id');

  // ---- journal ----
  Future<List<JournalEntry>> listJournal() async =>
      _list(await _send('GET', '/api/journal'), JournalEntry.fromJson);

  Future<JournalEntry> addJournal(
    String day,
    String notes,
    int? rating,
  ) async => JournalEntry.fromJson(
    _map(
      await _send(
        'POST',
        '/api/journal',
        body: {'day': day, 'notes': notes, 'rating': rating},
      ),
    ),
  );

  Future<JournalEntry> updateJournal(
    int id,
    String day,
    String notes,
    int? rating,
  ) async => JournalEntry.fromJson(
    _map(
      await _send(
        'PUT',
        '/api/journal/$id',
        body: {'day': day, 'notes': notes, 'rating': rating},
      ),
    ),
  );

  Future<void> deleteJournal(int id) => _send('DELETE', '/api/journal/$id');

  Future<void> uploadPhoto(int id, XFile file) async {
    final bytes = await file.readAsBytes();
    final req = http.MultipartRequest('POST', _uri('/api/journal/$id/photo'))
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: file.name.isEmpty ? 'photo.jpg' : file.name,
        ),
      );
    await _finish(req, timeout: const Duration(seconds: 60));
  }

  Future<void> deletePhoto(int id) => _send('DELETE', '/api/journal/$id/photo');

  String photoUrl(int id, int version) =>
      '$baseUrl/api/journal/$id/photo?v=$version';

  // ---- profile photo ----
  Future<Uint8List?> profilePhotoBytes() async {
    final req = http.Request('GET', _uri('/api/profile/photo'));
    final t = Session.I.token;
    if (t != null) req.headers['Authorization'] = 'Bearer $t';
    try {
      final res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 15)),
      );
      return res.statusCode == 200 ? res.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadProfilePhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    final req = http.MultipartRequest('POST', _uri('/api/profile/photo'))
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: file.name.isEmpty ? 'photo.jpg' : file.name,
        ),
      );
    await _finish(req, timeout: const Duration(seconds: 60));
  }

  Future<void> deleteProfilePhoto() => _send('DELETE', '/api/profile/photo');

  // ---- AI skin analysis ----
  Future<Map<String, dynamic>> analyzeSkin(
    List<XFile> files, {
    String? skinType,
    String? note,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/ai/skin-analysis'));
    for (final f in files) {
      final bytes = await f.readAsBytes();
      req.files.add(
        http.MultipartFile.fromBytes(
          'frames',
          bytes,
          filename: f.name.isEmpty ? 'skin.jpg' : f.name,
        ),
      );
    }
    if (skinType != null && skinType.isNotEmpty)
      req.fields['skin_type'] = skinType;
    if (note != null && note.trim().isNotEmpty)
      req.fields['note'] = note.trim();
    req.fields['lang'] = Lang.I.code;
    return _map(await _finish(req, timeout: const Duration(seconds: 120)));
  }

  Future<Map<String, dynamic>> analyzeSkinVideo(
    XFile video, {
    String? skinType,
    String? note,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/ai/skin-analysis'));
    final bytes = await video.readAsBytes();
    req.files.add(
      http.MultipartFile.fromBytes(
        'video',
        bytes,
        filename: video.name.isEmpty ? 'skin.mp4' : video.name,
      ),
    );
    if (skinType != null && skinType.isNotEmpty) {
      req.fields['skin_type'] = skinType;
    }
    if (note != null && note.trim().isNotEmpty) {
      req.fields['note'] = note.trim();
    }
    req.fields['lang'] = Lang.I.code;
    return _map(await _finish(req, timeout: const Duration(seconds: 150)));
  }

  // ---- insights & data ----
  Future<Insights> insights(int days, String date) async => Insights.fromJson(
    _map(
      await _send(
        'GET',
        '/api/insights',
        query: {'days': '$days', 'date': date},
      ),
    ),
  );

  /// Premium only. Returns the raw map from /api/insights/deep.
  Future<Map<String, dynamic>> deepInsights(int days, String date) async =>
      _map(
        await _send(
          'GET',
          '/api/insights/deep',
          query: {'days': '$days', 'date': date},
        ),
      );
  Future<void> clearAllData() =>
      _send('DELETE', '/api/data', query: {'confirm': 'delete-all'});
}
