import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class PhotoProcessor {
  Future<ProcessedPhoto> process({
    required String path,
    required List<String> watermarkLines,
  }) async {
    final input = await File(path).readAsBytes();

    final result = await Isolate.run(() {
      final decoded = img.decodeImage(input);
      if (decoded == null) {
        throw StateError('Foto tidak bisa diproses');
      }

      final resized = _resize(decoded);
      _drawWatermark(resized, watermarkLines);
      return img.encodeJpg(resized, quality: 80);
    });

    final hash = sha256.convert(result).toString();
    final output =
        File(path.replaceFirst(RegExp(r'\.[^.]+$'), '_processed.jpg'));
    await output.writeAsBytes(result, flush: true);

    return ProcessedPhoto(
      path: output.path,
      bytes: result,
      sha256Hash: hash,
    );
  }

  static img.Image _resize(img.Image source) {
    final longestSide =
        source.width > source.height ? source.width : source.height;
    if (longestSide <= 1024) return source;

    if (source.width >= source.height) {
      return img.copyResize(source, width: 1024);
    }
    return img.copyResize(source, height: 1024);
  }

  static void _drawWatermark(img.Image image, List<String> lines) {
    var y = 18;
    for (final line in lines) {
      img.drawString(
        image,
        line,
        font: img.arial14,
        x: 18,
        y: y,
        color: img.ColorRgb8(255, 255, 255),
      );
      y += 20;
    }
  }
}

class ProcessedPhoto {
  const ProcessedPhoto({
    required this.path,
    required this.bytes,
    required this.sha256Hash,
  });

  final String path;
  final List<int> bytes;
  final String sha256Hash;
}
