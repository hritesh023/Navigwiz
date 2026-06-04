# Navigwiz

Navigwiz is an open-source Flutter browser with a Linux desktop target, web/PWA support, Android support, custom Navigwiz search results, and the Apex Ai assistant.

## Search

User searches stay inside the Navigwiz frontend as custom `Navigwiz Search` results. Backend providers are implementation details and are not exposed in the browser UI.

Configure the private search backend with your deployment environment.

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
