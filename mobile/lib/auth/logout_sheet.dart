import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../theme/app_theme.dart';
import 'session.dart';

/// Bottom sheet: asks for confirmation, then signs the user out.
Future<void> confirmLogout(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.lavender,
              child: Icon(
                Icons.logout_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Logout', style: AppText.sectionTitle),
            const SizedBox(height: 6),
            const Text(
              'Are you sure you want to log out?',
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Yes, Logout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true) return;
  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  await Session.I.logout();
}
