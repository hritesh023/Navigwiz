import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:navigwiz/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('gif magic detection', () {
    final gif89 = Uint8List.fromList(
        [0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x10, 0x00, 0x10, 0x00]);
    final gif87 = Uint8List.fromList(
        [0x47, 0x49, 0x46, 0x38, 0x37, 0x61, 0x10, 0x00, 0x10, 0x00]);
    final png = Uint8List.fromList(
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(ThemeService.isGifBytes(gif89), isTrue);
    expect(ThemeService.isGifBytes(gif87), isTrue);
    expect(ThemeService.isGifBytes(png), isFalse);
    expect(ThemeService.gifDimensions(gif89), equals([16, 16]));
    expect(ThemeService.gifDimensions(png), isNull);
  });

  test('supported format gate keeps Flutter-renderable, rejects others',
      () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
    final png = Uint8List.fromList(
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
    final webp = Uint8List.fromList(
        [0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50]);
    final bmp = Uint8List.fromList([0x42, 0x4D, 0x00, 0x00]);
    final svg = Uint8List.fromList('<svg xmlns'.codeUnits);
    final html = Uint8List.fromList('<html><body>'.codeUnits);

    expect(ThemeService.isSupportedImageBytes(jpeg), isTrue);
    expect(ThemeService.isSupportedImageBytes(png), isTrue);
    expect(ThemeService.isSupportedImageBytes(gif), isTrue);
    expect(ThemeService.isSupportedImageBytes(webp), isTrue);
    expect(ThemeService.isSupportedImageBytes(bmp), isTrue);
    expect(ThemeService.isSupportedImageBytes(svg), isFalse);
    expect(ThemeService.isSupportedImageBytes(html), isFalse);
    expect(ThemeService.isSupportedImageBytes(Uint8List(0)), isFalse);

    expect(ThemeService.unsupportedFormatReason(svg, fileName: 'a.svg'),
        contains('SVG'));
    expect(ThemeService.unsupportedFormatReason(html), contains('web page'));
    expect(
        ThemeService.unsupportedFormatReason(Uint8List.fromList([1, 2, 3]),
            fileName: 'x.avif'),
        contains('AVIF'));
    expect(ThemeService.unsupportedFormatReason(jpeg), isNull);
  });

  test('prepareBackgroundBytes rejects empty/oversized/unsupported',
      () async {
    final svc = ThemeService();
    await expectLater(svc.prepareBackgroundBytes(Uint8List(0)),
        throwsA(isA<ArgumentError>()));
    await expectLater(
        svc.prepareBackgroundBytes(
            Uint8List.fromList('<svg xmlns'.codeUnits),
            fileName: 'a.svg'),
        throwsA(isA<StateError>()));
    final huge = Uint8List(ThemeService.maxDecodeBytes + 1);
    await expectLater(
        svc.prepareBackgroundBytes(huge), throwsA(isA<StateError>()));
  });

  test('prepareBackgroundBytes accepts a real small PNG end-to-end',
      () async {
    final svc = ThemeService();
    final image = img.Image(width: 32, height: 32);
    img.fill(image, color: img.ColorRgb8(10, 120, 200));
    final pngBytes = Uint8List.fromList(img.encodePng(image));
    final prepared =
        await svc.prepareBackgroundBytes(pngBytes, fileName: 't.png');
    expect(prepared.isNotEmpty, isTrue);
    expect(ThemeService.isSupportedImageBytes(prepared), isTrue);
    expect(await ThemeService.flutterCanRender(prepared), isTrue);
  });

  test('prepareBackgroundBytes accepts a real small GIF end-to-end',
      () async {
    final svc = ThemeService();
    final f1 = img.Image(width: 16, height: 16);
    img.fill(f1, color: img.ColorRgb8(200, 30, 30));
    final f2 = img.Image(width: 16, height: 16);
    img.fill(f2, color: img.ColorRgb8(30, 200, 30));
    f1.addFrame(f2);
    final gifBytes = Uint8List.fromList(img.encodeGif(f1));
    expect(ThemeService.isGifBytes(gifBytes), isTrue);
    final prepared =
        await svc.prepareBackgroundBytes(gifBytes, fileName: 'a.gif');
    expect(ThemeService.isGifBytes(prepared), isTrue);
  });
}
