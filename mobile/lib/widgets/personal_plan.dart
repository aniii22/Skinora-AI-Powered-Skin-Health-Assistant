import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../models/models.dart';
import '../screens/skin_profile_screen.dart';
import '../services/routine_engine.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'task_celebration.dart';
import '../utils/format.dart';
import 'daily_thoughts.dart';
import 'premium_star.dart';


class _Kind {
  const _Kind(this.color, this.icon, this.label);
  final Color color;
  final IconData icon;
  final String label;
}

_Kind _kindOf(RoutineStep st) {
  final t = st.title.toLowerCase();
  if (st.isActive) {
    return const _Kind(Color(0xFFD6336C), Icons.science_rounded, 'ACTIVE');
  }
  if (t.contains('water')) {
    return const _Kind(Color(0xFF2F80ED), Icons.water_drop_rounded, 'HYDRATE');
  }
  if (t.contains('cleanse')) {
    return const _Kind(
      Color(0xFF14A89B),
      Icons.bubble_chart_rounded,
      'CLEANSE',
    );
  }
  if (t.contains('under-eye')) {
    return const _Kind(Color(0xFF8E6BBF), Icons.visibility_rounded, 'EYES');
  }
  if (t.contains('serum') ||
      t.contains('vitamin') ||
      t.contains('niacinamide')) {
    return const _Kind(Color(0xFF7C4DFF), Icons.colorize_rounded, 'SERUM');
  }
  if (t.contains('moisturizer')) {
    return const _Kind(Color(0xFFE66BA8), Icons.spa_rounded, 'MOISTURISE');
  }
  if (t.contains('sunscreen')) {
    return const _Kind(Color(0xFFF59E0B), Icons.wb_sunny_rounded, 'PROTECT');
  }
  if (t.contains('mask') || t.contains('exfoliation')) {
    return const _Kind(
      Color(0xFF4CAF50),
      Icons.face_retouching_natural_rounded,
      'MASK',
    );
  }
  if (t.contains('screens') || t.contains('wind down')) {
    return const _Kind(Color(0xFF3F51B5), Icons.bedtime_rounded, 'SLEEP');
  }
  return const _Kind(AppColors.primary, Icons.auto_awesome_rounded, 'CARE');
}

/// Today's routine generated from the saved skin profile, shown as
/// colourful checkbox cards. Ticking a step adds it to the real checklist.
class PersonalPlanCard extends StatefulWidget {
  const PersonalPlanCard({super.key});

  @override
  State<PersonalPlanCard> createState() => _PersonalPlanCardState();
}

class _PersonalPlanCardState extends State<PersonalPlanCard> {
  final Set<String> _local = {}; // day reminders (screen only)
  final Set<String> _pending = {};
  List<RoutineItem> _pastItems = const [];
  bool _pastLoading = false;
  String _pastKey = '';

  @override
  void initState() {
    super.initState();
    selectedRoutineDay.addListener(_dayChanged);
    if (!_isToday(selectedRoutineDay.value)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPast());
    }
  }

  @override
  void dispose() {
    selectedRoutineDay.removeListener(_dayChanged);
    super.dispose();
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  void _dayChanged() {
    if (!mounted) return;
    setState(() {
      _pastItems = const [];
      _pastLoading = false;
      _pastKey = '';
    });
    _loadPast();
  }

  Future<void> _loadPast() async {
    final d = selectedRoutineDay.value;
    if (_isToday(d) || !mounted) return;
    final key = dayKey(d);
    final api = AppScope.read(context).api;
    setState(() {
      _pastLoading = true;
      _pastKey = key;
    });
    try {
      final items = await api.listRoutine(key);
      if (!mounted || _pastKey != key) return;
      setState(() {
        _pastItems = items;
        _pastLoading = false;
      });
    } catch (_) {
      if (!mounted || _pastKey != key) return;
      setState(() {
        _pastItems = const [];
        _pastLoading = false;
      });
    }
  }

  // A step is a Premium step when a free user is at the 3 step limit and
  // this step is not yet in the saved routine.
  bool _needsStar(AppState s, RoutineStep st) =>
      _isToday(selectedRoutineDay.value) &&
      _persist(st) &&
      s.routine.length >= 3 &&
      _find(s, st) == null;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // Unique per step, so two steps with similar names never toggle together.
  String _uid(RoutineStep st) =>
      '${st.period}|${st.order}|${st.title.trim().toLowerCase()}';
  bool _persist(RoutineStep st) => st.period != 'day';

  RoutineItem? _find(AppState s, RoutineStep st) {
    final title = st.title.trim().toLowerCase();
    for (final r in s.routine) {
      if (r.title.trim().toLowerCase() == title) return r;
    }
    return null;
  }

  bool _isDone(AppState s, RoutineStep st) {
    final dv = selectedRoutineDay.value;
    if (!_isToday(dv)) {
      if (!_persist(st)) return false;
      final t = st.title.trim().toLowerCase();
      for (final r in _pastItems) {
        if (r.title.trim().toLowerCase() == t) return r.done;
      }
      return false;
    }
    if (!_persist(st)) return _local.contains(_uid(st));
    return _find(s, st)?.done ?? false;
  }

  void _openProfile() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SkinProfileScreen()));
  }

  Map<String, dynamic> _profileMap(AppState s) {
    final p = s.profile;
    return {
      'skinType': p.skinType,
      'concerns': p.concerns,
      'sensitive': p.sensitive,
    };
  }

  final Map<String, GlobalKey> _keys = {};

  Future<void> _toggle(AppState s, RoutineStep st, bool value) async {
    if (!_isToday(selectedRoutineDay.value)) return;
    final rect = Celebrate.rectOfKey(_keys[_uid(st)]);
    final was = _isDone(s, st);
    await _toggleCore(s, st, value);
    if (value && !was && rect != null && mounted && _isDone(s, st)) {
      Celebrate.show(context, rect, message: st.title);
    }
  }

  Future<void> _toggleCore(AppState s, RoutineStep st, bool value) async {
    final k = _uid(st);
    if (_pending.contains(k)) return;

    if (!_persist(st)) {
      setState(() {
        if (value) {
          _local.add(k);
        } else {
          _local.remove(k);
        }
      });
      return;
    }

    var item = _find(s, st);
    setState(() => _pending.add(k));
    String? err;

    if (item == null) {
      err = await s.addRoutineItem(
        st.period == 'morning' ? 'morning' : 'evening',
        st.title,
      );
      item = _find(s, st);
    }
    if (err == null && item != null && item.done != value) {
      err = await s.setRoutineDone(item, value);
    }
    if (!mounted) return;
    setState(() => _pending.remove(k));
    if (err != null) showSnack(context, err, error: true);
  }

  // ---------- header ----------
  Widget _header(
    AppState s,
    List<RoutineStep> steps,
    Map<String, dynamic> map,
  ) {
    final now = selectedRoutineDay.value;
    
    final thought = dailyThought(now, Lang.I.code);
    final total = steps.length;
    final done = steps.where((x) => _isDone(s, x)).length;
    final value = total == 0 ? 0.0 : done / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deep, AppColors.primary, Color(0xFF7BB661)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_days[now.weekday - 1]}\u2019s glow plan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openProfile,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Edit profile'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            routineSummary(map),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .9),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          // Thought of the day: centered, light background, dark text.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1E3B5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wb_incandescent_rounded,
                      color: Color(0xFFB7791F),
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'THOUGHT OF THE DAY',
                      style: TextStyle(
                        color: Color(0xFFB7791F),
                        fontSize: 11.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  thought,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.deep,
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: .22),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$done / $total done',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- one step card ----------
  Widget _stepCard(AppState s, RoutineStep st) {
    final kind = _kindOf(st);
    final done = _isDone(s, st);
    final busy = _pending.contains(_uid(st));
    final c = kind.color;

    return Padding(
      key: _keys.putIfAbsent(_uid(st), () => GlobalKey()),
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: done ? c.withValues(alpha: .05) : c.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(18),
          onTap: busy ? null : () => _toggle(s, st, !done),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.withValues(alpha: done ? .18 : .35)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.withValues(alpha: .16),
                            ),
                            child: Icon(kind.icon, color: c, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (_needsStar(s, st)) const PremiumStar(size: 18),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        kind.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          letterSpacing: .6,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  st.title,
                                  style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: done
                                        ? AppColors.muted
                                        : AppColors.deep,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(st.detail, style: AppText.caption),
                              ],
                            ),
                          ),
                          busy
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Transform.scale(
                                  scale: 1.2,
                                  child: Builder(builder: (_) => Checkbox(
                                    value: done,
                                    activeColor: c,
                                    shape: const CircleBorder(),
                                    side: BorderSide(color: c, width: 2),
                                    onChanged: (v) =>
                                        _toggle(s, st, v ?? false),
                                  )),
                                ),
                        ],
                      ),
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

  Widget _section(
    AppState s,
    String title,
    IconData icon,
    Color color,
    List<RoutineStep> list,
  ) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final st in list) _stepCard(s, st),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (!s.profile.isSet) {
      return AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Personalise your routine',
                    style: AppText.cardTitle.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your skin type and concerns. Your daily schedule will be built around them.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openProfile,
              icon: const Icon(Icons.face_3_rounded),
              label: const Text('Fill skin profile'),
            ),
          ],
        ),
      );
    }

    final map = _profileMap(s);
    final steps = buildRoutine(map, day: selectedRoutineDay.value);
    final morning = steps.where((x) => x.period == 'morning').toList();
    final day = steps.where((x) => x.period == 'day').toList();
    final night = steps.where((x) => x.period == 'night').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(s, steps, map),
        if (!_isToday(selectedRoutineDay.value))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _pastLoading
                  ? 'Loading this day...'
                  : 'Viewing ${dayKey(selectedRoutineDay.value)} (read only)',
              style: AppText.caption,
            ),
          ),
        _section(
          s,
          'Morning',
          Icons.wb_sunny_rounded,
          const Color(0xFFF59E0B),
          morning,
        ),
        _section(
          s,
          'During the day',
          Icons.water_drop_rounded,
          const Color(0xFF2F80ED),
          day,
        ),
        _section(
          s,
          'Night',
          Icons.nights_stay_rounded,
          const Color(0xFF3F51B5),
          night,
        ),
        const SizedBox(height: 6),
        const Text(
          'Suggestions only, not medical advice. Patch test new products. Actives appear only on set nights and are skipped for sensitive skin.',
          style: AppText.caption,
        ),
      ],
    );
  }
}
