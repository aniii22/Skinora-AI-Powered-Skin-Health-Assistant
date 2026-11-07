import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/session.dart';
import '../services/api_client.dart' show ApiException;
import '../theme/app_theme.dart';
import '../widgets/common.dart' show showSnack;
import '../widgets/profile_avatar.dart';

/// Opens the edit panel (name, email, photo) as a bottom sheet.
Future<void> showEditAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 560),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _EditAccountSheet(),
  );
}

class _EditAccountSheet extends StatefulWidget {
  const _EditAccountSheet();

  @override
  State<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends State<_EditAccountSheet> {
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static const _fix = {
    'gmal.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gnail.com': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'hotmial.com': 'hotmail.com',
    'outlok.com': 'outlook.com',
  };

  final _formKey = GlobalKey<FormState>();
  final _pass = TextEditingController();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final String _origName;
  late final String _origEmail;
  bool _busy = false;
  bool _showPass = false;
  String? _error;

  bool get _emailChanged =>
      _email.text.trim().toLowerCase() != _origEmail.toLowerCase();
  bool get _changed => _name.text.trim() != _origName || _emailChanged;

  String? get _suggestion {
    final t = _email.text.trim().toLowerCase();
    final at = t.lastIndexOf('@');
    if (at < 1) return null;
    final fixed = _fix[t.substring(at + 1)];
    return fixed == null ? null : '${t.substring(0, at)}@$fixed';
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final u = Session.I.user;
    _origName = u?.name ?? '';
    _origEmail = u?.email ?? '';
    _name = TextEditingController(text: _origName)..addListener(_rebuild);
    _email = TextEditingController(text: _origEmail)..addListener(_rebuild);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String? _vName(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Enter your name.';
    if (t.length < 2) return 'Name must be at least 2 characters.';
    if (t.length > 40) return 'Name must be 40 characters or fewer.';
    return null;
  }

  String? _vEmail(String? v) {
    final t = (v ?? '').trim().toLowerCase();
    if (t.isEmpty) return 'Enter your email address.';
    if (t.length > 254 || !_emailRe.hasMatch(t)) {
      return 'Enter a valid email address.';
    }
    if (_emailChanged && _suggestion != null) {
      return 'This looks like a typo. Tap the suggestion below.';
    }
    return null;
  }

  String? _vPass(String? v) {
    if (!_emailChanged) return null;
    if ((v ?? '').isEmpty) return 'Enter your current password.';
    return null;
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.I.updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim().toLowerCase(),
        currentPassword: _emailChanged ? _pass.text : null,
      );
      if (!mounted) return;
      showSnack(context, 'Profile updated.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save. Please try again.';
        });
      }
    }
  }

  Widget _banner() {
    final name = _name.text.trim().isEmpty ? 'Your name' : _name.text.trim();
    final email = _email.text.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deep, AppColors.primary, Color(0xFF7BB661)],
        ),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            size: 72,
            name: name,
            onTap: () => showPhotoSheet(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .88),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the photo to change it',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _tick(bool ok) => ok
      ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
      : const SizedBox.shrink();

  Widget _suggestionChip() {
    final s = _suggestion;
    if (s == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _email.text = s;
          _email.selection = TextSelection.collapsed(offset: s.length);
        }),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_fix_high_rounded,
                size: 18,
                color: AppColors.deep,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Did you mean $s? Tap to fix',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _banner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: _vName,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        suffixIcon: _tick(_vName(_name.text) == null),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(254),
                      ],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: _vEmail,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        suffixIcon: _tick(
                          _vEmail(_email.text) == null &&
                              _suggestion == null,
                        ),
                      ),
                    ),
                    _suggestionChip(),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: _emailChanged
                          ? Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: TextFormField(
                                controller: _pass,
                                obscureText: !_showPass,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: _vPass,
                                decoration: InputDecoration(
                                  labelText: 'Current password',
                                  helperText:
                                      'Needed to confirm it is you when changing email.',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _showPass
                                        ? 'Hide password'
                                        : 'Show password',
                                    icon: Icon(
                                      _showPass
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () =>
                                        setState(() => _showPass = !_showPass),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _busy ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: (_busy || !_changed) ? null : _save,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}