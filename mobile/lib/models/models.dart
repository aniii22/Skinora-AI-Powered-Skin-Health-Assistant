const Map<String, String> skinTypes = {
  'normal': 'Normal',
  'oily': 'Oily',
  'dry': 'Dry',
  'combination': 'Combination',
  'not_sure': 'Not sure',
};

const Map<String, String> skinConcerns = {
  'acne': 'Acne',
  'dark_spots': 'Dark spots',
  'dryness': 'Dryness',
  'oiliness': 'Oiliness',
  'redness': 'Redness',
  'uneven_tone': 'Uneven skin tone',
  'dullness': 'Dullness',
  'dehydrated': 'Dehydrated',
  'large_pores': 'Large pores',
  'dark_circles': 'Dark circles',
  'acne_scars': 'Acne scars',
  'fine_lines': 'Fine lines',
};

DateTime _day(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

class SkinProfile {
  const SkinProfile({
    required this.displayName,
    required this.skinType,
    required this.concerns,
    required this.sensitive,
    this.gender = '',
  });

  final String displayName;
  final String skinType;
  final List<String> concerns;
  final bool sensitive;
  final String gender; // 'male' | 'female' | ''

  static const empty = SkinProfile(
    displayName: '',
    skinType: '',
    concerns: [],
    sensitive: false,
  );
  bool get isSet => skinType.isNotEmpty;

  factory SkinProfile.fromJson(Map<String, dynamic> j) => SkinProfile(
    displayName: j['display_name'] as String? ?? '',
    skinType: j['skin_type'] as String? ?? '',
    concerns: ((j['concerns'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    sensitive: j['sensitive'] as bool? ?? false,
    gender: j['gender'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'skin_type': skinType,
    'concerns': concerns,
    'sensitive': sensitive,
    'gender': gender,
  };
}

class WaterSettings {
  const WaterSettings({required this.goalMl, required this.glassMl});
  final int goalMl;
  final int glassMl;
  static const defaults = WaterSettings(goalMl: 2000, glassMl: 250);

  factory WaterSettings.fromJson(Map<String, dynamic> j) => WaterSettings(
    goalMl: (j['water_goal_ml'] as num).toInt(),
    glassMl: (j['glass_ml'] as num).toInt(),
  );
}

class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.period,
    required this.title,
    required this.done,
  });
  final int id;
  final String period; // 'morning' | 'evening'
  final String title;
  final bool done;

  factory RoutineItem.fromJson(Map<String, dynamic> j) => RoutineItem(
    id: (j['id'] as num).toInt(),
    period: j['period'] as String,
    title: j['title'] as String,
    done: j['done'] as bool? ?? false,
  );
}

class RoutineDay {
  const RoutineDay({
    required this.day,
    required this.completed,
    required this.total,
  });
  final DateTime day;
  final int completed;
  final int total;
  double get ratio => total == 0 ? 0 : (completed / total).clamp(0.0, 1.0);

  factory RoutineDay.fromJson(Map<String, dynamic> j) => RoutineDay(
    day: _day(j['day'] as String),
    completed: (j['completed'] as num).toInt(),
    total: (j['total'] as num).toInt(),
  );
}

class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.amountMl,
    required this.createdAt,
  });
  final int id;
  final int amountMl;
  final DateTime createdAt;

  factory WaterEntry.fromJson(Map<String, dynamic> j) => WaterEntry(
    id: (j['id'] as num).toInt(),
    amountMl: (j['amount_ml'] as num).toInt(),
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );
}

class WaterSummary {
  const WaterSummary({
    required this.totalMl,
    required this.goalMl,
    required this.glassMl,
    required this.entries,
  });
  final int totalMl;
  final int goalMl;
  final int glassMl;
  final List<WaterEntry> entries;

  double get progress => goalMl == 0 ? 0 : (totalMl / goalMl).clamp(0.0, 1.0);
  bool get goalReached => totalMl >= goalMl;

  factory WaterSummary.fromJson(Map<String, dynamic> j) => WaterSummary(
    totalMl: (j['total_ml'] as num).toInt(),
    goalMl: (j['goal_ml'] as num).toInt(),
    glassMl: (j['glass_ml'] as num).toInt(),
    entries: ((j['entries'] as List?) ?? const [])
        .map((e) => WaterEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class WaterDay {
  const WaterDay({required this.day, required this.totalMl});
  final DateTime day;
  final int totalMl;

  factory WaterDay.fromJson(Map<String, dynamic> j) => WaterDay(
    day: _day(j['day'] as String),
    totalMl: (j['total_ml'] as num).toInt(),
  );
}

class SleepLog {
  const SleepLog({
    required this.id,
    required this.start,
    required this.wake,
    required this.durationMin,
  });
  final int id;
  final DateTime start;
  final DateTime wake;
  final int durationMin;

  factory SleepLog.fromJson(Map<String, dynamic> j) => SleepLog(
    id: (j['id'] as num).toInt(),
    start: DateTime.parse(j['sleep_start'] as String).toLocal(),
    wake: DateTime.parse(j['wake_time'] as String).toLocal(),
    durationMin: (j['duration_min'] as num).toInt(),
  );
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.day,
    required this.notes,
    required this.rating,
    required this.hasPhoto,
    required this.photoVersion,
  });
  final int id;
  final DateTime day;
  final String notes;
  final int? rating;
  final bool hasPhoto;
  final int photoVersion;

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
    id: (j['id'] as num).toInt(),
    day: _day(j['day'] as String),
    notes: j['notes'] as String? ?? '',
    rating: (j['rating'] as num?)?.toInt(),
    hasPhoto: j['has_photo'] as bool? ?? false,
    photoVersion: (j['photo_v'] as num?)?.toInt() ?? 0,
  );
}

class Insights {
  const Insights({
    required this.days,
    required this.routine,
    required this.water,
    required this.waterGoalMl,
    required this.sleepCount,
    required this.sleepAvgMinutes,
    required this.journalCount,
    required this.journalAvgRating,
  });
  final int days;
  final List<RoutineDay> routine;
  final List<WaterDay> water;
  final int waterGoalMl;
  final int sleepCount;
  final double sleepAvgMinutes;
  final int journalCount;
  final double? journalAvgRating;

  factory Insights.fromJson(Map<String, dynamic> j) {
    final sleep = j['sleep'] as Map<String, dynamic>;
    final journal = j['journal'] as Map<String, dynamic>;
    return Insights(
      days: (j['days'] as num).toInt(),
      routine: (j['routine'] as List)
          .map((e) => RoutineDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      water: (j['water'] as List)
          .map((e) => WaterDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      waterGoalMl: (j['water_goal_ml'] as num).toInt(),
      sleepCount: (sleep['count'] as num).toInt(),
      sleepAvgMinutes: (sleep['avg_minutes'] as num).toDouble(),
      journalCount: (journal['count'] as num).toInt(),
      journalAvgRating: (journal['avg_rating'] as num?)?.toDouble(),
    );
  }
}
