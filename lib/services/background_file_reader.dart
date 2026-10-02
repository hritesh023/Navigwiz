// Web-safe conditional export: on web (no dart:io) the stub is linked,
// on desktop/mobile the dart:io implementation is linked. This keeps
// customization_panel.dart compilable for web while restoring the
// path-based File fallback on native platforms.
export 'background_file_reader_stub.dart'
    if (dart.library.io) 'background_file_reader_io.dart';
