import 'package:web/web.dart' as web;

String? currentHref() => web.window.location.href;

void replaceState(String url) => web.window.history.replaceState(null, '', url);

void redirectTo(String url) {
  web.window.location.href = url;
}
