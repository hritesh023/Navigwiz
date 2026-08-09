import 'package:window_manager/window_manager.dart';

Future<void> initialize() async {
  await windowManager.ensureInitialized();
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
