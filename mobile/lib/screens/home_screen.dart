import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../auth/premium_screen.dart' show PremiumScreen;
import '../auth/session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/brand_ui.dart';
import '../widgets/common.dart';
import '../widgets/ring_dashboard.dart';
import 'insights_screen.dart';
import 'journal_screen.dart';
import 'skin_profile_screen.dart';
import 'skin_scan_screen.dart';
import 'sleep_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onTab});
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final name = s.profile.displayName;
    return ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prettyDateYear(s.today).toUpperCase(), style: AppText.eyebrow),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              name.isEmpty ? 'Your skin, your glow' : 'Hi, $name',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.pageTitle,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Care for your skin, one calm ritual at a time.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 20),
          const HeroBanner(),
          const SizedBox(height: 16),
          const SizedBox.shrink(),
          LoadGate(state: s, builder: () => _content(context, s)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppState s) {
    final p = s.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RingDashboard(
          onRoutine: () => onTab(1),
          onWater: () => onTab(2),
          onSleep: () => openScreen(context, const SleepScreen()),
        ),
        const SizedBox(height: 20),
        if (p.isSet)
          ProfileSummaryCard(
            profile: p,
            onTap: () => openScreen(context, const SkinProfileScreen()),
          )
        else
          _WelcomeBanner(
            onSetup: () => openScreen(context, const SkinProfileScreen()),
          ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: Text("Today's care plan", style: AppText.sectionTitle),
            ),
            TextButton(
              onPressed: () => onTab(1),
              child: const Text('View routine'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashTile(
              color: AppColors.journal,
              track: AppColors.journal.withValues(alpha: .15),
              premiumFeature: true,
              title: 'Journal',
              caption: s.journal.isEmpty
                  ? 'No entries yet'
                  : '${s.journal.length} entries',
              icon: Icons.auto_awesome_rounded,
              onTap: () => openScreen(context, const JournalScreen()),
            ),
            const SizedBox(width: 10),
            DashTile(
              color: AppColors.insight,
              track: AppColors.insight.withValues(alpha: .15),
              premiumFeature: true,
              title: 'Insights',
              caption: 'Your trends',
              icon: Icons.insights_rounded,
              onTap: () => openScreen(context, const InsightsScreen()),
            ),
            const SizedBox(width: 10),
            DashTile(
              color: AppColors.primary,
              track: AppColors.primary.withValues(alpha: .15),
              premiumFeature: true,
              title: 'AI Scan',
              caption: 'Analyze skin',
              icon: Icons.document_scanner_rounded,
              onTap: () => openScreen(context, const SkinScanScreen()),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _HydrationCard(onOpen: () => onTab(2)),
        const SizedBox(height: 22),
        const PromoCarousel(),
        const SizedBox(height: 24),
        const AppFooter(),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3F8F3A), Color(0xFF7BB661), Color(0xFFB7D77A)],
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .18),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 470;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A LITTLE SELF-CARE GOES A LONG WAY',
              style: TextStyle(
                color: Color(0xFFF1FAD9),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Make time for your glow.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Set up your skin profile to start tracking your routine.',
              style: TextStyle(color: Colors.white, height: 1.45),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onSetup,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Set up skin profile'),
            ),
          ],
        );
        final art = Container(
          width: compact ? 62 : 106,
          height: compact ? 62 : 106,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .25)),
          ),
          child: Icon(
            Icons.spa_rounded,
            size: compact ? 35 : 58,
            color: Colors.white,
          ),
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [art, const SizedBox(height: 18), copy],
              )
            : Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 20),
                  art,
                ],
              );
      },
    ),
  );
}

class _HydrationCard extends StatefulWidget {
  const _HydrationCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  State<_HydrationCard> createState() => _HydrationCardState();
}

class _HydrationCardState extends State<_HydrationCard> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    final s = AppScope.read(context);
    setState(() => _busy = true);
    final err = await s.addWater(s.settings.glassMl);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showSnack(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final w = s.water!;
    final remaining = w.goalMl - w.totalMl;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.waterSoft,
                child: Icon(Icons.water_drop_rounded, color: AppColors.water),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily hydration', style: AppText.cardTitle),
                    SizedBox(height: 3),
                    Text(
                      'Pause and sip throughout your day',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${w.totalMl > 5000 ? 5000 : w.totalMl} ml',
                style: AppText.cardTitle.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppProgressBar(
            value: w.progress,
            color: AppColors.water,
            background: AppColors.waterSoft,
          ),
          const SizedBox(height: 12),
          Text(
            remaining > 0
                ? '$remaining ml left to your chosen goal'
                : 'Your chosen goal is complete!',
            style: AppText.caption,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: widget.onOpen,
                child: const Text('Open tracker'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add glass (${s.settings.glassMl} ml)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final u = Session.I.user;
        if (u == null) return const SizedBox.shrink();

        if (u.isPremium) {
          final until = u.premiumUntil?.toString().split(' ').first;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: AppColors.gold),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: AppColors.gold,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Premium member', style: AppText.cardTitle),
                        const SizedBox(height: 2),
                        Text(
                          until == null
                              ? 'All features unlocked'
                              : 'Active until $until',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius + 4),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.deep, AppColors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .25),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: AppColors.gold,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Unlock Skinora Premium',
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlimited routine and journal, deep insights and progress photos.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => openScreen(context, const PremiumScreen()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.deep,
                  ),
                  child: const Text('See Premium'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
