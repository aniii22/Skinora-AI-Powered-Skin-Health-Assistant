import 'reminders_screen.dart';
import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../widgets/account_section.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _goal;
  late final TextEditingController _glass;
  bool _busy = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final st = AppScope.read(context).settings;
    _goal = TextEditingController(text: '${st.goalMl}');
    _glass = TextEditingController(text: '${st.glassMl}');
  }

  @override
  void dispose() {
    _goal.dispose();
    _glass.dispose();
    super.dispose();
  }

  String? _range(String? v, int lo, int hi) {
    final n = int.tryParse((v ?? '').trim());
        if ((v ?? '').trim().isEmpty) return 'This field is required.';
    if (n == null) return 'Enter a value between $lo and $hi ml.';
    if (n < lo || n > hi) return 'Enter a value between $lo and $hi ml.';
    return null;
  }

    String? _glassErr(String? v) {
    final e = _range(v, 50, 1000);
    if (e != null) return e;
    final g = int.tryParse(_goal.text.trim());
    final n = int.parse(v!.trim());
    if (g != null && n > g) return 'One glass amount cannot exceed your daily goal.';
    return null;
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await AppScope.read(
      context,
    ).saveSettings(int.parse(_goal.text.trim()), int.parse(_glass.text.trim()));
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, err ?? 'Settings saved', error: err != null);
  }

  Future<void> _deleteAll() async {
    if (_deleting) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete all data?',
      message:
          'Your profile, routine, water, sleep and journal entries (including photos) will be '
          'permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete everything',
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    final s = AppScope.read(context);
    final err = await s.clearAll();
    if (!mounted) return;
    setState(() => _deleting = false);
    if (err == null) {
      _goal.text = '${s.settings.goalMl}';
      _glass.text = '${s.settings.glassMl}';
    }
    showSnack(context, err ?? 'All data deleted', error: err != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsivePage(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.deep,
                    AppColors.primary,
                    Color(0xFF7BB661),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Goal ${AppScope.of(context).settings.goalMl} ml  \u00B7  Glass ${AppScope.of(context).settings.glassMl} ml',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Water'),
            AppSurface(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _goal,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: InputDecoration(
                        labelText: Lang.I.tr('Daily goal (ml)'),
                        helperText: Lang.I.tr('500 to 5000'),
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction, validator: (v) => _range(v, 500, 5000),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _glass,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: InputDecoration(
                        labelText: Lang.I.tr('One glass (ml)'),
                        helperText: Lang.I.tr('50 to 1000'),
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction, validator: _glassErr,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save water settings'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This is a personal target you choose. It is not medical advice.',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            AppSurface(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                title: const Text('Reminders & notifications'),
                subtitle: const Text('Water, skincare, quiet hours'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RemindersScreen()),
                ),
              ),
            ),
            const SizedBox(height: 22),
            AppSurface(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                title: const Text('Reminders & notifications'),
                subtitle: const Text('Water, skincare, quiet hours'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RemindersScreen()),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const AccountSection(),
            const SizedBox(height: 22),
            const SectionLabel('Notifications'),
            const InfoNote(
              'Reminders are not available yet. Skinora does not send notifications.',
              icon: Icons.notifications_off_outlined,
            ),
            const SizedBox(height: 22),
            const SectionLabel('Privacy'),
            const AppSurface(
              child: Text(
                'Your data is stored in the database and uploads folder of the Skinora server you run. '
                'Photos are not encrypted and are not sent to any third party. '
                'Your data is tied to your account and protected by your password.',
                style: AppText.body,
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Your data'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: .25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This removes your profile, routine, water, sleep and journal. Your account stays.',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deleting ? null : _deleteAll,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      icon: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever_outlined),
                      label: const Text('Delete all my data'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
