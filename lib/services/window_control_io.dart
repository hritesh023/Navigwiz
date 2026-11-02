import 'dart:ui';

import 'package:window_manager/window_manager.dart';

Future<void> initialize() async {
  await windowManager.ensureInitialized();
  await windowManager.setTitle('Navigwiz');
  await windowManager.setMinimumSize(const Size(800, 600));
  await windowManager.waitUntilReadyToShow(null, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> minimize() async {
  await windowManager.minimize();
}

Future<void> toggleMaximize() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

Future<void> close() async {
  await windowManager.close();
}
