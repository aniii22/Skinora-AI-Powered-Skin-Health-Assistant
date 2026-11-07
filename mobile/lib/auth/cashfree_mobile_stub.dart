Future<void> payOnMobile({
  required String orderId,
  required String sessionId,
  required String mode,
}) async {
  throw UnsupportedError('Mobile checkout is not available on this platform.');
}