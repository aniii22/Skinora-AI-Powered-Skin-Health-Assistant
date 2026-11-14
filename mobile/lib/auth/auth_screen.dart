import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

import '../services/api_client.dart' show ApiException;
import '../theme/app_theme.dart';
import 'session.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false, _busy = false, _hide = true;
  String? _error;

  static final _emailRx = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );

  String? _emailErr(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required.';
    if (s.length > 254 || s.contains('..') || !_emailRx.hasMatch(s)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Map<String, bool> _passRules(String p) => {
    'At least 8 characters': p.length >= 8,
    'One uppercase letter': RegExp(r'[A-Z]').hasMatch(p),
    'One lowercase letter': RegExp(r'[a-z]').hasMatch(p),
    'One number': RegExp(r'[0-9]').hasMatch(p),
    'One special character': RegExp(r'[^A-Za-z0-9\s]').hasMatch(p),
  };

  String? _passErr(String? v) {
    final p = v ?? '';
    if (p.isEmpty) return 'Password is required.';
    if (p.length > 72) return 'Password must be 72 characters or fewer.';
    if (!_register && p.isNotEmpty) return null;
    if (_passRules(p).containsValue(false)) {
      return 'Password does not meet all requirements.';
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      if (_register) {
        await Session.I.register(_name.text.trim(), email, _pass.text);
      } else {
        await Session.I.login(email, _pass.text);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _orb(
    IconData icon, {
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) => Positioned(
    left: left,
    right: right,
    top: top,
    bottom: bottom,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .12),
        border: Border.all(color: Colors.white.withValues(alpha: .25)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );

  Widget _hero() => SizedBox(
    height: 190,
    width: 280,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.gold.withValues(alpha: .35),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .10),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: const Icon(Icons.spa_rounded, color: AppColors.gold, size: 52),
        ),
        _orb(Icons.water_drop_rounded, left: 14, top: 22),
        _orb(Icons.wb_sunny_rounded, right: 10, top: 10),
        _orb(Icons.nightlight_round, left: 0, bottom: 28),
        _orb(Icons.auto_awesome, right: 18, bottom: 20),
      ],
    ),
  );

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.gold.withValues(alpha: .6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.gold),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _glow(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.gold.withValues(alpha: .08),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.deep, AppColors.primary],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: IgnorePointer(child: _glow(260)),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: IgnorePointer(child: _glow(300)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _hero(),
                        const SizedBox(height: 6),
                        const Text(
                          'Skinora',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Glow, one ritual\nat a time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Track your routine, hydration and sleep, and watch your skin story unfold.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .88),
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .25),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _register
                                    ? 'Create your account'
                                    : 'Welcome back',
                                style: AppText.sectionTitle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _register
                                    ? 'Start tracking your skin care today.'
                                    : 'Sign in to continue.',
                                style: AppText.bodyMuted,
                              ),
                              const SizedBox(height: 18),
                              if (_register) ...[
                                TextFormField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: Lang.I.tr('Name'),
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Enter your name'
                                      : v.trim().length > 40
                                      ? 'Max 40 characters'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(254)],
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  labelText: Lang.I.tr('Email'),
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                validator: _emailErr,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pass,
                                obscureText: _hide,
                                inputFormatters: _register ? [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(72)] : [LengthLimitingTextInputFormatter(72)],
                                onChanged: (_) => setState(() {}),
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                onFieldSubmitted: (_) => _submit(),
                                autofillHints: [
                                  _register
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                decoration: InputDecoration(
                                  labelText: Lang.I.tr('Password'),
                                  helperText: _register
                                      ? 'At least 8 characters'
                                      : null,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _hide
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      _hide
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () =>
                                        setState(() => _hide = !_hide),
                                  ),
                                ),
                                validator: _passErr,
                              ),
                              if (_register) ...[
                                const SizedBox(height: 10),
                                for (final r in _passRules(_pass.text).entries)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      children: [
                                        Icon(
                                          r.value
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          size: 16,
                                          color: r.value
                                              ? const Color(0xFF2E7D32)
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            r.key,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: r.value
                                                  ? const Color(0xFF2E7D32)
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _register
                                              ? 'Create account'
                                              : 'Sign in',
                                        ),
                                ),
                              ),
                              Center(
                                child: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _register = !_register;
      _pass.clear();
                                          _error = null;
                                        }),
                                  child: Text(
                                    _register
                                        ? 'Already have an account? Sign in'
                                        : 'New here? Create an account',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _chip(Icons.checklist_rounded, 'Daily routine'),
                            _chip(Icons.water_drop_outlined, 'Hydration'),
                            _chip(Icons.insights_rounded, 'Skin insights'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
