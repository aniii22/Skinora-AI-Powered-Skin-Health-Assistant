import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../auth/premium_screen.dart' show AccountMenu, PremiumScreen;
import '../auth/logout_sheet.dart';
import '../auth/session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'routine_screen.dart';
import 'skin_scan_screen.dart';
import 'water_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) AppScope.read(context).refreshIfNeeded();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      AppScope.read(context)
          .refreshIfNeeded(maxAge: const Duration(seconds: 20));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime _lastScanTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _go(int i) => setState(() => _index = i);

  // Bottom bar slot 2 opens AI Skin Scan on top of the shell. Water keeps
  // page index 2, so the Hydration card on Home can still switch to it.
  void _onNavTap(int i) {
    if (i == 2) {
      final now = DateTime.now();
      if (now.difference(_lastScanTap) < const Duration(milliseconds: 700)) return;
      _lastScanTap = now;
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SkinScanScreen()));
      return;
    }
    _go(i);
  }

  Widget _page() {
    switch (_index) {
      case 1:
        return const RoutineScreen();
      case 2:
        return const WaterScreen();
      case 3:
        return const ProfileScreen();
      default:
        return HomeScreen(onTab: _go);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 640;
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 9),
              const Flexible(
                child: Text(
                  'Skinora',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.deep,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SKIN WELLNESS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (wide)
              TextButton.icon(
                onPressed: () => confirmLogout(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ListenableBuilder(
              listenable: Session.I,
              builder: (context, _) => Session.I.user?.isPremium == true
                  ? const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
            ),
            const NotificationBell(),
            const _UpgradePill(),
            const AccountMenu(),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_index), child: _page()),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index == 2 ? 0 : _index,
          onDestinationSelected: _onNavTap,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: Lang.I.tr('Home'),
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist_rounded),
              label: Lang.I.tr('Routine'),
            ),
            NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              selectedIcon: Icon(Icons.document_scanner_rounded),
              label: Lang.I.tr('AI Skin Scan'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: Lang.I.tr('Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradePill extends StatelessWidget {
  const _UpgradePill();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final prem = Session.I.user?.isPremium == true;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gold, Color(0xFFE6CE9A)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 16,
                    color: AppColors.deep,
                  ),
                  SizedBox(width: 5),
                  Text(
                    prem ? 'Premium' : 'Go Premium',
                    style: TextStyle(
                      color: AppColors.deep,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
