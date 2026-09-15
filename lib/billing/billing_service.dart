// Centralized billing for Navigwiz.
// Money flow (no redirects, no QR codes, no secrets in the app):
//   1. App creates a Razorpay ORDER server-side at api.acronous.com.
//   2. The REAL Razorpay gateway opens in-app (checkout.js on web, native
//      SDK with UPI/cards on Android/iOS, hosted auto-checkout on desktop).
//   3. App sends payment+signature to /v1/billing/verify; the worker checks
//      HMAC-SHA256 and grants the subscription in KV.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/central_auth_service.dart';
import 'pay_gateway.dart';
import 'pay_result.dart';
import 'plans.dart';

class NavigwizBillingService extends ChangeNotifier {
  static const String billingHost = 'https://api.acronous.com';

  bool loading = false;
  String? activePlanId;
  int apiCredits = 0;
  String? busyPlanId;
  String? error;

  static String checkoutFallbackUrl({String? token, required String plan}) {
    final base =
        'https://acronous.com/checkout.html?plan=${Uri.encodeComponent(plan)}';
    if (token != null && token.isNotEmpty) {
      return '$base&token=${Uri.encodeComponent(token)}';
    }
    return base;
  }

  Map<String, String> get _headers {
    final t = CentralAuthService().token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('$billingHost$path'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    final j = jsonDecode(r.body);
    if (r.statusCode != 200 || j is! Map<String, dynamic>) {
      final msg = (j is Map ? j['error']?.toString() : null);
      throw StateError(msg?.isNotEmpty ?? false
          ? msg!
          : 'Request failed (${r.statusCode}). Please try again.');
    }
    return j;
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await http
          .get(Uri.parse('$billingHost/v1/billing/status?product=navigwiz'),
              headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 401) {
        error = 'Sign in to see your plan.';
        return;
      }
      if (r.statusCode != 200) throw Exception('status ${r.statusCode}');
      final s = jsonDecode(r.body) as Map<String, dynamic>;
      final subs = s['subscriptions'] as Map<String, dynamic>?;
      activePlanId =
          (subs?['navigwiz'] as Map<String, dynamic>?)?['plan'] as String?;
      apiCredits = (s['api_credits'] as num?)?.toInt() ?? 0;
    } catch (_) {
      error = 'Could not load subscription status.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Opens the real Razorpay gateway for [plan] and verifies the payment.
  /// Returns true when the plan is now active. Cancellation returns false
  /// quietly; failures set [error].
  Future<bool> buy(NavPlan plan) async {
    if (busyPlanId != null) return false;
    busyPlanId = plan.id;
    error = null;
    notifyListeners();
    try {
      final order = await _postJson('/v1/billing/order', {'plan': plan.id});
      final orderId = order['order_id'] as String? ?? '';
      final amount = (order['amount'] as num?)?.toInt() ?? 0;
      final keyId = order['key_id'] as String? ?? '';
      if (orderId.isEmpty || keyId.isEmpty || amount <= 0) {
        throw StateError('Could not start checkout. Please try again.');
      }
      late final GatewayResult g;
      try {
        g = await openRazorpayCheckout(
          keyId: keyId,
          amountPaise: amount,
          orderId: orderId,
          planLabel:
              '${plan.label.replaceAll(' ⭐', '')} (${formatPlanPrice(plan.priceInr)}/mo)',
          themeColor: '#f59e0b',
        );
      } on UnsupportedError {
        // Desktop: complete payment on the hosted auto-checkout page.
        await launchUrl(
          Uri.parse(checkoutFallbackUrl(
              token: CentralAuthService().token, plan: plan.id)),
          mode: LaunchMode.externalApplication,
        );
        return true;
      }
      await _postJson('/v1/billing/verify', {
        'razorpay_order_id': g.orderId,
        'razorpay_payment_id': g.paymentId,
        'razorpay_signature': g.signature,
        'plan': plan.id,
      });
      await refresh();
      return true;
    } on PaymentCancelled {
      return false;
    } catch (e) {
      error = e.toString().replaceFirst('StateError: ', '');
      if (error!.startsWith('Exception: ')) {
        error = error!.substring('Exception: '.length);
      }
      notifyListeners();
      return false;
    } finally {
      busyPlanId = null;
      notifyListeners();
    }
  }
}
