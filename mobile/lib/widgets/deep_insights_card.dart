import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../auth/premium_screen.dart' show showPremiumDialog;
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Premium-only, rule-based insights from /api/insights/deep.
class DeepInsightsCard extends StatefulWidget {
  const DeepInsightsCard({super.key});

  @override
  State<DeepInsightsCard> createState() => _DeepInsightsCardState();
}

class _DeepInsightsCardState extends State<DeepInsightsCard> {
  bool _loading = true;
  bool _locked = false;
  String? _error;
  List<String> _insights = const [];
  int _streak = 0;
  int _goalDays = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _today() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _locked = false;
      _error = null;
    });
    try {
      final map = await ApiClient().deepInsights(30, _today());
      final list = map['insights'];
      if (!mounted) return;
      setState(() {
        _insights = list is List ? list.map((e) => e.toString()).toList() : [];
        _streak = (map['routine_streak'] as num?)?.toInt() ?? 0;
        _goalDays = (map['water_goal_days'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e is ApiException && e.premiumRequired) {
          _locked = true;
        } else {
          _error = e is ApiException
              ? e.message
              : 'Could not load deep insights.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: AppColors.gold),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Deep insights', style: AppText.cardTitle),
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_locked) ...[
            const Text(
              'See how water, sleep and routine are linked to your skin rating over 30 days.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => showPremiumDialog(
                context,
                'Deep insights are part of Premium.',
              ),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: const Text('Unlock with Premium'),
            ),
          ] else if (_error != null) ...[
            Text(_error!, style: AppText.bodyMuted),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  Icons.local_fire_department_rounded,
                  '$_streak day routine streak',
                ),
                _Chip(Icons.water_drop_rounded, '$_goalDays water goal days'),
              ],
            ),
            const SizedBox(height: 12),
            for (final t in _insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $t', style: AppText.body),
              ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(text, style: AppText.caption),
        ],
      ),
    );
  }
}
