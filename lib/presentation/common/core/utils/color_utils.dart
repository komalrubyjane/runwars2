import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:run_flutter_run/core/theme/strava_theme.dart';

/// Utility class for color-related operations. Uses Strava theme.
class ColorUtils {
  static Color main = StravaTheme.orange;
  static Color mainDarker = StravaTheme.orangeDark;
  static Color mainMedium = StravaTheme.orange;
  static Color mainLight = StravaTheme.orangeLight;

  static Color error = Colors.red.shade600;
  static Color errorDarker = Colors.red.shade800;
  static Color errorLight = Colors.red.shade100;

  static Color warning = Colors.orange;

  static Color white = Colors.white;
  static Color black = Colors.black;
  static Color red = Colors.red;
  static Color green = StravaTheme.green;
  static Color greenDarker = const Color(0xFF169B45);
  static Color transparent = Colors.transparent;
  static Color grey = StravaTheme.grey600;
  static Color greyDarker = StravaTheme.grey800;
  static Color greyLight = StravaTheme.grey200;
  static Color blueGrey = StravaTheme.grey600;
  static Color blueGreyDarker = StravaTheme.grey800;
  static Color backgroundLight = StravaTheme.white;

  /// List of colors used for generating color tuples (Strava-style).
  static List<Color> colorList = [
    StravaTheme.orange,
    StravaTheme.orangeDark,
    StravaTheme.green,
    Colors.blueGrey
  ];

  /// Generates a darker color based on the given [baseColor].
  ///
  /// The [baseColor] is used as the reference color for generating the darker color.
  /// The darker color is determined based on the luminance of the base color.
  static Color generateDarkColor(Color baseColor) {
    final luminance = baseColor.computeLuminance();
    final darkColor =
        luminance > 0.5 ? baseColor.withOpacity(0.8) : baseColor.darker();
    return darkColor;
  }

  /// Generates a lighter color based on the given [baseColor].
  ///
  /// The [baseColor] is used as the reference color for generating the lighter color.
  /// The lighter color is determined based on the luminance of the base color.
  static Color generateLightColor(Color baseColor) {
    final luminance = baseColor.computeLuminance();
    final lightColor =
        luminance > 0.5 ? baseColor.lighter() : baseColor.withOpacity(0.8);
    return lightColor;
  }

  /// Generates a color tuple from the [colorList] based on the given [index].
  ///
  /// The [index] is used to select the base color from the color list.
  /// The base color is then used to generate a dark color and a light color,
  /// forming a color tuple of length 2.
  static List<Color> generateColorTupleFromIndex(int index) {
    final baseColor = colorList[index % colorList.length];
    final darkColor = generateDarkColor(baseColor);
    final lightColor = generateLightColor(baseColor);
    return [darkColor, lightColor];
  }

  static Future<ImageProvider<Object>?> colorToImageProvider(Color color,
      {double width = 32.0, double height = 32.0}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTRB(0, 0, width, height), paint);
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return MemoryImage(byteData.buffer.asUint8List());
    } else {
      return null;
    }
  }
}

/// Extension methods for the [Color] class.
extension ColorExtension on Color {
  /// Returns a darker shade of the color.
  ///
  /// The [factor] determines the darkness of the shade.
  /// A factor of 0.0 represents the same color, while a factor of 1.0 represents a fully dark color.
  Color darker([double factor = 0.1]) {
    return Color.fromARGB(
      alpha,
      (red * (1.0 - factor)).round(),
      (green * (1.0 - factor)).round(),
      (blue * (1.0 - factor)).round(),
    );
  }

  /// Returns a lighter shade of the color.
  ///
  /// The [factor] determines the lightness of the shade.
  /// A factor of 0.0 represents the same color, while a factor of 1.0 represents a fully light color.
  Color lighter([double factor = 0.1]) {
    return Color.fromARGB(
      alpha,
      (red + (255 - red) * factor).round(),
      (green + (255 - green) * factor).round(),
      (blue + (255 - blue) * factor).round(),
    );
  }
}
