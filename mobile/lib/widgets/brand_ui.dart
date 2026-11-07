import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../auth/premium_screen.dart' show PremiumScreen;
import '../auth/session.dart';
import '../screens/journal_screen.dart';
import '../screens/routine_screen.dart';
import '../screens/skin_scan_screen.dart';
import '../screens/sleep_screen.dart';
import '../screens/water_screen.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class _ArtPainter extends CustomPainter {
  const _ArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    p.color = Colors.white.withValues(alpha: .10);
    canvas.drawCircle(
      Offset(size.width * .88, size.height * .15),
      size.height * .55,
      p,
    );
    p.color = Colors.white.withValues(alpha: .07);
    canvas.drawCircle(
      Offset(size.width * .98, size.height * .95),
      size.height * .6,
      p,
    );
    canvas.drawCircle(
      Offset(size.width * .10, size.height * 1.05),
      size.height * .45,
      p,
    );
    final leaf = Path()
      ..moveTo(size.width * .74, size.height * .88)
      ..quadraticBezierTo(
        size.width * .66,
        size.height * .35,
        size.width * .90,
        size.height * .18,
      )
      ..quadraticBezierTo(
        size.width * .98,
        size.height * .66,
        size.width * .74,
        size.height * .88,
      )
      ..close();
    p.color = Colors.white.withValues(alpha: .16);
    canvas.drawPath(leaf, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Illustrated hero banner with tagline (Home).
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.deep, AppColors.primary, Color(0xFF7BB661)],
          ),
        ),
        child: CustomPaint(
          painter: const _ArtPainter(),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GLOW FROM WITHIN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Small habits.\nBig glow.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Routine, water, sleep and AI skin scan, all in one place.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .35),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a promo card opens when tapped.
enum _PromoTarget { premium, water, sleep, journal }

class _Promo {
  const _Promo(
    this.eyebrow,
    this.title,
    this.line,
    this.icon,
    this.colors, {
    required this.target,
  });
  final String eyebrow;
  final String title;
  final String line;
  final IconData icon;
  final List<Color> colors;
  final _PromoTarget target;

  bool get premium => target == _PromoTarget.premium;
}

/// Auto-sliding promo cards. Each card opens its own page.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _ctrl = PageController(viewportFraction: 1.0);
  Timer? _timer;
  int _page = 0;

  List<_Promo> _promos() {
    final premium = Session.I.user?.isPremium == true;
    return [
      if (!premium)
        const _Promo(
          'LIMITED OFFER',
          'Premium for just \u20B91',
          'Unlimited routine, deep insights and progress photos.',
          Icons.workspace_premium,
          [Color(0xFF1F3B2C), Color(0xFFC9A66B)],
          target: _PromoTarget.premium,
        ),
      const _Promo(
        'STAY HYDRATED',
        'Sip your way to glow',
        'Water keeps skin feeling fresh. Log every glass.',
        Icons.water_drop_rounded,
        [Color(0xFF278BD8), Color(0xFF8FD0F5)],
        target: _PromoTarget.water,
      ),
      const _Promo(
        'BEAUTY SLEEP',
        '8 hours. Every night.',
        'Rest is part of your routine. Log your sleep.',
        Icons.nightlight_round,
        [Color(0xFF4B3F91), Color(0xFF7B69C9)],
        target: _PromoTarget.sleep,
      ),
      const _Promo(
        'SKIN JOURNAL',
        'Notice. Note. Glow.',
        'Rate your skin daily and see what works for you.',
        Icons.auto_awesome_rounded,
        [Color(0xFFD27A45), Color(0xFFE9B27A)],
        target: _PromoTarget.journal,
      ),
    ];
  }

  void _open(_PromoTarget t) {
    switch (t) {
      case _PromoTarget.premium:
        openScreen(context, const PremiumScreen());
      case _PromoTarget.water:
        openScreen(
          context,
          Scaffold(
            appBar: AppBar(title: const Text('Hydration')),
            body: const WaterScreen(),
          ),
        );
      case _PromoTarget.sleep:
        openScreen(context, const SleepScreen());
      case _PromoTarget.journal:
        openScreen(context, const JournalScreen());
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final n = _promos().length;
      _ctrl.animateToPage(
        (_page + 1) % n,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promos = _promos();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: promos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _card(context, promos[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < promos.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _card(BuildContext context, _Promo p) {
    return Semantics(
      button: true,
      label: '${p.title}. ${p.line}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            mouseCursor: SystemMouseCursors.click,
            onTap: () => _open(p.target),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: p.colors,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: CustomPaint(
                  painter: const _ArtPainter(),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.eyebrow,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .85),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                p.line,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .92),
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.premium
                                    ? 'Tap to upgrade  \u203A'
                                    : 'Tap to open  \u203A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          p.icon,
                          color: Colors.white.withValues(alpha: .95),
                          size: 46,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark green footer used at the bottom of Home and Profile.
/// Every tag opens its screen and shows a pointer cursor on hover.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  /// Opens a tab-style screen (no AppBar of its own) on its own page,
  /// with a back button.
  void _openPage(BuildContext context, String title, Widget body) {
    openScreen(
      context,
      Scaffold(
        appBar: AppBar(title: Text(title)),
        body: body,
      ),
    );
  }

  Widget _tag(
    BuildContext context,
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      label: text,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.white.withValues(alpha: .10),
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            mouseCursor: SystemMouseCursors.click,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.deep,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 38, height: 38, fit: BoxFit.contain),
              const SizedBox(width: 10),
              const Text(
                'Skinora',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Healthy skin starts with small, daily care.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(
                context,
                Icons.checklist_rounded,
                'Routine',
                () => _openPage(context, 'Routine', const RoutineScreen()),
              ),
              _tag(
                context,
                Icons.water_drop_rounded,
                'Hydration',
                () => _openPage(context, 'Hydration', const WaterScreen()),
              ),
              _tag(
                context,
                Icons.nightlight_round,
                'Sleep',
                () => openScreen(context, const SleepScreen()),
              ),
              _tag(
                context,
                Icons.auto_awesome_rounded,
                'Journal',
                () => openScreen(context, const JournalScreen()),
              ),
              _tag(
                context,
                Icons.document_scanner_rounded,
                'AI Scan',
                () => openScreen(context, const SkinScanScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: .15), height: 1),
          const SizedBox(height: 12),
          Text(
            'Skinora is a wellness tracker, not a medical service. It does not diagnose skin conditions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\u00A9 2026 Skinora. Made with care in India.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
