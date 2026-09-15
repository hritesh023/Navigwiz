// Navigwiz pricing catalog — mirrors billing/plans.json on acronous.com.
// The browser itself is FREE. Users pay for AI work on the web.
// Checkout is centralized on acronous.com/pricing.html via Razorpay.
class NavPlan {
  final String id;
  final String label;
  final int? priceInr;
  final String tagline;
  final List<String> features;
  final bool popular;
  const NavPlan({
    required this.id,
    required this.label,
    required this.priceInr,
    required this.tagline,
    required this.features,
    this.popular = false,
  });
}

const List<NavPlan> navigwizPlans = [
  NavPlan(id: 'nav_browser', label: 'Browser', priceInr: 0, tagline: 'Full browser, free', features: [
    'Tabs, Private Space, bookmarks', 'History, downloads, extensions, sync',
    'Basic search + basic AI assistance', 'No artificial crippling',
  ]),
  NavPlan(id: 'nav_ai_starter', label: 'AI Starter', priceInr: 99, tagline: 'AI browsing', features: [
    'AI search & page summarization', 'Basic voice & page Q&A',
    'Basic file analysis', 'Limited AI research + memory',
  ]),
  NavPlan(id: 'nav_ai_plus', label: 'AI Plus ⭐', priceInr: 299, tagline: 'Advanced browsing', popular: true, features: [
    'Multi-page research & PDF analysis', 'Advanced search + workspace memory',
    'Voice & camera analysis', 'File/folder intelligence', 'Compare websites',
  ]),
  NavPlan(id: 'nav_ai_pro', label: 'AI Pro', priceInr: 699, tagline: 'Agentic research', features: [
    'Agentic browsing & deep research', 'Multi-step tasks, data extraction',
    'Web scraping & structured reports', 'Advanced workspaces + persistent context',
  ]),
  NavPlan(id: 'nav_ai_ultra', label: 'AI Ultra', priceInr: 1499, tagline: 'Heavy professional use', features: [
    'Very high task allowance', 'Long-running agents, scheduled research',
    'Large-scale extraction', 'API access + priority processing',
  ]),
];

String formatPlanPrice(int? v) {
  if (v == null) return 'Custom';
  if (v == 0) return '₹0';
  return '₹${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
}
