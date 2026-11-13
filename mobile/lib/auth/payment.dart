import '../services/api_client.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'cashfree_mobile_stub.dart'
    if (dart.library.io) 'cashfree_mobile.dart'
    as mobile;
import 'session.dart';

import 'cashfree_stub.dart'
    if (dart.library.js_interop) 'cashfree_web.dart'
    as cashfree;

/// Creates a Cashfree order, opens the checkout, then asks the server to
/// confirm the payment. Premium is switched on by the server only.
Future<void> payForPremium(String plan) async {
  final api = ApiClient();

  final o = await api.request(
    'POST',
    '/api/premium/order',
    body: {'plan': plan},
  ) as Map<String, dynamic>;

  if (!kIsWeb) {
    await mobile.payOnMobile(
      orderId: (o['order_id'] ?? '').toString(),
      sessionId: (o['payment_session_id'] ?? '').toString(),
      mode: (o['mode'] ?? 'sandbox').toString(),
    );
  } else {
    await cashfree.openCashfreeCheckout(
      sessionId: (o['payment_session_id'] ?? '').toString(),
      mode: (o['mode'] ?? 'sandbox').toString(),
    );
  }

  final u = await api.request(
    'POST',
    '/api/premium/verify',
    body: {'order_id': o['order_id']},
  ) as Map<String, dynamic>;

  Session.I.setUser(u);
}
