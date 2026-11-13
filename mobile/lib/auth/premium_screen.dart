import '../screens/edit_account_screen.dart';
import 'premium_membership_screen.dart';
import '../widgets/profile_avatar.dart';

import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../services/api_client.dart' show ApiException;
import '../widgets/common.dart' show confirmDialog;
import 'session.dart';
import '../theme/app_theme.dart';
import '../screens/skin_profile_screen.dart';
import '../screens/settings_screen.dart';

const _purple = Color(0xFF3F8F3A);
const _pink = Color(0xFFE59A7A);

/// Call from any catch block. Opens the upgrade dialog on a 402,
/// otherwise shows the error in a snackbar.
void showPremiumDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.workspace_premium, color: _pink, size: 36),
      title: const Text('Premium feature'),
      content: Text(message.replaceFirst('Premium: ', '')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Not now'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _purple),
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            );
          },
          child: const Text('See Premium'),
        ),
      ],
    ),
  );
}

/// For catch blocks: upgrade dialog on a 402, otherwise a snackbar.
void handleApiError(BuildContext context, Object e) {
  if (!context.mounted) return;
  if (e is ApiException && e.premiumRequired) {
    showPremiumDialog(context, e.message);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : '$e')),
    );
  }
}

/// Account dropdown shown in the navbar.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    Color color,
    String label, {
    String? hint,
  }) {
    final danger = value == 'logout';
    return PopupMenuItem<String>(
      value: value,
      height: 54,
      mouseCursor: SystemMouseCursors.click,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: danger ? AppColors.danger : AppColors.deep,
                  ),
                ),
                if (hint != null) Text(hint, style: AppText.caption),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: danger ? AppColors.danger : AppColors.muted,
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final user = Session.I.user;
    final email = user?.email ?? '';
    final rawName = (user?.name ?? '').trim();
    final name = rawName.isNotEmpty
        ? rawName
        : (email.contains('@') ? email.split('@').first : 'Skinora user');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deep, AppColors.primary, Color(0xFF7BB661)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .7),
                width: 2,
              ),
            ),
            child: ProfileAvatar(name: rawName, size: 50, onDark: true),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 17,
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
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Full access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.danger,
          size: 32,
        ),
        title: const Text('Sign out?'),
        content: const Text('You will need to log in again to use Skinora.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Pop pushed routes so AuthGate (home) is visible again.
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      await Session.I.logout();
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: Lang.I.tr('Account'),
    padding: EdgeInsets.zero,
    offset: const Offset(0, 50),
    elevation: 12,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(minWidth: 270, maxWidth: 300),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ProfileAvatar(
          name: Session.I.user?.name ?? '',
          size: 34,
          onDark: false,
        ),
      ),
    ),
    onSelected: (v) async {
      if (v == 'premium') {
        _push(context, const PremiumScreen());
        return;
      }
      if (v == 'settings') {
        _push(context, const SettingsScreen());
        return;
      } // SETTINGS
      if (v == 'account') {
        await showEditAccountSheet(context);
        return;
      }
      if (v == 'language') {
        showLanguagePicker(context);
        return;
      }
      if (v == 'photo') {
        await showPhotoSheet(context);
      } else if (v == 'premium') {
        _push(context, const PremiumScreen());
      } else if (v == 'profile') {
        _push(context, const SkinProfileScreen());
      } else if (v == 'logout') {
        await _signOut(context);
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem<String>(
        value: 'account',
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            _header(),
            const Positioned(
              right: 14,
              top: 14,
              child: Icon(Icons.edit_rounded, size: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
      const PopupMenuItem<String>(enabled: false, height: 6, child: SizedBox()),
      _item(
        'profile',
        Icons.face_3_rounded,
        const Color(0xFF7C4DFF),
        'Skin profile',
        hint: 'Skin type and concerns',
      ),
      _item(
        'photo',
        Icons.photo_camera_rounded,
        const Color(0xFF14A89B),
        'Change photo',
        hint: 'Update your avatar',
      ),
      _item(
        'premium',
        Icons.workspace_premium,
        const Color(0xFFC9A66B),
        'Premium',
        hint: 'Plans and benefits',
      ),
      _item(
        'settings',
        Icons.settings_rounded,
        const Color(0xFF3F51B5),
        'Settings',
        hint: 'App preferences',
      ), // SETTINGS
      _item(
        'language',
        Icons.language_rounded,
        const Color(0xFF00897B),
        'Language',
        hint: 'English, हिन्दी, मराठी',
      ),
      const PopupMenuDivider(height: 10),
      _item('logout', Icons.logout_rounded, AppColors.danger, 'Sign out'),
      const PopupMenuItem<String>(enabled: false, height: 6, child: SizedBox()),
    ],
  );
}

class LegacyPremiumScreen extends StatefulWidget {
  const LegacyPremiumScreen({super.key});
  @override
  State<LegacyPremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<LegacyPremiumScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() job, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skinora Premium')),
      body: ListenableBuilder(
        listenable: Session.I,
        builder: (_, _) {
          final u = Session.I.user!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _hero(u.isPremium),
                  const SizedBox(height: 16),
                  _table(),
                  const SizedBox(height: 16),
                  if (u.isPremium) ...[
                    Text(
                      _untilLine(u.premiumUntil),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final ok = await confirmDialog(
                                context,
                                title: 'Cancel Premium?',
                                message: 'You will lose unlimited routine steps, progress photos and 14/30 day insights right away. Your data is kept.',
                                confirmLabel: 'Cancel Premium',
                              );
                              if (ok && mounted)
                                await _run(
                                  Session.I.cancelPremium,
                                  'Premium cancelled',
                                );
                            },
                      child: const Text('Cancel Premium'),
                    ),
                  ] else ...[
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _fakePay('monthly', 129),
                              'Premium activated (30 days)',
                            ),
                      child: const Text(
                        'Get Premium \u2013 \u20B9129 for 30 days',
                      ),
                    ),

                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _fakePay('yearly', 999),
                              'Premium activated (1 year)',
                            ),
                      child: const Text(
                        'Get Premium \u2013 \u20B9999 for 1 year',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Demo payment: no real money is charged. Premium lasts 30 days or 1 year and does not renew automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF81778F)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fakePay(String plan, int rupees) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Test payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan == 'yearly'
                  ? 'Skinora Premium - 1 year'
                  : 'Skinora Premium - 30 days',
            ),
            const SizedBox(height: 8),
            Text(
              '\u20B9$rupees',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Demo mode: no real money is charged.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Pay \u20B9$rupees'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => Session.I.activatePremium(plan), 'Premium activated');
  }

  String _untilLine(DateTime? d) {
    if (d == null) return 'Premium is active';
    const m = [
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
    return 'Premium active until ${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Widget _hero(bool premium) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F3B2C), _purple, _pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Color(0xFFC9A66B),
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premium ? 'You are Premium' : 'Go Premium',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Unlimited routine and journal, deeper insights, progress photos.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _table() {
    const rows = [
      ('AI skin scans', '3 in total', '30 per month'),
      ('Journey and insights history', 'Last 2 days', 'Full history'),
      ('Insights range', '2 days', '7, 14, 30 days'),
      ('Routine steps', 'Up to 6', 'Unlimited'),
      ('Journal entries', '10 per month', 'Unlimited'),
      ('Progress photos', 'Not included', 'Included'),
    ];
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE3EAD6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.3),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(1.2),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                SizedBox(height: 36),
                Text('Free', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  'Premium',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _purple),
                ),
              ],
            ),
            for (final r in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(r.$1),
                  ),
                  Text(r.$2),
                  Text(r.$3),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The Premium page the whole app opens. It shows the demo membership page.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) => const PremiumMembershipScreen();
}
