import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../auth/premium_screen.dart' show PremiumScreen, handleApiError;
import '../auth/session.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// "Account" block for Settings: plan, Cancel Premium and Sign out.
class AccountSection extends StatefulWidget {
  const AccountSection({super.key});
  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  bool _busy = false;

  

  Future<void> _signOut() async {
    final ok = await confirmDialog(
      context,
      title: 'Sign out?',
      message: 'You can sign back in anytime.',
      confirmLabel: 'Sign out',
      destructive: false,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await Session.I.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final u = Session.I.user;
        if (u == null) return const SizedBox.shrink();
        final until = u.premiumUntil?.toString().split(' ').first ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Account'),
            AppSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name, style: AppText.cardTitle),
                  const SizedBox(height: 2),
                  Text(u.email, style: AppText.caption),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Plan: ', style: AppText.body),
                      if (u.isPremium)
                        const SizedBox.shrink()
                      else
                        const Text('Free', style: AppText.cardTitle),
                    ],
                  ),
                  if (u.isPremium) ...[
                    const SizedBox(height: 4),
                    Text('Active until $until', style: AppText.caption),
                  ],
                  const SizedBox(height: 14),
                  if (!u.isPremium)
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PremiumScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.workspace_premium),
                      label: const Text('Upgrade to Premium'),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }
}
