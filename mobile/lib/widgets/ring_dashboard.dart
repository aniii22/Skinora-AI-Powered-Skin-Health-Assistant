import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'task_celebration.dart';
import 'premium_star.dart';
import '../auth/session.dart';
import '../auth/premium_screen.dart' show showPremiumDialog;
import 'daily_thoughts.dart';

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track);
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(r, 0, math.pi * 2, false, bg);
    if (value > 0) {
      canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0.0, 1.0),
        false,
        fg,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Pops the party popper over a ring when it reaches 100% while the Home page
/// is visible. It pops once, and again only after the ring drops below 100%.
class _RingPop extends StatefulWidget {
  const _RingPop({required this.id, required this.value, required this.child});
  final String? id;
  final double? value;
  final Widget child;

  static final Map<String, bool> _shown = {};

  @override
  State<_RingPop> createState() => _RingPopState();
}

class _RingPopState extends State<_RingPop> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _check();
  }

  @override
  void didUpdateWidget(_RingPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _check();
  }

  void _check() {
    final id = widget.id;
    final v = widget.value;
    if (id == null || v == null) return;
    if (v < 1.0) {
      _RingPop._shown[id] = false;
      return;
    }
    if (_RingPop._shown[id] == true) return;
    final route = ModalRoute.of(context);
    final visible =
        (route?.isCurrent ?? true) && TickerMode.valuesOf(context).enabled;
    if (!visible) return;
    _RingPop._shown[id] = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rect = Celebrate.rectOf(context);
      if (rect != null) Celebrate.showAtRect(context, rect, size: 60);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Clickable dashboard card. Shows a progress ring when [value] is given,
/// otherwise the [icon] inside a soft ring. Must be placed inside a Row.
class DashTile extends StatelessWidget {
  const DashTile({
    super.key,
    this.value,
    required this.color,
    required this.track,
    required this.title,
    required this.caption,
    required this.icon,
    this.onTap,
    this.celebrateId,
    this.premiumFeature = false,
  });
  final double? value;
  final Color color;
  final Color track;
  final String title;
  final String caption;
  final IconData icon;
  final VoidCallback? onTap;
  final String? celebrateId;
  final bool premiumFeature;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kRadius);
    final v = value;
    return Expanded(
      child: Semantics(
        button: onTap != null,
        label: '$title. $caption',
        child: ExcludeSemantics(
          child: Material(
            color: Colors.white,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              mouseCursor: onTap == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: PremiumCorner(
                show: premiumFeature,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _RingPop(
                        id: celebrateId,
                        value: v,
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: CustomPaint(
                            painter: _RingPainter(v ?? 0, color, track),
                            child: Center(
                              child: v != null
                                  ? Text(
                                      '${(v.clamp(0.0, 1.0) * 100).round()}%',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    )
                                  : Icon(icon, color: color, size: 28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 14, color: color),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.cardTitle.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(fontSize: 11.5),
                      ),
                    ],
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

/// Three progress rings: routine, water, sleep (today). Each one is tappable.
class RingDashboard extends StatelessWidget {
  const RingDashboard({super.key, this.onRoutine, this.onWater, this.onSleep});
  final VoidCallback? onRoutine;
  final VoidCallback? onWater;
  final VoidCallback? onSleep;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final total = s.routine.length;
    final done = s.routine.where((r) => r.done).length;
    final routineV = total == 0 ? 0.0 : done / total;

    final w = s.water;
    final waterV = w == null ? 0.0 : w.progress.toDouble();
    final waterCap = w == null
        ? '-'
        : '${w.totalMl > 5000 ? 5000 : w.totalMl}/${w.goalMl} ml';

    final sleepNow = DateTime.now();
    final todaySleep = s.sleep
        .where(
          (e) =>
              e.wake.year == sleepNow.year &&
              e.wake.month == sleepNow.month &&
              e.wake.day == sleepNow.day,
        )
        .toList();
    final hasSleep = todaySleep.isNotEmpty;
    final sleepMin = hasSleep ? todaySleep.first.durationMin : 0;
    final sleepV = sleepMin / 480.0;
    final sleepCap = hasSleep ? formatMinutes(sleepMin) : 'No entry';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashTile(
          celebrateId: 'routine',
          value: routineV,
          color: AppColors.primary,
          track: AppColors.lavender,
          title: 'Routine',
          caption: '$done of $total',
          icon: Icons.checklist_rounded,
          onTap: onRoutine,
        ),
        const SizedBox(width: 10),
        DashTile(
          celebrateId: 'water',
          value: waterV,
          color: AppColors.water,
          track: AppColors.waterSoft,
          title: 'Water',
          caption: waterCap,
          icon: Icons.water_drop_rounded,
          onTap: onWater,
        ),
        const SizedBox(width: 10),
        DashTile(
          celebrateId: 'sleep',
          value: sleepV,
          color: AppColors.sleep,
          track: AppColors.panel,
          title: 'Sleep',
          caption: sleepCap,
          icon: Icons.nightlight_round,
          onTap: onSleep,
        ),
      ],
    );
  }
}

/// Monday-Sunday strip. Tap a day to see its plan, checks and thought.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key});

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  static bool _future(DateTime d) => _d(d).isAfter(_d(DateTime.now()));

  static bool _locked(DateTime d) {
    if (Session.I.user?.isPremium == true) return false;
    return _d(DateTime.now()).difference(_d(d)).inDays > 1;
  }

  void _pick(BuildContext context, DateTime d) {
    if (_future(d)) return;
    if (_locked(d)) {
      showPremiumDialog(
        context,
        'Premium: the free plan shows only the last 2 days of history. Upgrade to see your full history.',
      );
      return;
    }
    selectedRoutineDay.value = _d(d);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = _d(now).subtract(Duration(days: now.weekday - 1));
    final names = weekdayNames();
    return ListenableBuilder(
      listenable: Listenable.merge([selectedRoutineDay, Session.I]),
      builder: (context, _) {
        final sel = _future(selectedRoutineDay.value)
            ? _d(DateTime.now())
            : selectedRoutineDay.value;
        return Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              Expanded(
                child: _day(
                  context,
                  monday.add(Duration(days: i)),
                  names[i],
                  now,
                  sel,
                ),
              ),
              if (i < 6) const SizedBox(width: 6),
            ],
          ],
        );
      },
    );
  }

  Widget _day(
    BuildContext context,
    DateTime d,
    String name,
    DateTime now,
    DateTime sel,
  ) {
    final isToday = _d(d) == _d(now);
    final selected = _d(d) == _d(sel);
    final locked = _locked(d);
    final radius = BorderRadius.circular(16);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            mouseCursor: SystemMouseCursors.click,
            onTap: _future(d) ? null : () => _pick(context, d),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : (isToday
                            ? AppColors.primary.withValues(alpha: .5)
                            : AppColors.border),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white.withValues(alpha: .85)
                          : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? Colors.white
                          : (_future(d)
                                ? AppColors.muted.withValues(alpha: .45)
                                : AppColors.deep),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (locked)
          const Positioned(
            top: -5,
            right: -3,
            child: IgnorePointer(child: PremiumStar(size: 14)),
          ),
      ],
    );
  }
}
