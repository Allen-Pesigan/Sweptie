import 'package:google_ml_kit/google_ml_kit.dart';

class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  /// Extracts text from an image at [filePath].
  /// Returns an empty string if no text is found or an error occurs.
  Future<String> extractText(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognized =
          await textRecognizer.processImage(inputImage);
      return recognized.text;
    } catch (_) {
      return '';
    } finally {
      await textRecognizer.close();
    }
  }
}
