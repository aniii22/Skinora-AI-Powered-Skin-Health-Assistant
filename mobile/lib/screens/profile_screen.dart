import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../auth/logout_sheet.dart';
import '../auth/premium_screen.dart' show PremiumScreen;
import '../auth/session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_ui.dart';
import '../widgets/common.dart';
import '../widgets/premium_ui.dart' show PremiumBadge;
import '../widgets/profile_avatar.dart';
import 'insights_screen.dart';
import 'journal_screen.dart';
import 'settings_screen.dart';
import 'skin_profile_screen.dart';
import 'sleep_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ResponsivePage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AccountHeader(),
          const SizedBox(height: 22),
          const SectionLabel('Account'),
          _Group(
            children: [
              _Row(
                icon: Icons.face_retouching_natural_rounded,
                color: AppColors.primary,
                title: 'Skin profile',
                subtitle: s.profile.isSet
                    ? 'View or edit your skin details'
                    : 'Not set up yet',
                onTap: () => openScreen(context, const SkinProfileScreen()),
              ),
              _Row(
                icon: Icons.workspace_premium,
                color: AppColors.gold,
                title: 'Premium',
                subtitle: 'Plans, limits and benefits',
                onTap: () => openScreen(context, const PremiumScreen()),
              ),
              _Row(
                icon: Icons.settings_rounded,
                color: AppColors.primary,
                title: 'Settings',
                subtitle: 'Water goal, privacy and data',
                onTap: () => openScreen(context, const SettingsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('Tools'),
          _Group(
            children: [
              _Row(
                icon: Icons.nightlight_round,
                color: AppColors.sleep,
                title: 'Sleep tracker',
                subtitle: 'Log bedtime and wake-up time',
                onTap: () => openScreen(context, const SleepScreen()),
              ),
              _Row(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.journal,
                title: 'Your Skin Journey',
                subtitle: 'Notes, ratings and progress photos',
                onTap: () => openScreen(context, const JournalScreen()),
              ),
              _Row(
                icon: Icons.insights_rounded,
                color: AppColors.insight,
                title: 'Skin insights',
                subtitle: 'Trends from your own logs',
                onTap: () => openScreen(context, const InsightsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Group(
            children: [
              _Row(
                icon: Icons.logout_rounded,
                color: AppColors.danger,
                title: 'Log out',
                subtitle: 'Sign out of this device',
                onTap: () => confirmLogout(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const InfoNote(
            'Skinora provides general skincare tracking and is not a substitute for a dermatologist.',
          ),
          const SizedBox(height: 22),
          const AppFooter(),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final u = Session.I.user;
        final profileName = s.profile.displayName;
        final name = profileName.isNotEmpty
            ? profileName
            : (u?.name ?? 'Guest');
        final premium = u?.isPremium == true;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.deep, AppColors.primary, Color(0xFF7BB661)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .25),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              ProfileAvatar(
                size: 64,
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
                      u?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (premium)
                      const SizedBox.shrink()
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'FREE PLAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const Divider(height: 1, indent: 72),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.cardTitle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
