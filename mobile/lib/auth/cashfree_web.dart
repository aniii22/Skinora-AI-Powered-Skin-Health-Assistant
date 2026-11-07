import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../services/api_client.dart' show ApiException;

/// Opens the Cashfree checkout popup and returns when it closes. The result
/// is never trusted: the server checks the order with Cashfree afterwards.
Future<void> openCashfreeCheckout({
  required String sessionId,
  required String mode,
}) async {
  if (!globalContext.has('Cashfree')) {
    throw ApiException(
      'The payment window could not load. Check your internet and reload the page.',
    );
  }
  final cashfree = globalContext.callMethod<JSObject>(
    'Cashfree'.toJS,
    {'mode': mode}.jsify(),
  );
  final promise = cashfree.callMethod<JSPromise>(
    'checkout'.toJS,
    {'paymentSessionId': sessionId, 'redirectTarget': '_modal'}.jsify(),
  );
  try {
    await promise.toDart;
  } catch (_) {}
}