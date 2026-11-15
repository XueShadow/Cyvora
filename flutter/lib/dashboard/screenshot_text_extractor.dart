import 'screenshot_text_extractor_stub.dart'
    if (dart.library.io) 'screenshot_text_extractor_io.dart'
    if (dart.library.js_interop) 'screenshot_text_extractor_web.dart'
    as extractor;

Future<String?> extractScreenshotText() => extractor.extractScreenshotText();
