import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../auth/premium_screen.dart' show showPremiumDialog;
import '../auth/session.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/deep_insights_card.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _days = Session.I.user?.isPremium == true ? 7 : 2;
  late Future<Insights> _future;

  @override
  void initState() {
    super.initState();
    _future = AppScope.read(context).loadInsights(_days);
  }

  void _reload([int? days]) {
    final s = AppScope.read(context);
    setState(() {
      if (days != null) _days = days;
      _future = s.loadInsights(_days);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skin insights')),
      body: ResponsivePage(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              eyebrow: 'YOUR OWN DATA',
              title: 'Skin insights',
              subtitle: 'Simple summaries of what you have logged. These are observations, not diagnoses.',
            ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  const ButtonSegment(value: 2, label: Text('2 days')),
                  for (final d in const [7, 14, 30])
                    ButtonSegment(
                      value: d,
                      label: Text('$d days'),
                      icon: Session.I.user?.isPremium == true
                          ? null
                          : const Icon(Icons.lock_rounded, size: 16),
                    ),
                ],
                selected: {_days},
                onSelectionChanged: (v) {
                  final d = v.first;
                  if (d > 2 && Session.I.user?.isPremium != true) {
                    showPremiumDialog(
                      context,
                      'Premium: 7, 14 and 30 day insights are part of Premium.',
                    );
                    return;
                  }
                  _reload(d);
                },
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Insights>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  final e = snap.error;
                  return ErrorRetry(
                    message: e is ApiException
                        ? e.message
                        : 'Could not load insights.',
                    onRetry: _reload,
                  );
                }
                return _body(snap.data!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppText.cardTitle.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _body(Insights d) {
    final showBars = d.days <= 14;

    final routineTotal = d.routine.fold<int>(0, (a, b) => a + b.total);
    final routineDone = d.routine.fold<int>(0, (a, b) => a + b.completed);
    final routinePct = routineTotal == 0
        ? 0
        : (routineDone / routineTotal * 100).round();

    final waterSum = d.water.fold<int>(0, (a, b) => a + b.totalMl);
    final waterAvg = d.days == 0 ? 0 : (waterSum / d.days).round();
    final goalDays = d.water.where((w) => w.totalMl >= d.waterGoalMl).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DeepInsightsCard(),
        const SizedBox(height: 14),
        const SectionLabel('Observed from your tracking'),
        _card('Routine', Icons.checklist_rounded, AppColors.pink, [
          if (routineTotal == 0)
            const Text(
              'No routine steps to summarise yet.',
              style: AppText.bodyMuted,
            )
          else ...[
            Text(
              '$routinePct% of steps completed ($routineDone of $routineTotal)',
              style: AppText.body,
            ),
            const SizedBox(height: 4),
            const Text(
              'Based on the number of steps you have now.',
              style: AppText.caption,
            ),
            if (showBars) ...[
              const SizedBox(height: 12),
              for (final r in d.routine)
                HistoryBar(
                  label: dayLabel(r.day),
                  value: '${r.completed}/${r.total}',
                  progress: r.ratio,
                ),
            ],
          ],
        ]),
        _card('Hydration', Icons.water_drop_rounded, AppColors.water, [
          if (waterSum == 0)
            const Text(
              'No water logged in this period.',
              style: AppText.bodyMuted,
            )
          else ...[
            Text('Average $waterAvg ml per day', style: AppText.body),
            const SizedBox(height: 4),
            Text(
              'You reached your ${d.waterGoalMl} ml goal on $goalDays of ${d.days} days.',
              style: AppText.caption,
            ),
            if (showBars) ...[
              const SizedBox(height: 12),
              for (final w in d.water)
                HistoryBar(
                  label: dayLabel(w.day),
                  value: '${w.totalMl > 5000 ? 5000 : w.totalMl} ml',
                  progress: d.waterGoalMl == 0 ? 0 : w.totalMl / d.waterGoalMl,
                  color: AppColors.water,
                  background: AppColors.waterSoft,
                ),
            ],
          ],
        ]),
        _card('Sleep', Icons.nightlight_round, AppColors.sleep, [
          if (d.sleepCount == 0)
            const Text(
              'No sleep entries in this period.',
              style: AppText.bodyMuted,
            )
          else
            Text(
              '${d.sleepCount} ${d.sleepCount == 1 ? 'entry' : 'entries'}, average '
              '${formatMinutes(d.sleepAvgMinutes.round())} per entry',
              style: AppText.body,
            ),
        ]),
        _card('Journal', Icons.auto_awesome_rounded, AppColors.journal, [
          if (d.journalCount == 0)
            const Text(
              'No journal entries in this period.',
              style: AppText.bodyMuted,
            )
          else ...[
            Text(
              '${d.journalCount} ${d.journalCount == 1 ? 'entry' : 'entries'}',
              style: AppText.body,
            ),
            if (d.journalAvgRating != null) ...[
              const SizedBox(height: 4),
              Text(
                'Average skin rating: ${d.journalAvgRating!.toStringAsFixed(1)} out of 5',
                style: AppText.body,
              ),
            ],
          ],
        ]),
        const SizedBox(height: 8),
        const SectionLabel('General skincare information'),
        const AppSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Not based on your data', style: AppText.caption),
              SizedBox(height: 8),
              Text(
                '\u2022 Gentle cleansing and daily sunscreen are common basics.',
                style: AppText.body,
              ),
              SizedBox(height: 6),
              Text(
                '\u2022 Introduce one new product at a time and stop if irritation appears.',
                style: AppText.body,
              ),
              SizedBox(height: 6),
              Text(
                '\u2022 Persistent or worrying skin changes are best checked by a dermatologist.',
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const InfoNote(
          'Skinora does not diagnose skin conditions or predict results.',
        ),
      ],
    );
  }
}
