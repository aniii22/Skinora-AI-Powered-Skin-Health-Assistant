import 'dart:async';
import 'dart:js_interop';

@JS('skinoraPay')
external void _skinoraPay(
  JSAny opts,
  JSFunction onSuccess,
  JSFunction onDismiss,
);

/// Opens Razorpay Checkout (web). Returns the payment ids, or null if closed.
Future<Map<String, String>?> openRazorpayCheckout(
  Map<String, Object?> options,
) {
  final c = Completer<Map<String, String>?>();

  void ok(JSString paymentId, JSString orderId, JSString signature) {
    if (c.isCompleted) return;
    c.complete({
      'razorpay_payment_id': paymentId.toDart,
      'razorpay_order_id': orderId.toDart,
      'razorpay_signature': signature.toDart,
    });
  }

  void dismissed() {
    if (!c.isCompleted) c.complete(null);
  }

  try {
    _skinoraPay(options.jsify()!, ok.toJS, dismissed.toJS);
  } catch (e) {
    if (!c.isCompleted)
      c.completeError(Exception('Could not open the payment window.'));
  }
  return c.future;
}
