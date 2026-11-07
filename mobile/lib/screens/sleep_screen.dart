import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

const int kSleepGoalMin = 480;
const _good = Color(0xFF2E9E5B);
const _warn = Color(0xFFE8B008);
const _bad = Color(0xFFE5484D);
List<String> get _wd => weekdayNames();

Color _sleepColor(int min) =>
    min >= kSleepGoalMin ? _good : (min >= 360 ? _warn : _bad);

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

class _SleepStats {
  _SleepStats(List<SleepLog> logs) {
    final now = DateTime.now();
    final today = _d(now);
    for (final l in logs) {
      final k = _d(l.wake);
      byDay[k] = (byDay[k] ?? 0) + l.durationMin;
    }
    for (var i = 6; i >= 0; i--) {
      days.add(DateTime(today.year, today.month, today.day - i));
    }
    todayMin = byDay[today] ?? 0;
    final logged = [
      for (final d in days)
        if (byDay.containsKey(d)) byDay[d]!,
    ];
    loggedDays = logged.length;
    avg = logged.isEmpty
        ? 0
        : (logged.fold<int>(0, (a, b) => a + b) / logged.length).round();
    debt = logged.fold<int>(
      0,
      (a, b) => a + (b < kSleepGoalMin ? kSleepGoalMin - b : 0),
    );

    var d = byDay.containsKey(today)
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    while ((byDay[d] ?? 0) >= kSleepGoalMin && streak < 365) {
      streak++;
      d = DateTime(d.year, d.month, d.day - 1);
    }

    final first = days.first;
    final beds = <int>[];
    for (final l in logs) {
      if (_d(l.wake).isBefore(first)) continue;
      var m = l.start.hour * 60 + l.start.minute;
      if (m < 720) m += 1440;
      beds.add(m);
    }
    bedCount = beds.length;
    if (beds.length >= 3) {
      final sorted = [...beds]..sort();
      final med = sorted[sorted.length ~/ 2];
      steady = beds.where((m) => (m - med).abs() <= 45).length;
    }
  }

  final Map<DateTime, int> byDay = {};
  final List<DateTime> days = [];
  int todayMin = 0, avg = 0, debt = 0, streak = 0, loggedDays = 0;
  int steady = 0, bedCount = 0;
}

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep tracker')),
      body: ResponsivePage(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              eyebrow: 'REST & RECOVERY',
              title: 'Sleep log',
              subtitle: 'Enter your bedtime and wake-up time yourself. Skinora does not measure sleep automatically.',
            ),
            LoadGate(state: s, builder: () => _content(context, s)),
          ],
        ),
      ),
    );
  }

  String _tip(_SleepStats st) {
    if (st.todayMin == 0) {
      return 'Log last night\u2019s sleep to see how you did against your 8h goal.';
    }
    if (st.todayMin >= kSleepGoalMin) {
      return 'Goal complete. Rest is when your skin renews itself, so keep this rhythm going.';
    }
    if (st.todayMin >= 360) {
      return 'A little short of 8h. Try going to bed 30 minutes earlier tonight.';
    }
    return 'Low sleep can show up as dull skin and dark circles. Aim for an early night and keep screens away before bed.';
  }

  Widget _ring(_SleepStats st) {
    final v = (st.todayMin / kSleepGoalMin).clamp(0.0, 1.0).toDouble();
    final c = st.todayMin == 0 ? AppColors.muted : _sleepColor(st.todayMin);
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 10,
              backgroundColor: c.withValues(alpha: .15),
              color: c,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                st.todayMin == 0 ? '-' : formatMinutes(st.todayMin),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text('of 8h', style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(_SleepStats st, DateTime d) {
    const maxMin = 600.0;
    const h = 110.0;
    final min = st.byDay[d] ?? 0;
    final bh = (min / maxMin * h).clamp(min > 0 ? 4.0 : 0.0, h).toDouble();
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 12,
            child: Text(
              min > 0 ? (min / 60).toStringAsFixed(1) : '',
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 18,
            height: bh,
            decoration: BoxDecoration(
              color: min == 0 ? Colors.transparent : _sleepColor(min),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _wd[d.weekday - 1],
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String title, String text) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(title, style: AppText.cardTitle),
            const SizedBox(height: 2),
            Text(text, style: AppText.caption),
          ],
        ),
      );

  Widget _content(BuildContext context, AppState s) {
    final st = _SleepStats(s.sleep);
    final logs = [...s.sleep]..sort((a, b) => b.wake.compareTo(a.wake));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: () => openScreen(context, const SleepEditorScreen()),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Log sleep'),
        ),
        const SizedBox(height: 18),
        if (s.sleep.isEmpty)
          const EmptyState(
            icon: Icons.nightlight_round,
            title: 'No sleep logged yet',
            message: 'Add your first entry to start building a sleep history.',
          )
        else ...[
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ring(st),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Last night', style: AppText.cardTitle),
                          const SizedBox(height: 6),
                          Text(
                            st.todayMin == 0
                                ? 'Nothing logged for today yet.'
                                : st.todayMin >= kSleepGoalMin
                                ? 'Goal complete'
                                : '${formatMinutes(kSleepGoalMin - st.todayMin)} short of your 8h goal',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: st.todayMin == 0
                                  ? AppColors.muted
                                  : _sleepColor(st.todayMin),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(_tip(st), style: AppText.body),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Last 7 days', style: AppText.cardTitle),
                const SizedBox(height: 12),
                SizedBox(
                  height: 144,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18 + 110 * kSleepGoalMin / 600,
                        child: Container(
                          height: 1,
                          color: AppColors.muted.withValues(alpha: .5),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [for (final d in st.days) _bar(st, d)],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Line = 8h goal. Green: goal met. Gold: a bit short. Red: well short.',
                  style: AppText.caption,
                ),
                const SizedBox(height: 14),
                Text(
                  st.loggedDays == 0
                      ? 'No sleep logged in the last 7 days.'
                      : 'Average ${formatMinutes(st.avg)} per night over ${st.loggedDays} logged ${st.loggedDays == 1 ? 'night' : 'nights'}.',
                  style: AppText.body,
                ),
                if (st.loggedDays > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    st.debt == 0
                        ? 'No sleep debt this week. Nice work.'
                        : 'This week you are ${formatMinutes(st.debt)} short of your goal.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: st.debt == 0 ? _good : _warn,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppSurface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stat(
                  Icons.local_fire_department_rounded,
                  st.streak > 0 ? _warn : AppColors.muted,
                  st.streak == 0
                      ? 'No streak yet'
                      : '${st.streak} ${st.streak == 1 ? 'day' : 'days'} streak',
                  'Nights in a row with 8h or more.',
                ),
                const SizedBox(width: 14),
                _stat(
                  Icons.schedule_rounded,
                  AppColors.sleep,
                  st.bedCount < 3
                      ? 'Bedtime'
                      : '${st.steady} of ${st.bedCount} steady',
                  st.bedCount < 3
                      ? 'Log 3 nights to see how steady your bedtime is.'
                      : 'Nights you went to bed at nearly the same time.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('History'),
          for (final log in logs) ...[
            _SleepTile(log: log),
            const SizedBox(height: 10),
          ],
          const InfoNote(
            'These are general wellness tips, not medical advice. If you often feel very tired, talk to a doctor.',
          ),
        ],
      ],
    );
  }
}

class _SleepTile extends StatelessWidget {
  const _SleepTile({required this.log});
  final SleepLog log;

  String _t(BuildContext c, DateTime d) => TimeOfDay.fromDateTime(d).format(c);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final met = log.durationMin >= kSleepGoalMin;
    final c = _sleepColor(log.durationMin);
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prettyDate(log.wake), style: AppText.cardTitle),
                const SizedBox(height: 3),
                Text(
                  '${_t(context, log.start)} \u2192 ${_t(context, log.wake)}',
                  style: AppText.caption,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    met
                        ? 'Goal met'
                        : '${formatMinutes(kSleepGoalMin - log.durationMin)} short',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: c,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMinutes(log.durationMin),
            style: AppText.cardTitle.copyWith(color: AppColors.sleep),
          ),
          IconButton(
            tooltip: 'Edit sleep entry for ${prettyDate(log.wake)}',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                openScreen(context, SleepEditorScreen(existing: log)),
          ),
          IconButton(
            tooltip: 'Delete sleep entry for ${prettyDate(log.wake)}',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete sleep entry?',
                message: 'This entry will be removed permanently.',
                confirmLabel: 'Delete',
              );
              if (!ok || !context.mounted) return;
              final err = await s.deleteSleep(log.id);
              if (!context.mounted) return;
              showSnack(
                context,
                err ?? 'Sleep entry deleted',
                error: err != null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class SleepEditorScreen extends StatefulWidget {
  const SleepEditorScreen({super.key, this.existing});
  final SleepLog? existing;

  @override
  State<SleepEditorScreen> createState() => _SleepEditorScreenState();
}

class _SleepEditorScreenState extends State<SleepEditorScreen> {
  late DateTime _bed;
  late DateTime _wake;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _bed = e.start;
      _wake = e.wake;
    } else {
      final now = DateTime.now();
      var wake = DateTime(now.year, now.month, now.day, 7);
      if (wake.isAfter(now)) {
        wake = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      }
      _wake = wake;
      _bed = wake.subtract(const Duration(hours: 8));
    }
  }

  String? _validate() {
    if (!_wake.isAfter(_bed)) return 'Wake-up time must be after bedtime.';
    if (_wake.difference(_bed) > const Duration(hours: 24)) {
      return 'A sleep entry cannot be longer than 24 hours.';
    }
    if (_wake.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return 'Wake-up time cannot be in the future.';
    }
    return null;
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AppScope.read(context)
        .saveSleep(id: widget.existing?.id, start: _bed, wake: _wake);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    showSnack(context, 'Sleep entry saved');
    Navigator.of(context).pop();
  }

  Widget _picker(
    String label,
    DateTime value,
    ValueChanged<DateTime> onPicked,
  ) {
    return AppSurface(
      onTap: _busy
          ? null
          : () async {
              final picked = await _pick(value);
              if (picked != null && mounted) {
                setState(() {
                  onPicked(picked);
                  _error = null;
                });
              }
            },
      child: Row(
        children: [
          const Icon(Icons.event_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption),
                const SizedBox(height: 2),
                Text(
                  '${prettyDateYear(value)} \u00B7 ${TimeOfDay.fromDateTime(value).format(context)}',
                  style: AppText.cardTitle,
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_calendar_outlined, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _feedback(int diff) {
    if (diff <= 0) return const SizedBox.shrink();
    final c = _sleepColor(diff);
    final String msg;
    final IconData icon;
    if (diff > 600) {
      msg = 'Longer than usual. Oversleeping can leave you feeling tired too.';
      icon = Icons.info_outline_rounded;
    } else if (diff >= kSleepGoalMin) {
      msg =
          'Goal complete. Your skin renews itself while you sleep, great job.';
      icon = Icons.check_circle_rounded;
    } else {
      final short = kSleepGoalMin - diff;
      msg =
          '${formatMinutes(short)} short of your 8h goal. Try going to bed ${formatMinutes(short)} earlier.';
      icon = Icons.nightlight_round;
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (diff > 600 ? AppColors.muted : c).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: diff > 600 ? AppColors.muted : c, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diff = _wake.difference(_bed).inMinutes;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Log sleep' : 'Edit sleep entry'),
      ),
      body: ResponsivePage(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _picker('Went to bed', _bed, (v) => _bed = v),
            const SizedBox(height: 12),
            _picker('Woke up', _wake, (v) => _wake = v),
            const SizedBox(height: 16),
            Text(
              diff > 0
                  ? 'Duration: ${formatMinutes(diff)}'
                  : 'Duration: not valid yet',
              style: AppText.cardTitle.copyWith(
                color: diff > 0 ? _sleepColor(diff) : AppColors.danger,
              ),
            ),
            _feedback(diff),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save entry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
