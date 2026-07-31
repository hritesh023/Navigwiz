import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void watchForServiceWorkerUpdates() {
  final sw = web.window.navigator.serviceWorker;

  var refreshing = false;
  sw.addEventListener('controllerchange', ((web.Event _) {
    if (refreshing) return;
    refreshing = true;
    web.window.location.reload();
  }).toJS);

  sw.ready.toDart.then((registration) {
    void adopt(web.ServiceWorker? worker) {
      if (worker == null) return;
      worker.addEventListener('statechange', ((web.Event _) {
        if (worker.state == 'installed') {
          worker.postMessage('SKIP_WAITING'.toJS);
        }
      }).toJS);
    }

    registration.addEventListener('updatefound', ((web.Event _) {
      adopt(registration.installing);
    }).toJS);
    adopt(registration.waiting);

    Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(registration.update().toDart);
    });
  });
}
