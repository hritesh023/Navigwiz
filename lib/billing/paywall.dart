// Global paywall bus for Navigwiz: any HTTP 402 (AI task quota exhausted)
// funnels here and lands the user on the PricingScreen.
// Wired once at app start via PaywallBus.attach(navigatorKey).
import 'package:flutter/material.dart';

import '../screens/pricing_screen.dart';

/// Thrown when the backend reports the AI-task allowance is exhausted.
/// Carries the server's message + upgrade URL so UI can show a CTA.
class PaywallException implements Exception {
  final String message;
  final String upgradeUrl;
  final String? planRequired;
  PaywallException(this.message,
      {this.upgradeUrl = 'https://acronous.com/pricing.html#nav', this.planRequired});
  @override
  String toString() => message;
}

class PaywallBus {
  static GlobalKey<NavigatorState>? _nav;
  static DateTime? _lastPush;

  static void attach(GlobalKey<NavigatorState> key) {
    _nav = key;
  }

  static bool isPaywallStatus(int status, Map<String, dynamic>? body) {
    if (status == 402) return true;
    final t = body?['type'];
    final e = body?['error'];
    if (t == 'paywall') return true;
    if (e == 'quota_exceeded' || e == 'out_of_credits') return true;
    if (e is String && e.startsWith('QUOTA_')) return true;
    return false;
  }

  static PaywallException fromBody(Map<String, dynamic>? body, {int status = 402}) {
    final msg = (body?['response'] ?? body?['error'] ?? '').toString();
    return PaywallException(
      msg.isNotEmpty ? msg : 'You have used your AI allowance. Upgrade to continue.',
      upgradeUrl: (body?['upgrade_url'] ?? 'https://acronous.com/pricing.html#nav').toString(),
      planRequired: body?['plan_required']?.toString() ?? body?['plan']?.toString(),
    );
  }

  /// Push the PricingScreen (throttled, post-frame). Returns true when handled.
  static bool handle(Object e) {
    if (e is! PaywallException) return false;
    final now = DateTime.now();
    if (_lastPush != null && now.difference(_lastPush!).inSeconds < 3) return true;
    _lastPush = now;
    final nav = _nav?.currentState;
    if (nav == null) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        nav.push(MaterialPageRoute(builder: (_) => const PricingScreen()));
      } catch (_) {}
    });
    return true;
  }
}
