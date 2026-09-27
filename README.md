# Navigwiz

Navigwiz is an open-source Flutter browser with a Linux desktop target, web/PWA support, Android support, custom Navigwiz search results, and the Apex Ai assistant.

## Search

User searches stay inside the Navigwiz frontend as custom `Navigwiz Search` results. Backend providers are implementation details and are not exposed in the browser UI.

Configure the private search backend with your deployment environment.

## 💳 Billing & Subscriptions

Navigwiz uses the **central Acronous billing system** (Razorpay + KV entitlements). The browser is free; AI work is paid.

### Plans
| Plan | Price | AI Tasks/Day | Research/Day |
|---|---|---|---|
| Browser (free) | ₹0 | 10 | 3 |
| AI Starter | ₹99/mo | 100 | 20 |
| AI Plus | ₹299/mo | 500 | 100 |
| AI Pro | ₹699/mo | 2,000 | 400 |
| AI Ultra | ₹1,499/mo | 8,000 | 1,500 |

### Flow
1. User clicks a plan on PricingScreen → `NavigwizBillingService.buy(plan)`
2. `POST /v1/billing/order {plan}` → central worker creates Razorpay order
3. Razorpay Checkout opens (in-app on mobile, fallback URL on desktop)
4. `POST /v1/billing/verify` → central verifies HMAC + binds order → grants KV entitlement
5. `PaywallBus` pushes PricingScreen on any HTTP 402

### Entitlement enforcement
- `ai-worker/src/index.js` — `requireNavigwizPlan()` gates `/v1/research` (Starter+), `/v1/project/generate` (Plus+), `/v1/agent/build` (Pro+)
- `lib/billing/paywall.dart` — `PaywallBus` + `PaywallException`
- `lib/billing/billing_service.dart` — checkout + friendly error messages
- `backend/app/api/billing.py` — plan-strict local checkout (mirrors central)

### Key files
- `lib/billing/billing_service.dart` — `buy()`, `refresh()`, `_friendly()`
- `lib/billing/paywall.dart` — `PaywallBus.handle()`, `PaywallException`
- `lib/services/ai_service.dart` — sends `Authorization: Bearer` on AI calls, handles 402
- `ai-worker/src/index.js` — `requireNavigwizPlan()`, `navigwizPlanRank()`

## Platforms

- Linux desktop: includes a `.desktop` entry declaring Navigwiz as a web browser handler for `http` and `https`.
- Web: ships as a standalone installable PWA named `Navigwiz`.
- Android: declares `http`, `https`, and web search intent filters so it can be offered for browser/search actions.

## Development

```bash
flutter pub get
flutter run
flutter test
```
