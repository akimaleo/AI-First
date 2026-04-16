import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

/// Snapshots a [RepaintBoundary] into a PNG on disk so the OS share sheet can
/// pick it up as an image attachment.
class ShareCardRenderer {
  ShareCardRenderer({Future<Directory> Function()? tempDir})
      : _tempDir = tempDir ?? getTemporaryDirectory;

  final Future<Directory> Function() _tempDir;

  Future<File> exportToPng(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
    String fileName = 'sync_or_sink_moment',
  }) async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode share card to PNG');
    }
    final dir = await _tempDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/${fileName}_$timestamp.png');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return file;
  }
}
