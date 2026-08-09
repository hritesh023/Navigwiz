import 'window_control_web.dart'
    if (dart.library.io) 'window_control_io.dart' as impl;

/// Wraps desktop window controls (minimize / maximize / close).
///
/// On web these are no-ops because the browser owns the window. On desktop
/// they drive the native window via window_manager.
class WindowControlService {
  static Future<void> initialize() => impl.initialize();

  static Future<void> minimize() => impl.minimize();

  static Future<void> toggleMaximize() => impl.toggleMaximize();

  static Future<void> close() => impl.close();
}
