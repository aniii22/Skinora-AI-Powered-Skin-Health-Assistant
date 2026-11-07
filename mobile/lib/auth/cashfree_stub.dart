import '../services/api_client.dart' show ApiException;

Future<void> openCashfreeCheckout({
  required String sessionId,
  required String mode,
}) async {
  throw ApiException(
    'Online payment works in the web app for now. Android payments are being set up.',
  );
}