import 'dart:io';
import 'package:image/image.dart' as img;

// Format/size conversion only. The supplied artwork remains unchanged.
void main() {
  final original = File('assets/images/logo/kirakira-original.png');
  final image = img.decodePng(original.readAsBytesSync())!;
  final sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];
  final ico = img.IcoEncoder().encodeImages([
    for (final size in sizes)
      img.copyResize(image, width: size, height: size,
          interpolation: img.Interpolation.average),
  ]);
  for (final path in [
    'windows/runner/resources/app_icon.ico',
    'assets/images/logo/logo_windows.ico',
    'assets/images/logo/logo_lanczos.ico',
  ]) {
    File(path).writeAsBytesSync(ico);
  }
  for (final entry in {'': 256, '@2x': 512, '@3x': 768}.entries) {
    final png = img.encodePng(img.copyResize(image,
        width: entry.value, height: entry.value,
        interpolation: img.Interpolation.cubic));
    for (final variant in ['', 'Dark']) {
      File('ios/Runner/Assets.xcassets/LaunchImage.imageset/'
              'LaunchImage$variant${entry.key}.png')
          .writeAsBytesSync(png);
    }
  }
  stdout.writeln('Updated multi-size Windows/tray icons and iOS launch artwork.');
}
