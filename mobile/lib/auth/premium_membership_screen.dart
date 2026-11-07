import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../services/api_client.dart' show ApiClient, ApiException;
import '../services/demo_payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/premium_ui.dart' show PremiumBadge;
import 'payment.dart';
import 'session.dart';

const _features = <String>[
  'Unlimited routine steps',
  'Unlimited skin journal entries',
  'Skin Journal progress photos',
  'Extended insights (7, 14 and 30 days)',
  'Enhanced skin progress tracking',
  '30 AI skin scans every month',
];

const _rows = <List<String>>[
  ['Routine steps', '6', 'Unlimited'],
  ['Journal entries', '10 / month', 'Unlimited'],
  ['Progress photos', '-', 'Yes'],
  ['Deep insights (7, 14, 30 days)', '-', 'Yes'],
  ['AI skin scans', '3 in total', '30 / month'],
];

class PremiumMembershipScreen extends StatefulWidget {
  const PremiumMembershipScreen({super.key});

  @override
  State<PremiumMembershipScreen> createState() =>
      _PremiumMembershipScreenState();
}

class _PremiumMembershipScreenState extends State<PremiumMembershipScreen> {
  final _svc = DemoPaymentService();
  List<DemoPlan> _plans = const [];
  List<DemoPayment> _history = const [];
  bool _enabled = true;
  bool _loading = true;
  bool _paying = false;
  String? _error;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _plans.isEmpty;
      _error = null;
    });
    try {
      final r = await _svc.plans();
      final h = await _svc.history();
      try {
        // History loading also settles any finished payment, so refresh the user.
        final me = await ApiClient().request(
          'GET',
          '/api/auth/me',
        ) as Map<String, dynamic>;
        Session.I.setUser(me);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _plans = r.plans;
        _enabled = r.demo;
        _history = h;
        _selected ??= r.plans.isEmpty ? null : r.plans.first.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load Premium plans.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subscribe() async {
    if (_paying) return;
    final matches = _plans.where((p) => p.id == _selected);
    if (matches.isEmpty) return;
    setState(() => _paying = true);
    try {
      await payForPremium(matches.first.id);
      if (mounted) showSnack(context, 'Payment successful. Premium is active.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          'Payment could not be completed. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
    if (mounted) _load();
  }

  Widget _statusCard() {
    final u = Session.I.user;
    final active = u?.isPremium == true;
    final until = u?.premiumUntil;
    return AppSurface(
      child: Row(
        children: [
          Icon(
            active ? Icons.verified_rounded : Icons.workspace_premium_outlined,
            color: active ? AppColors.success : AppColors.gold,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Premium Active' : 'Free plan',
                  style: AppText.cardTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? (until == null
                            ? 'All features unlocked'
                            : 'Active until ${demoDate(until)}')
                      : 'Upgrade to unlock every feature.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          if (active) const PremiumBadge(),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _planTile(DemoPlan p, bool best) {
    final sel = _selected == p.id;
    final radius = BorderRadius.circular(kRadius);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: sel ? AppColors.lavender : Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          mouseCursor: SystemMouseCursors.click,
          onTap: _paying ? null : () => setState(() => _selected = p.id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: sel ? AppColors.primary : AppColors.border,
                width: sel ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  sel
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: sel ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: AppText.cardTitle),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${p.days} days', style: AppText.caption),
                          if (best) _tag('BEST VALUE', AppColors.gold),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(p.price, style: AppText.cardTitle.copyWith(fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featuresCard() => AppSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What you get', style: AppText.cardTitle),
        const SizedBox(height: 10),
        for (final f in _features)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(f, style: AppText.body)),
              ],
            ),
          ),
      ],
    ),
  );

  TableRow _tr(List<String> c, {bool header = false}) => TableRow(
    children: [
      for (var i = 0; i < c.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            c[i],
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: (header || i == 2)
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: header
                  ? AppColors.muted
                  : (i == 2 ? AppColors.primary : AppColors.deep),
            ),
          ),
        ),
    ],
  );

  Widget _comparison() => AppSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Free vs Premium', style: AppText.cardTitle),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2.3),
            1: FlexColumnWidth(1.3),
            2: FlexColumnWidth(1.4),
          },
          children: [
            _tr(const ['Feature', 'Free', 'Premium'], header: true),
            for (final r in _rows) _tr(r),
          ],
        ),
      ],
    ),
  );

  Widget _historyTile(DemoPayment h) {
    final ok = h.status == 'success';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${demoDate(h.createdAt)} - ${h.txnId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                demoRupees(h.amountPaise),
                style: AppText.cardTitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 3),
              _tag(
                ok ? 'SUCCESS' : 'FAILED',
                ok ? AppColors.success : AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _content() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [ErrorRetry(message: _error!, onRetry: _load)];
    }
    var maxDays = 0;
    for (final p in _plans) {
      if (p.days > maxDays) maxDays = p.days;
    }
    return [
      if (!_enabled)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: InfoNote('Online payments are not set up on this server yet.'),
        ),
      if (!(Session.I.user?.isPremium == true)) ...[
        const SectionLabel('Choose your plan'),
        for (final p in _plans)
          _planTile(p, p.days == maxDays && _plans.length > 1),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: (_selected == null || !_enabled || _paying)
              ? null
              : _subscribe,
          icon: _paying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.workspace_premium),
          label: Text(_paying ? 'Processing Payment...' : 'Subscribe Now'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Secure payment by Cashfree. Premium turns on only after your payment is confirmed.',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
      const SizedBox(height: 18),
      _featuresCard(),
      const SizedBox(height: 14),
      _comparison(),
      const SizedBox(height: 18),
      const SectionLabel('Payment history'),
      AppSurface(
        child: _history.isEmpty
            ? const Text('No payments yet.', style: AppText.bodyMuted)
            : Column(
                children: [for (final h in _history.take(10)) _historyTile(h)],
              ),
      ),
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Membership')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  ListenableBuilder(
                    listenable: Session.I,
                    builder: (context, _) => _statusCard(),
                  ),
                  const SizedBox(height: 14),
                  ..._content(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
