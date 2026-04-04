import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Reads [PlatformFile] bytes. On some platforms (e.g. web) [PlatformFile.bytes] may be
/// empty until the stream is consumed — this falls back to [PlatformFile.readStream].
Future<Uint8List?> readPlatformFileBytes(PlatformFile file) async {
  if (file.bytes != null && file.bytes!.isNotEmpty) {
    return file.bytes;
  }
  final stream = file.readStream;
  if (stream != null) {
    final chunks = <int>[];
    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }
    if (chunks.isEmpty) return null;
    return Uint8List.fromList(chunks);
  }
  return null;
}
