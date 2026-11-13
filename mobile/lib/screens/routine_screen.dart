import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../auth/premium_screen.dart' show showPremiumDialog;
import '../auth/session.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/personal_plan.dart';
import '../widgets/ring_dashboard.dart';
import '../widgets/task_celebration.dart';
import '../widgets/daily_thoughts.dart' show selectedRoutineDay;

bool get _isPastSelected {
  final n = DateTime.now();
  final d = selectedRoutineDay.value;
  return !(d.year == n.year && d.month == n.month && d.day == n.day);
}

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ValueListenableBuilder<DateTime>(
      valueListenable: selectedRoutineDay,
      builder: (context, _, _) => _page(context, s),
    );
  }

  Widget _page(BuildContext context, AppState s) {
    return ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            eyebrow: 'YOUR DAILY RITUAL',
            title: 'Daily routine',
            subtitle: 'Keep your routine simple, gentle and consistent.',
          ),
          const WeekStrip(),
          const SizedBox(height: 18),
          const PersonalPlanCard(),
          const SizedBox(height: 18),
          LoadGate(state: s, builder: () => _content(context, s)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppState s) {
    final past = _isPastSelected;
    final sel = selectedRoutineDay.value;
    RoutineDay? pastDay;
    if (past) {
      for (final d in s.routineHistory) {
        if (d.day.year == sel.year && d.day.month == sel.month && d.day.day == sel.day) {
          pastDay = d;
        }
      }
    }
    final total = past ? (pastDay?.total ?? 0) : s.routine.length;
    final done = past ? (pastDay?.completed ?? 0) : s.routine.where((r) => r.done).length;
    final pct = total == 0 ? 0 : (done / total * 100).round();
    final hasHistory = s.routineHistory.any((d) => d.completed > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isPastSelected) ...[
          const InfoNote(
            'Past day selected: changes are locked. Select today to edit.',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 12),
        ],
        AppSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      past ? 'Progress on ${dayLabel(sel)}' : "Today's progress",
                      style: AppText.cardTitle.copyWith(fontSize: 16),
                    ),
                  ),
                  Text(
                    '$done/$total',
                    style: AppText.cardTitle.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              AppProgressBar(value: total == 0 ? 0 : done / total, height: 9),
              const SizedBox(height: 6),
              Text(
                total == 0
                    ? (past ? 'No data for this day' : 'Add a step to get started')
                    : '$pct% complete  •  ${Session.I.user?.isPremium == true ? '$total steps' : '$total / 6 steps (free plan)'}',
                style: AppText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _period(
          context,
          s,
          'morning',
          'Morning routine',
          Icons.wb_sunny_outlined,
        ),
        const SizedBox(height: 16),
        _period(
          context,
          s,
          'evening',
          'Evening routine',
          Icons.nights_stay_outlined,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: (done == 0 || _isPastSelected)
              ? null
              : () => _reset(context, s),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text("Reset today's checks"),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Last 7 days'),
        AppSurface(
          child: hasHistory
              ? Column(
                  children: [
                    for (final d in s.routineHistory)
                      HistoryBar(
                        label: dayLabel(d.day),
                        value: '${d.completed}/${d.total} steps',
                        progress: d.ratio,
                      ),
                  ],
                )
              : const Text(
                  'Your completion history will appear here once you check off steps.',
                  style: AppText.bodyMuted,
                ),
        ),
        const SizedBox(height: 14),
        const InfoNote(
          'A new day starts automatically at midnight and past days stay in your history. '
          'Introduce new skincare products one at a time and stop using a product if it causes irritation.',
          icon: Icons.lightbulb_outline_rounded,
        ),
      ],
    );
  }

  Widget _period(
    BuildContext context,
    AppState s,
    String period,
    String title,
    IconData icon,
  ) {
    if (_isPastSelected) return const SizedBox.shrink();
    final items = s.routine.where((r) => r.period == period).toList();
    final done = items.where((r) => r.done).length;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppText.cardTitle.copyWith(fontSize: 16),
                ),
              ),
              Text('$done/${items.length}', style: AppText.caption),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No steps yet. Add your first step below.',
                style: AppText.bodyMuted,
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _tile(context, s, items[i]),
              if (i < items.length - 1) const Divider(),
            ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isPastSelected
                  ? null
                  : () => _guardedAdd(context, s, period),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Add ${period == 'morning' ? 'morning' : 'evening'} step',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppState s, RoutineItem item) {
    final pending = s.pendingRoutine.contains(item.id);
    return Row(
      children: [
        Builder(
          builder: (boxContext) => Checkbox(
            value: item.done,
            activeColor: AppColors.primary,
            onChanged: (pending || _isPastSelected)
                ? null
                : (v) async {
                    final rect = Celebrate.rectOf(boxContext);
                    final err = await s.setRoutineDone(item, v ?? false);
                    if (err == null &&
                        v == true &&
                        rect != null &&
                        context.mounted) {
                      Celebrate.show(context, rect, message: item.title);
                    }
                    if (err != null && context.mounted) {
                      showSnack(context, err, error: true);
                    }
                  },
          ),
        ),
        Expanded(
          child: Text(
            item.title,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              decoration: item.done ? TextDecoration.lineThrough : null,
              color: item.done ? AppColors.muted : AppColors.deep,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Edit ${item.title}',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _isPastSelected ? null : () => _edit(context, s, item),
        ),
        IconButton(
          tooltip: 'Delete ${item.title}',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _isPastSelected ? null : () => _delete(context, s, item),
        ),
      ],
    );
  }

  Future<void> _guardedAdd(
    BuildContext context,
    AppState s,
    String period,
  ) async {
    if (Session.I.user?.isPremium != true && s.routine.length >= 6) {
      showPremiumDialog(
        context,
        'Premium: the free plan allows up to 6 routine steps. Upgrade for unlimited steps.',
      );
      return;
    }
    await _add(context, s, period);
  }

  Future<void> _add(BuildContext context, AppState s, String period) =>
      showTextPrompt(
        context,
        title: period == 'morning' ? 'Add morning step' : 'Add evening step',
        label: Lang.I.tr('Step name'),
        confirmLabel: 'Add',
        onSubmit: (v) => s.addRoutineItem(period, v),
      );

  Future<void> _edit(BuildContext context, AppState s, RoutineItem item) =>
      showTextPrompt(
        context,
        title: 'Edit step',
        label: Lang.I.tr('Step name'),
        initial: item.title,
        confirmLabel: 'Save',
        onSubmit: (v) => s.editRoutineItem(item, v),
      );

  Future<void> _delete(
    BuildContext context,
    AppState s,
    RoutineItem item,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete step?',
      message: '"${item.title}" and its completion history will be removed.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    final err = await s.deleteRoutineItem(item);
    if (!context.mounted) return;
    showSnack(context, err ?? 'Step deleted', error: err != null);
  }

  Future<void> _reset(BuildContext context, AppState s) async {
    final ok = await confirmDialog(
      context,
      title: "Reset today's checks?",
      message: 'All steps will be marked as not done for today.',
      confirmLabel: 'Reset',
    );
    if (!ok || !context.mounted) return;
    final err = await s.resetRoutineDay();
    if (!context.mounted) return;
    showSnack(context, err ?? "Today's checks were reset", error: err != null);
  }
}