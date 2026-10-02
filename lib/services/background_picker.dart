// Web-safe conditional export for the Equyvo-style background picker.
//
// On web (no dart:io) the native `<input type=file>` + data-URL
// implementation is linked — `file_picker` (and its throwing
// `PlatformFile.path`) is never involved. On desktop/mobile the
// `file_picker`-based implementation is linked instead.
export 'background_picker_web.dart'
    if (dart.library.io) 'background_picker_io.dart';
export 'background_picker_types.dart';
