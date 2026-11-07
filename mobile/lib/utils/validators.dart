import 'package:flutter/services.dart';

class Validators {
  // ---- LIMITS ----
  static const int goalMin = 500, goalMax = 5000;
  static const int glassMin = 50, glassMax = 1000;
  static const int emailMax = 254, passMin = 8, passMax = 64;

  // ---- PATTERNS ----
  static final RegExp _email = RegExp(
      r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$");
  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[^A-Za-z0-9\s]');

  // ---- INPUT FORMATTERS (limits typing) ----
  static final List<TextInputFormatter> waterInput = [
    FilteringTextInputFormatter.digitsOnly,
    FilteringTextInputFormatter.deny(RegExp(r'^0')),
    LengthLimitingTextInputFormatter(4),
  ];
  static final List<TextInputFormatter> emailInput = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(emailMax),
  ];
  static final List<TextInputFormatter> passwordInput = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(passMax),
  ];

  // ---- EMAIL ----
  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required.';
    if (s.contains('..') || !_email.hasMatch(s) || s.length > emailMax) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  // ---- PASSWORD ----
  static Map<String, bool> passwordRules(String p) => {
        'At least $passMin characters': p.length >= passMin,
        'One uppercase letter (A-Z)': _upper.hasMatch(p),
        'One lowercase letter (a-z)': _lower.hasMatch(p),
        'One number (0-9)': _digit.hasMatch(p),
        'One special character (!@#\$%...)': _special.hasMatch(p),
      };

  static String? password(String? v) {
    final p = v ?? '';
    if (p.isEmpty) return 'Password is required.';
    if (p.length > passMax) return 'Password is too long.';
    if (p.contains(RegExp(r'\s'))) return 'Password cannot contain spaces.';
    if (passwordRules(p).values.any((ok) => !ok)) {
      return 'Password does not meet all requirements.';
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if ((v ?? '').isEmpty) return 'Please confirm your password.';
    if (v != original) return 'Passwords do not match.';
    return null;
  }

  // ---- WATER ----
  static String? goal(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'This field is required.';
    final n = int.tryParse(s);
    if (n == null || n < goalMin || n > goalMax) {
      return 'Enter a value between $goalMin and $goalMax ml.';
    }
    return null;
  }

  static String? glass(String? v, String? goalText) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'This field is required.';
    final n = int.tryParse(s);
    if (n == null || n < glassMin || n > glassMax) {
      return 'Enter a value between $glassMin and $glassMax ml.';
    }
    final g = int.tryParse((goalText ?? '').trim());
    if (g != null && n > g) {
      return 'One glass amount cannot exceed your daily goal.';
    }
    return null;
  }
}
