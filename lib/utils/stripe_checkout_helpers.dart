import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

class StripeCheckoutHelpers {
  static bool isUserCanceled(Object e) {
    if (e is stripe.StripeException) {
      final code = e.error.code.toString().toLowerCase();
      final msg = (e.error.localizedMessage ?? e.error.message ?? '').toLowerCase();
      return code.contains('cancel') || msg.contains('cancel');
    }
    final s = e.toString().toLowerCase();
    return s.contains('payment flow has been canceled') || s.contains('canceled') || s.contains('cancelled');
  }

  static String format(Object e) {
    if (e is stripe.StripeException) {
      final msg = e.error.localizedMessage ?? e.error.message;
      if (msg != null && msg.trim().isNotEmpty) return msg.trim();
      return e.toString();
    }
    if (e is stripe.StripeConfigException) {
      final msg = e.message;
      if (msg.trim().isNotEmpty) return msg.trim();
      return e.toString();
    }
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring('Exception: '.length) : s;
  }
}

