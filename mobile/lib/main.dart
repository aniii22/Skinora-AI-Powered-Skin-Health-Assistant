import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'auth/premium_screen.dart' show showPremiumDialog;
import 'auth/session.dart';
import 'screens/shell.dart';
import 'services/api_client.dart';
import 'services/local_notifier.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/pointer_cursors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.I.init();
  // Notifications start after the first frame, so the permission prompt cannot block startup.
  runApp(const SkinoraApp());
  WidgetsBinding.instance.addPostFrameCallback((_) => LocalNotifier.I.init());
}

class SkinoraApp extends StatefulWidget {
  const SkinoraApp({super.key});

  @override
  State<SkinoraApp> createState() => _SkinoraAppState();
}

class _SkinoraAppState extends State<SkinoraApp> {
  final _nav = GlobalKey<NavigatorState>();
  final AppState _state = AppState(ApiClient());
  bool _wasSignedIn = false;

  @override
  void initState() {
    super.initState();
    Session.I.addListener(_onSession);
    _state.addListener(_onState);
    _onSession();
  }

  /// Load data only after sign-in; wipe it on sign-out.
  void _onSession() {
    final now = Session.I.signedIn;
    if (now == _wasSignedIn) return;
    _wasSignedIn = now;
    _state.reset();
    if (now) {
      _state.init();
      LocalNotifier.I.syncFromServer(_state.api);
    } else {
      LocalNotifier.I.cancelAll();
    }
  }

  /// Any "Premium: ..." error from the server opens the upgrade dialog.
  void _onState() {
    final msg = _state.premiumNotice;
    if (msg == null) return;
    _state.premiumNotice = null;
    final ctx = _nav.currentContext;
    if (ctx != null) showPremiumDialog(ctx, msg);
  }

  @override
  void dispose() {
    Session.I.removeListener(_onSession);
    _state.removeListener(_onState);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        navigatorKey: _nav,
        title: 'Skinora',
        debugShowCheckedModeBanner: false,
        theme: withPointerCursors(buildAppTheme()),
        home: const AuthGate(child: HomeShell()),
      ),
    );
  }
}
