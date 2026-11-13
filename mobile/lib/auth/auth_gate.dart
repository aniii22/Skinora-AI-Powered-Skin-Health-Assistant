import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import 'auth_screen.dart';
import 'session.dart';

bool _wasSignedIn = false;

/// Shows login/register until the user is signed in, then [child].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Session.I,
    builder: (ctx, _) {
      final inNow = Session.I.signedIn;
      if (_wasSignedIn && !inNow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctx.mounted) Navigator.of(ctx).popUntil((r) => r.isFirst);
        });
      }
      _wasSignedIn = inNow;
      if (!Session.I.ready) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (Session.I.signedIn) return child;
      if (Session.I.restoreFailed) return const _ReconnectScreen();
      return const AuthScreen();
    },
  );
}

/// Shown when a saved login exists but the server cannot be reached.
class _ReconnectScreen extends StatelessWidget {
  const _ReconnectScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                "Can't reach Skinora",
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your login is saved. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: Session.I.retryRestore,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: Session.I.discardSession,
                child: const Text('Sign in with a different account'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
