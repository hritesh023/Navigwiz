import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../billing/billing_service.dart';
import '../billing/plans.dart';

/// In-app pricing + subscription status. Checkout runs on acronous.com via
/// Razorpay Checkout (single audited implementation, UPI/cards/netbanking);
/// this screen reads the granted entitlement back from api.acronous.com.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late final NavigwizBillingService _billing = NavigwizBillingService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _billing.refresh());
  }

  @override
  void dispose() {
    _billing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChangeNotifierProvider.value(
      value: _billing,
      child: Consumer<NavigwizBillingService>(
        builder: (context, billing, _) => Scaffold(
          appBar: AppBar(title: const Text('AI Plans & Billing'), centerTitle: true),
          body: RefreshIndicator(
            onRefresh: billing.refresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PageHeader(cs: cs),
                        const SizedBox(height: 20),
                        _StatusCard(cs: cs, billing: billing),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cols = constraints.maxWidth >= 960
                                ? 3
                                : constraints.maxWidth >= 640
                                    ? 2
                                    : 1;
                            const gap = 16.0;
                            final cardWidth =
                                (constraints.maxWidth - gap * (cols - 1)) / cols;
                            return Wrap(
                              spacing: gap,
                              runSpacing: 12,
                              children: [
                                for (final plan in navigwizPlans)
                                  SizedBox(
                                    width: cols == 1 ? double.infinity : cardWidth,
                                    child: _PlanCard(
                                        cs: cs, plan: plan, billing: billing),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse('https://acronous.com/docs.html#subscriptions'),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Text('Billing FAQ & refunds'),
                          ),
                        ),
                        Text(
                          'Secured by Razorpay · UPI · Cards · Netbanking · International',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final ColorScheme cs;
  const _PageHeader({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Navigwiz plans · secured by Razorpay',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Browser stays free. Pay for AI work.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Most people stay on Browser forever. Upgrade for AI research and agentic browsing.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final ColorScheme cs;
  final NavigwizBillingService billing;
  const _StatusCard({required this.cs, required this.billing});

  @override
  Widget build(BuildContext context) {
    if (billing.loading) {
      return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
    }
    return Card(
      color: cs.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Icon(Icons.verified_rounded, color: cs.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current plan: ${billing.activePlanId ?? 'Browser (free)'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (billing.error != null)
                Text(billing.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: billing.refresh, tooltip: 'Refresh status'),
        ]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ColorScheme cs;
  final NavPlan plan;
  final NavigwizBillingService billing;
  const _PlanCard({required this.cs, required this.plan, required this.billing});

  @override
  Widget build(BuildContext context) {
    final active = billing.activePlanId == plan.id;
    // Compact Equyvo-style button: h-10 (40px), px-4, text-sm, rounded-md.
    final compactBtnStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    final compactOutlineStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: plan.popular
            ? BorderSide(color: cs.primary, width: 1.6)
            : BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(plan.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (plan.popular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
                child: Text('POPULAR', style: TextStyle(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
          ]),
          Text(plan.tagline, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 6),
          Text('${formatPlanPrice(plan.priceInr)}${(plan.priceInr ?? 0) > 0 ? '/mo' : ''}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: plan.priceInr == 0
                ? OutlinedButton(style: compactOutlineStyle, onPressed: active ? null : () => Navigator.pop(context), child: Text(active ? 'Current plan' : 'You are on Browser'))
                : FilledButton(
                    style: compactBtnStyle,
                    onPressed: (active || billing.busyPlanId != null)
                        ? null
                        : () async {
                            final ok = await billing.buy(plan);
                            if (!context.mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Payment verified. Your plan is active.')),
                              );
                            } else if (billing.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(billing.error!)),
                              );
                            }
                          },
                    child: billing.busyPlanId == plan.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(active ? 'Current plan' : 'Choose ${plan.label.replaceAll(' ⭐', '')}'),
                  ),
          ),
        ]),
      ),
    );
  }
}
