import 'package:google_ml_kit/google_ml_kit.dart';

class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  Future<String> extractText(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognized =
          await textRecognizer.processImage(inputImage);
      return _cleanText(recognized.text);
    } catch (_) {
      return '';
    } finally {
      await textRecognizer.close();
    }
  }

  String _cleanText(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }
}
