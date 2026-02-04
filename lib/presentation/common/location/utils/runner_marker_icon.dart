import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Creates a stick-figure / runner style marker icon for the map.
/// Uses a simple drawn figure (head circle + body and limbs) so no asset is required.
BitmapDescriptor? _cachedRunnerIcon;

/// Returns a BitmapDescriptor for a runner/stick-figure marker. Cached after first call.
Future<BitmapDescriptor> getRunnerMarkerIcon() async {
  if (_cachedRunnerIcon != null) return _cachedRunnerIcon!;
  const int size = 96;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..color = Colors.orange
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;

  const cx = size / 2.0;
  const cy = size / 2.0;
  const scale = size / 80.0;

  // Head (circle)
  canvas.drawCircle(Offset(cx, cy - 22 * scale), 8 * scale, paint);
  // Body (line down)
  canvas.drawLine(
    Offset(cx, cy - 14 * scale),
    Offset(cx, cy + 12 * scale),
    paint,
  );
  // Arms (running pose: one forward, one back)
  canvas.drawLine(
    Offset(cx, cy - 6 * scale),
    Offset(cx - 14 * scale, cy + 4 * scale),
    paint,
  );
  canvas.drawLine(
    Offset(cx, cy - 6 * scale),
    Offset(cx + 14 * scale, cy - 2 * scale),
    paint,
  );
  // Legs (running)
  canvas.drawLine(
    Offset(cx, cy + 12 * scale),
    Offset(cx - 10 * scale, cy + 28 * scale),
    paint,
  );
  canvas.drawLine(
    Offset(cx, cy + 12 * scale),
    Offset(cx + 12 * scale, cy + 26 * scale),
    paint,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  final bytes = byteData.buffer.asUint8List();
  _cachedRunnerIcon = BitmapDescriptor.bytes(bytes);
  return _cachedRunnerIcon!;
}
