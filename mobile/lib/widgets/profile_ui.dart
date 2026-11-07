import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../theme/app_theme.dart';

/// Rounded menu row for the Profile tab (icon, title, optional subtitle/badge).
class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = AppColors.primary,
    this.badge,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? badge;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.danger : color;
    final radius = BorderRadius.circular(kRadius);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: c, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.cardTitle.copyWith(
                        color: danger ? AppColors.danger : AppColors.deep,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[badge!, const SizedBox(width: 6)],
              Icon(
                Icons.chevron_right_rounded,
                color: danger ? c : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green gradient card at the top of Profile: avatar, name, email, plan chip.
class AccountHeader extends StatelessWidget {
  const AccountHeader({
    super.key,
    required this.name,
    required this.email,
    required this.isPremium,
    required this.onPlanTap,
  });

  final String name;
  final String email;
  final bool isPremium;
  final VoidCallback onPlanTap;

  @override
  Widget build(BuildContext context) {
    final n = name.trim();
    final initial = n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F7A3A), Color(0xFF5FA24C)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: .22),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.isEmpty ? 'Your account' : n,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: isPremium
                ? 'Premium plan active'
                : 'Free plan, open Premium',
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: onPlanTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_open_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPremium ? 'Premium' : 'Free',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: "Are you sure you want to log out?". Returns true on confirm.
Future<bool> showLogoutSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.danger.withValues(alpha: .12),
              child: const Icon(Icons.logout_rounded, color: AppColors.danger),
            ),
            const SizedBox(height: 14),
            const Text('Log out?', style: AppText.sectionTitle),
            const SizedBox(height: 6),
            const Text(
              'Are you sure you want to log out of Skinora?',
              textAlign: TextAlign.center,
              style: AppText.bodyMuted,
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
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: const Text('Yes, log out'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
