import 'api_client.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String demoDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String demoRupees(int paise) {
  final whole = paise ~/ 100;
  final rest = paise % 100;
  return rest == 0
      ? '\u20B9$whole'
      : '\u20B9$whole.${rest.toString().padLeft(2, '0')}';
}

class DemoPlan {
  DemoPlan({
    required this.id,
    required this.name,
    required this.days,
    required this.amountPaise,
  });
  final String id;
  final String name;
  final int days;
  final int amountPaise;

  String get price => demoRupees(amountPaise);

  factory DemoPlan.fromJson(Map<String, dynamic> j) => DemoPlan(
    id: j['id'] as String,
    name: j['name'] as String,
    days: (j['days'] as num).toInt(),
    amountPaise: (j['amount_paise'] as num).toInt(),
  );
}

class DemoPlansResponse {
  DemoPlansResponse(this.demo, this.plans);

  /// True when payments are set up on the server.
  final bool demo;
  final List<DemoPlan> plans;
}

class DemoPayment {
  DemoPayment({
    required this.txnId,
    required this.planName,
    required this.amountPaise,
    required this.method,
    required this.status,
    required this.isDemo,
    required this.createdAt,
  });
  final String txnId;
  final String planName;
  final int amountPaise;
  final String method;
  final String status;
  final bool isDemo;
  final DateTime createdAt;

  factory DemoPayment.fromJson(Map<String, dynamic> j) => DemoPayment(
    txnId: (j['txn_id'] ?? '').toString(),
    planName: (j['plan_name'] ?? '').toString(),
    amountPaise: (j['amount_paise'] as num?)?.toInt() ?? 0,
    method: (j['method'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    isDemo: j['is_demo'] == true,
    createdAt:
        DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ??
        DateTime.now(),
  );
}

/// Loads plans and payment history. The server decides everything.
class DemoPaymentService {
  DemoPaymentService({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<DemoPlansResponse> plans() async {
    final m =
        await _api.request('GET', '/api/premium/plans') as Map<String, dynamic>;
    final list = (m['plans'] as List? ?? const [])
        .map((e) => DemoPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return DemoPlansResponse(m['enabled'] == true, list);
  }

  Future<List<DemoPayment>> history() async {
    final d = await _api.request('GET', '/api/premium/payments');
    final list = d is List ? d : const [];
    return [
      for (final e in list)
        if (e is Map) DemoPayment.fromJson(Map<String, dynamic>.from(e)),
    ];
  }
}