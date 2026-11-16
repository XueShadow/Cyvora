import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

Future<String?> extractScreenshotText() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    throw UnsupportedError(
      'Screenshot text extraction is currently available on Android and iOS.',
    );
  }

  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 90,
  );
  if (image == null) return null;

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(image.path),
    );
    return result.text;
  } finally {
    await recognizer.close();
    if (await File(image.path).exists()) {
      await File(image.path).delete();
    }
  }
}
