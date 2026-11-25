import 'dart:js_interop';

import 'package:image_picker/image_picker.dart';

@JS('cyvoraExtractScreenshotText')
external JSPromise<JSString> _cyvoraExtractScreenshotText(
  JSUint8Array imageBytes,
);

Future<String?> extractScreenshotText() async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 90,
  );
  if (image == null) return null;

  final bytes = await image.readAsBytes();
  if (bytes.isEmpty) {
    throw StateError('The selected screenshot is empty.');
  }
  if (bytes.length > 12 * 1024 * 1024) {
    throw StateError('Choose a screenshot smaller than 12 MB.');
  }

  final text = await _cyvoraExtractScreenshotText(bytes.toJS).toDart;
  return text.toDart;
}
