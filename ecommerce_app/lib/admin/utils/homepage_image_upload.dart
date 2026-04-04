import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/images/product_image_compress.dart';
import '../../presentation/utils/user_facing_error_message.dart';
import '../providers/admin_providers.dart';
import 'admin_file_bytes.dart';

/// Picks an image, reads bytes (web-safe), compresses, uploads to homepage storage with timeout.
/// Always clears loading via [setUploading] in [finally].
Future<void> pickAndUploadHomepageImage({
  required BuildContext context,
  required WidgetRef ref,
  required String storageFolder,
  required void Function(bool uploading) setUploading,
  required void Function(String publicUrl) onUploaded,
}) async {
  setUploading(true);
  try {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return;

    final file = pick.files.single;
    final raw = await readPlatformFileBytes(file);
    if (raw == null || raw.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read this file. Try a smaller JPG/PNG/WebP, or paste an image URL instead.',
            ),
          ),
        );
      }
      return;
    }

    final compressed = compressProductImageForUpload(raw);
    if (compressed == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not decode this image. Use JPG, PNG, or WebP.',
            ),
          ),
        );
      }
      return;
    }

    final name = file.name.trim().isNotEmpty ? file.name : 'upload.jpg';
    final url = await ref.read(adminServiceProvider).uploadHomepageImage(
          folder: storageFolder,
          bytes: compressed,
          fileName: name,
        )
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () => throw TimeoutException(
            'Upload timed out. Check your network and that storage allows uploads.',
          ),
        );

    onUploaded(url);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(e))),
      );
    }
  } finally {
    if (context.mounted) {
      setUploading(false);
    }
  }
}
