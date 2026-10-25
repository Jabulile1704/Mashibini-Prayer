// Draws the app icon and writes every size both platforms need.
//
//   flutter test tool/generate_icons.dart
//
// It is a test only because that is the one way to get a real Flutter canvas
// without a device attached. It asserts nothing: it paints, and it writes.
//
// The icon is generated rather than drawn in an editor so it can be changed
// in one place and regenerated everywhere — the same reasoning as Zaka's
// GenerateAppIcon.swift and Yetsa's MakeIcon.swift.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/presentation/brand/mark.dart';
import 'package:mashibini_prayer/src/presentation/brand/palette.dart';

/// iOS wants every one of these, by exactly these names.
const Map<String, int> _iosSizes = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

const Map<String, int> _androidSizes = <String, int>{
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// The mark alone, on nothing. Used for the launch screen, where the
/// platform paints the background and a baked-in square would show a seam.
Future<Uint8List> _paintMark(int pixels) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  RotaMarkPainter(
    ringColour: Palette.parchment.withValues(alpha: 0.36),
    currentColour: Palette.ember,
  ).paint(canvas, Size(pixels.toDouble(), pixels.toDouble()));

  final ui.Image image = await recorder.endRecording().toImage(pixels, pixels);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _paintIcon(int pixels) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final double size = pixels.toDouble();

  // Opaque, always. An App Store icon may not carry an alpha channel, and a
  // transparent Android icon becomes whatever happens to be behind it.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = Palette.ink,
  );

  // The mark sits on about two thirds of the tile, roughly where iOS expects
  // a mark to sit inside its rounded mask.
  final double inset = size * 0.2;
  canvas.translate(inset, inset);
  RotaMarkPainter(
    ringColour: Palette.parchment.withValues(alpha: 0.36),
    currentColour: Palette.ember,
  ).paint(canvas, Size(size - inset * 2, size - inset * 2));

  final ui.Image image = await recorder.endRecording().toImage(pixels, pixels);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('generate the app icons', (WidgetTester tester) async {
    await tester.runAsync(() async {
      int written = 0;

      for (final MapEntry<String, int> entry in _iosSizes.entries) {
        final File file = File(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
        );
        await file.writeAsBytes(await _paintIcon(entry.value));
        written++;
      }

      for (final MapEntry<String, int> entry in _androidSizes.entries) {
        final File file = File(
          'android/app/src/main/res/${entry.key}/ic_launcher.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(await _paintIcon(entry.value));
        written++;
      }

      // The launch mark, at the three densities iOS asks for and one for
      // Android. Transparent, so the platform's background colour — set to
      // the same ink in the storyboard and in launch_background.xml — shows
      // through with no seam.
      const Map<String, int> launchSizes = <String, int>{
        'LaunchImage.png': 96,
        'LaunchImage@2x.png': 192,
        'LaunchImage@3x.png': 288,
      };
      for (final MapEntry<String, int> entry in launchSizes.entries) {
        final File file = File(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/${entry.key}',
        );
        await file.writeAsBytes(await _paintMark(entry.value));
        written++;
      }

      for (final MapEntry<String, int> entry in _androidSizes.entries) {
        final File file = File(
          'android/app/src/main/res/${entry.key}/launch_image.png',
        );
        await file.writeAsBytes(await _paintMark(entry.value * 2));
        written++;
      }

      // ignore: avoid_print
      print('Wrote $written files.');
    });
  });
}
