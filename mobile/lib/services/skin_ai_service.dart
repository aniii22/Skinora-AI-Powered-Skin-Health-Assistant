import 'package:image_picker/image_picker.dart';

import 'api_client.dart';

List<String> _strs(dynamic v) => v is List
    ? v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList()
    : <String>[];

String _str(dynamic v) => (v ?? '').toString();

class ScanProduct {
  ScanProduct({
    required this.type,
    required this.keyIngredients,
    required this.why,
    required this.usage,
  });

  final String type;
  final List<String> keyIngredients;
  final String why;
  final String usage;

  factory ScanProduct.fromJson(Map<String, dynamic> j) => ScanProduct(
    type: _str(j['type']),
    keyIngredients: _strs(j['key_ingredients']),
    why: _str(j['why']),
    usage: _str(j['usage']),
  );
}

class SkinScanResult {
  SkinScanResult({
    required this.observations,
    required this.confidence,
    required this.summary,
    required this.concerns,
    required this.possibleCauses,
    required this.recommendations,
    required this.routineMorning,
    required this.routineEvening,
    required this.lifestyle,
    required this.products,
    required this.avoid,
    required this.seeDoctor,
    required this.seeDoctorReason,
    required this.disclaimer,
    this.scansLeft,
  });

  final List<String> observations;
  final String confidence;
  final String summary;
  final List<String> concerns;
  final List<String> possibleCauses;
  final List<String> recommendations;
  final List<String> routineMorning;
  final List<String> routineEvening;
  final List<String> lifestyle;
  final List<ScanProduct> products;
  final List<String> avoid;
  final bool seeDoctor;
  final String seeDoctorReason;
  final String disclaimer;
  final int? scansLeft;

  factory SkinScanResult.fromJson(Map<String, dynamic> j, {int? scansLeft}) {
    final prods = j['products'];
    return SkinScanResult(
      observations: _strs(j['observations']),
      confidence: _str(j['confidence']).toLowerCase(),
      summary: _str(j['summary']),
      concerns: _strs(j['concerns']),
      possibleCauses: _strs(j['possible_causes']),
      recommendations: _strs(j['recommendations']),
      routineMorning: _strs(j['routine_morning']),
      routineEvening: _strs(j['routine_evening']),
      lifestyle: _strs(j['lifestyle']),
      products: prods is List
          ? [
              for (final p in prods)
                if (p is Map)
                  ScanProduct.fromJson(Map<String, dynamic>.from(p)),
            ]
          : <ScanProduct>[],
      avoid: _strs(j['avoid']),
      seeDoctor: j['see_doctor'] == true,
      seeDoctorReason: _str(j['see_doctor_reason']),
      disclaimer: _str(j['disclaimer']),
      scansLeft: scansLeft,
    );
  }
}

class SkinAiService {
  SkinAiService({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<SkinScanResult> analyze(
    List<XFile> files, {
    String? skinType,
    String? note,
  }) async =>
      _parse(await _api.analyzeSkin(files, skinType: skinType, note: note));

  Future<SkinScanResult> analyzeVideo(
    XFile video, {
    String? skinType,
    String? note,
  }) async => _parse(
    await _api.analyzeSkinVideo(video, skinType: skinType, note: note),
  );

  SkinScanResult _parse(Map<String, dynamic> m) {
    var root = m;
    if (root['analysis'] is! Map && root['data'] is Map) {
      root = Map<String, dynamic>.from(root['data'] as Map);
    }
    final a = root['analysis'];
    final left = root['scans_left'];
    return SkinScanResult.fromJson(
      a is Map ? Map<String, dynamic>.from(a) : root,
      scansLeft: left is num ? left.toInt() : null,
    );
  }
}
