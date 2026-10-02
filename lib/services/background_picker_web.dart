import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'background_picker_types.dart';

/// File size cap, mirroring Equyvo's `ChatThemeSelector.MAX_BYTES`.
/// Larger files are rejected before any decode with a friendly message.
const int _maxPickBytes = 12 * 1024 * 1024;

/// Picks a background image/GIF using a native browser
/// `<input type="file">` + `FileReader.readAsDataURL` — the exact flow of
/// Equyvo's `ChatThemeSelector.processFile`.
///
/// No `file_picker` plugin involved, so there is no `PlatformFile.path` to
/// throw "use bytes instead" on web. Returns null when the user cancels.
Future<PickedBackground?> pickBackgroundImage({bool gifOnly = false}) async {
  final completer = Completer<PickedBackground?>();

  final accept = gifOnly ? 'image/gif,.gif' : 'image/*,.gif';
  final uploadInput = HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = false
    ..style.display = 'none';

  var settled = false;
  void complete(PickedBackground? value) {
    if (settled) return;
    settled = true;
    if (!completer.isCompleted) completer.complete(value);
  }

  void fail(String message) {
    if (settled) return;
    settled = true;
    if (!completer.isCompleted) completer.completeError(StateError(message));
  }

  void onChange(Event _) {
    final files = uploadInput.files;
    if (files == null || files.length == 0) {
      complete(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      complete(null);
      return;
    }

    // Equyvo-style guards: MIME must be an image, size under cap.
    final mime = file.type;
    if (mime.isNotEmpty && !mime.startsWith('image/')) {
      fail('Please choose an image or GIF file.');
      return;
    }
    if (file.size > _maxPickBytes) {
      final mb = (file.size / 1048576).toStringAsFixed(1);
      fail('That file is too large ($mb MB). Please pick an image/GIF under 12 MB.');
      return;
    }
    if (file.size == 0) {
      fail('Selected file is empty.');
      return;
    }

    final reader = FileReader();
    reader.onLoadEnd.listen((_) {
      try {
        final dataUrl = (reader.result as JSString?)?.toDart;
        if (dataUrl == null || !dataUrl.startsWith('data:image/')) {
          fail('That file is not a readable image.');
          return;
        }
        final comma = dataUrl.indexOf(',');
        if (comma < 0) {
          fail('That file is not a readable image.');
          return;
        }
        final bytes = Uint8List.fromList(base64.decode(dataUrl.substring(comma + 1)));
        if (bytes.isEmpty) {
          fail('Selected file is empty.');
          return;
        }
        complete(PickedBackground(
          name: file.name.isNotEmpty ? file.name : 'background',
          bytes: bytes,
          size: file.size,
          mimeType: mime.isNotEmpty ? mime : null,
        ));
      } catch (_) {
        fail('Could not read that file. Try another image.');
      }
    });
    // `readAsDataURL` errors surface via onLoadEnd with an empty result,
    // which the handler above turns into a friendly failure.
    reader.readAsDataURL(file);
  }

  void onCancel(Event _) {
    // Fired when the user dismisses the dialog without picking.
    complete(null);
  }

  void onWindowFocus(Event _) {
    // Fallback for browsers that never fire `cancel`: if no change event
    // arrived shortly after focus returns, treat it as a cancel.
    Future.delayed(const Duration(seconds: 1)).then((_) => complete(null));
  }

  uploadInput.addEventListener('change', onChange.toJS);
  uploadInput.addEventListener('cancel', onCancel.toJS);
  window.addEventListener('focus', onWindowFocus.toJS);

  // Host the input in the document body (same technique as file_picker_web).
  final host = document.createElement('flt-navigwiz-bg-picker')
    ..id = '__navigwiz-bg-picker';
  document.querySelector('body')?.appendChild(host);
  host.appendChild(uploadInput);
  uploadInput.click();
  // Remove from DOM right away; the read continues off-element.
  uploadInput.remove();

  try {
    return await completer.future;
  } finally {
    window.removeEventListener('focus', onWindowFocus.toJS);
    try {
      host.remove();
    } catch (_) {}
  }
}
