import 'dart:async';

Future<Map<String, String>?> openRazorpayCheckout(
  Map<String, Object?> options,
) {
  return Future.error(
    UnsupportedError('Razorpay checkout is not configured for this platform.'),
  );
}
