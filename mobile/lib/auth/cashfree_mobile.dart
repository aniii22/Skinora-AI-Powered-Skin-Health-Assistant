import 'dart:async';

import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';

import '../services/api_client.dart' show ApiException;

/// Opens the Cashfree checkout on Android. Completes when Cashfree reports
/// the payment as done; the server then confirms it before Premium turns on.
Future<void> payOnMobile({
  required String orderId,
  required String sessionId,
  required String mode,
}) async {
  final done = Completer<void>();
  final service = CFPaymentGatewayService();
  service.setCallback(
    (String id) {
      if (!done.isCompleted) done.complete();
    },
    (CFErrorResponse e, String id) {
      if (!done.isCompleted) {
        done.completeError(
          ApiException(e.getMessage() ?? 'Payment was not completed.'),
        );
      }
    },
  );
  try {
    final session = CFSessionBuilder()
        .setEnvironment(
          mode == 'production' ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX,
        )
        .setOrderId(orderId)
        .setPaymentSessionId(sessionId)
        .build();
    final pay = CFWebCheckoutPaymentBuilder().setSession(session).build();
    service.doPayment(pay);
  } catch (_) {
    if (!done.isCompleted) {
      done.completeError(ApiException('Could not open the payment screen.'));
    }
  }
  return done.future.timeout(
    const Duration(minutes: 10),
    onTimeout: () => throw ApiException(
      'Payment is taking too long. If money was deducted, reopen the app to confirm.',
    ),
  );
}