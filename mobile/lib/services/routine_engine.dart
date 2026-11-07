class RoutineStep {
  const RoutineStep({
    required this.order,
    required this.period,
    required this.title,
    required this.detail,
    required this.icon,
    this.isActive = false,
  });

  final int order; // minutes from midnight (night steps may exceed 1440)
  final String period; // morning | day | night
  final String title;
  final String detail;
  final String icon; // water, face, sun, moon, spa, sleep
  final bool isActive; // true for actives like retinol / salicylic acid

  String get time {
    final m = ((order % 1440) + 1440) % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }
}

String _first(Map<String, dynamic> p, List<String> keys) {
  for (final k in keys) {
    final v = p[k];
    if (v == null || v is List) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s.toLowerCase();
  }
  return '';
}

List<String> _list(Map<String, dynamic> p, List<String> keys) {
  for (final k in keys) {
    final v = p[k];
    if (v is List && v.isNotEmpty) {
      return v.map((e) => e.toString().trim().toLowerCase()).toList();
    }
    if (v is String && v.trim().isNotEmpty) {
      return v
          .split(RegExp(r'[,;|]'))
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  return [];
}

int _mins(String s, int fallback) {
  final m = RegExp(
    r'(\d{1,2}):(\d{2})\s*(am|pm)?',
    caseSensitive: false,
  ).firstMatch(s);
  if (m == null) return fallback;
  var h = int.parse(m.group(1)!);
  final mi = int.parse(m.group(2)!);
  final ap = m.group(3)?.toLowerCase();
  if (ap == 'pm' && h < 12) h += 12;
  if (ap == 'am' && h == 12) h = 0;
  return h * 60 + mi;
}

/// Builds a day's routine from the saved skin profile map.
/// Reads keys tolerantly: skinType/skin_type, concerns/skinConcerns,
/// sensitivity, age, sunExposure, wakeTime, sleepTime.
List<RoutineStep> buildRoutine(Map<String, dynamic> profile, {DateTime? day}) {
  final d = day ?? DateTime.now();
  final skin = _first(profile, ['skinType', 'skin_type', 'type']);
  final concerns = _list(profile, [
    'concerns',
    'skinConcerns',
    'skin_concerns',
    'concern',
  ]);
  final sens = _first(profile, ['sensitivity', 'sensitive']);
  final age = int.tryParse(_first(profile, ['age'])) ?? 25;
  final sun = _first(profile, ['sunExposure', 'sun_exposure']);
  final wake = _mins(_first(profile, ['wakeTime', 'wake_time', 'wakeUp']), 420);
  var sleep = _mins(
    _first(profile, ['sleepTime', 'sleep_time', 'bedTime', 'bedtime']),
    1380,
  );
  if (sleep < wake) sleep += 1440;

  bool has(List<String> words) =>
      concerns.any((c) => words.any((w) => c.replaceAll('_', ' ').contains(w)));

  final oily = skin.contains('oily');
  final dry = skin.contains('dry');
  final sensitive =
      skin.contains('sensitive') ||
      sens.contains('high') ||
      sens == 'yes' ||
      sens == 'true';
  final highSun = sun.contains('high') || sun.contains('outdoor');

  final acne = has(['acne', 'pimple', 'breakout', 'pore', 'oilin']) || oily;
  final aging = has(['aging', 'wrinkle', 'fine line']);
  final pigment = has(['pigment', 'dark spot', 'tan', 'dull', 'uneven']);
  final dryness = has(['dry', 'flaky', 'tight']) || dry;
  final darkCircles = has(['dark circle', 'puffy']);
  final redness = has(['redness']);

  final wd = d.weekday; // 1 = Mon ... 7 = Sun
  final retinolNight =
      !sensitive && age >= 18 && (aging || pigment) && (wd == 2 || wd == 5);
  final acidNight = !sensitive && age >= 13 && acne && (wd == 1 || wd == 4);
  final sunday = wd == 7;

  final steps = <RoutineStep>[];

  // ---------- Morning ----------
  steps.add(
    RoutineStep(
      order: wake,
      period: 'morning',
      title: 'Wake up: 1 glass water',
      detail: 'Rehydrate before anything else. Skin shows dehydration first.',
      icon: 'water',
    ),
  );

  steps.add(
    RoutineStep(
      order: wake + 10,
      period: 'morning',
      title: 'Cleanse',
      detail: sensitive
          ? 'Fragrance-free, gentle cleanser with lukewarm water. No scrubbing.'
          : oily
          ? 'Gel or foaming cleanser to control oil. 30 to 60 seconds.'
          : dry
          ? 'Creamy hydrating cleanser, or just water if skin feels tight.'
          : 'Mild gel cleanser, lukewarm water.',
      icon: 'face',
    ),
  );

  if (pigment || aging) {
    steps.add(
      RoutineStep(
        order: wake + 15,
        period: 'morning',
        title: 'Vitamin C serum',
        detail: 'Brightens and protects against sun damage. Start every other day if skin stings.',
        icon: 'spa',
      ),
    );
  } else if (acne || redness) {
    steps.add(
      RoutineStep(
        order: wake + 15,
        period: 'morning',
        title: 'Niacinamide serum',
        detail: 'Helps with oil balance, pores and redness.',
        icon: 'spa',
      ),
    );
  } else if (dryness) {
    steps.add(
      RoutineStep(
        order: wake + 15,
        period: 'morning',
        title: 'Hyaluronic acid serum',
        detail: 'Apply on slightly damp skin, then seal with moisturizer.',
        icon: 'spa',
      ),
    );
  }

  if (darkCircles) {
    steps.add(
      RoutineStep(
        order: wake + 18,
        period: 'morning',
        title: 'Under-eye care',
        detail: 'Light caffeine or peptide eye cream. Pat gently, do not rub.',
        icon: 'spa',
      ),
    );
  }

  steps.add(
    RoutineStep(
      order: wake + 20,
      period: 'morning',
      title: 'Moisturizer',
      detail: oily
          ? 'Light gel, oil-free moisturizer.'
          : dry
          ? 'Rich cream with ceramides.'
          : 'Lightweight lotion or gel-cream.',
      icon: 'face',
    ),
  );

  steps.add(
    RoutineStep(
      order: wake + 25,
      period: 'morning',
      title: highSun ? 'Sunscreen SPF 50' : 'Sunscreen SPF 30+',
      detail: 'Two finger lengths for face and neck. Reapply every 3 to 4 hours if outdoors.',
      icon: 'sun',
    ),
  );

  // ---------- Day ----------
  steps.add(
    RoutineStep(
      order: wake + 300,
      period: 'day',
      title: 'Midday water check',
      detail: 'Aim for steady sipping through the day, not all at once.',
      icon: 'water',
    ),
  );
  steps.add(
    RoutineStep(
      order: wake + 600,
      period: 'day',
      title: highSun ? 'Sunscreen reapply' : 'Afternoon water check',
      detail: highSun
          ? 'Reapply SPF on face, neck and hands.'
          : 'Keep your glass near you.',
      icon: highSun ? 'sun' : 'water',
    ),
  );

  // ---------- Night ----------
  steps.add(
    RoutineStep(
      order: sleep - 60,
      period: 'night',
      title: 'Cleanse (double cleanse if sunscreen or makeup)',
      detail:
          'Oil or balm first to remove sunscreen, then your normal cleanser.',
      icon: 'face',
    ),
  );

  if (retinolNight) {
    steps.add(
      RoutineStep(
        order: sleep - 50,
        period: 'night',
        title: 'Retinol (tonight)',
        detail: 'Pea-sized amount on dry skin. Tonight and 2 nights a week only. Always use sunscreen next morning.',
        icon: 'moon',
        isActive: true,
      ),
    );
  } else if (acidNight) {
    steps.add(
      RoutineStep(
        order: sleep - 50,
        period: 'night',
        title: 'Salicylic acid (tonight)',
        detail: '2% on breakout-prone areas. Tonight and 2 nights a week only. Stop if skin burns or peels.',
        icon: 'moon',
        isActive: true,
      ),
    );
  } else if (sunday) {
    steps.add(
      RoutineStep(
        order: sleep - 50,
        period: 'night',
        title: sensitive
            ? 'Soothing mask'
            : 'Weekly mask or gentle exfoliation',
        detail: sensitive
            ? 'Aloe or oat based mask, 10 minutes. No exfoliation.'
            : 'Clay mask for oily, hydrating mask for dry. 10 minutes, then rinse.',
        icon: 'spa',
      ),
    );
  } else {
    steps.add(
      RoutineStep(
        order: sleep - 50,
        period: 'night',
        title: 'Recovery night: serum only',
        detail: 'No actives tonight. Use hydrating or barrier-repair serum.',
        icon: 'spa',
      ),
    );
  }

  steps.add(
    RoutineStep(
      order: sleep - 40,
      period: 'night',
      title: 'Night moisturizer',
      detail: dry || sensitive
          ? 'Rich barrier cream. Apply a little extra on dry patches.'
          : 'Light moisturizer to lock in hydration.',
      icon: 'face',
    ),
  );

  steps.add(
    RoutineStep(
      order: sleep - 15,
      period: 'night',
      title: 'Screens off, wind down',
      detail: 'Aim for 7 to 8 hours of sleep. Sleep is when skin repairs.',
      icon: 'sleep',
    ),
  );

  steps.sort((a, b) => a.order.compareTo(b.order));
  return steps;
}

/// Short line explaining why this routine was chosen.
String routineSummary(Map<String, dynamic> profile) {
  final skin = _first(profile, ['skinType', 'skin_type', 'type']);
  final concerns = _list(profile, [
    'concerns',
    'skinConcerns',
    'skin_concerns',
    'concern',
  ]);
  final parts = <String>[];
  if (skin.isNotEmpty) parts.add('$skin skin');
  if (concerns.isNotEmpty) parts.add(concerns.join(', '));
  return parts.isEmpty
      ? 'Fill your Skin Profile to personalise this routine.'
      : 'Personalised for: ${parts.join(' | ')}';
}
