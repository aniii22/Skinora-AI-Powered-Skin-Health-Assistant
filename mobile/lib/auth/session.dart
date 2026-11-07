import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

class AppUser {
  AppUser(this.name, this.email, this.isPremium, this.premiumUntil);
  final String name, email;
  final bool isPremium;
  final DateTime? premiumUntil;
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    j['name'] as String,
    j['email'] as String,
    j['is_premium'] == true,
    j['premium_until'] == null
        ? null
        : DateTime.tryParse(j['premium_until'] as String)?.toLocal(),
  );
}

/// Login state. ApiClient reads [token] for every request.
class Session extends ChangeNotifier {
  Session._();
  static final Session I = Session._();

  static const _tokenKey = 'skinora_session_token';
  final FlutterSecureStorage _vault = const FlutterSecureStorage();
  final ApiClient _api = ApiClient();

  String? token;
  AppUser? user;

  /// False while the saved session is being checked with the server.
  bool ready = false;

  /// True when a saved token exists but the server could not be reached.
  /// The token is kept, so the user is NOT logged out by a network problem.
  bool restoreFailed = false;

  bool get signedIn => token != null && user != null;

  Map<String, dynamic> _m(dynamic d) => d as Map<String, dynamic>;

  Future<String?> _readToken() async {
    try {
      final t = await _vault.read(key: _tokenKey);
      return (t == null || t.isEmpty) ? null : t;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeToken(String t) async {
    try {
      await _vault.write(key: _tokenKey, value: t);
    } catch (_) {}
  }

  Future<void> _deleteToken() async {
    try {
      await _vault.delete(key: _tokenKey);
    } catch (_) {}
  }

  /// Called once from main(). Returns quickly; the server check runs in the
  /// background while AuthGate shows a spinner.
  Future<void> init() async {
    // Remove the old plain-text token left by earlier app versions.
    try {
      await (await SharedPreferences.getInstance()).remove('token');
    } catch (_) {}

    token = await _readToken();
    if (token == null) {
      ready = true;
      notifyListeners();
      return;
    }
    unawaited(_restoreAndFinish());
  }

  Future<void> _restoreAndFinish() async {
    await _restore();
    ready = true;
    notifyListeners();
  }

  Future<void> _restore() async {
    restoreFailed = false;
    try {
      user = AppUser.fromJson(_m(await _api.request('GET', '/api/auth/me')));
    } on ApiException catch (e) {
      if (e.status == 401) {
        await _clear(); // session really expired or was revoked
      } else {
        restoreFailed = true; // network or server problem: keep the token
      }
    } catch (_) {
      restoreFailed = true;
    }
  }

  /// "Try again" on the reconnect screen.
  Future<void> retryRestore() async {
    if (token == null) return;
    ready = false;
    notifyListeners();
    await _restoreAndFinish();
  }

  /// Forget the saved login without contacting the server.
  Future<void> discardSession() => _clear();

  Future<void> _save(Map<String, dynamic> d) async {
    token = d['token'] as String;
    user = AppUser.fromJson(_m(d['user']));
    restoreFailed = false;
    await _writeToken(token!);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async =>
      _save(
        _m(
          await _api.request(
            'POST',
            '/api/auth/register',
            body: {'name': name, 'email': email, 'password': password},
          ),
        ),
      );

  Future<void> login(String email, String password) async => _save(
    _m(
      await _api.request(
        'POST',
        '/api/auth/login',
        body: {'email': email, 'password': password},
      ),
    ),
  );

  Future<void> logout() async {
    try {
      await _api.request('POST', '/api/auth/logout');
    } catch (_) {}
    await _clear();
  }

  Future<void> deleteAccount(String password) async {
    await _api.request(
      'DELETE',
      '/api/auth/account',
      body: {'password': password},
    );
    await _clear();
  }

  Future<void> activatePremium(String plan) async {
    user = AppUser.fromJson(
      _m(
        await _api.request(
          'POST',
          '/api/premium/activate',
          body: {'plan': plan},
        ),
      ),
    );
    notifyListeners();
  }

  Future<void> cancelPremium() async {
    user = AppUser.fromJson(
      _m(await _api.request('POST', '/api/premium/cancel')),
    );
    notifyListeners();
  }

  /// Change name or email. Changing the email needs the current password.
  Future<void> updateProfile({
    required String name,
    required String email,
    String? currentPassword,
  }) async {
    final body = <String, dynamic>{'name': name, 'email': email};
    if (currentPassword != null && currentPassword.isNotEmpty) {
      body['current_password'] = currentPassword;
    }
    user = AppUser.fromJson(
      _m(await _api.request('PUT', '/api/auth/me', body: body)),
    );
    notifyListeners();
  }

  void setUser(Map<String, dynamic> j) {
    user = AppUser.fromJson(j);
    notifyListeners();
  }

  /// Called by ApiClient when the server answers 401 for a signed-in user.
  void expire() {
    if (token != null) _clear();
  }

  Future<void> _clear() async {
    token = null;
    user = null;
    restoreFailed = false;
    notifyListeners();
    await _deleteToken();
  }
}
