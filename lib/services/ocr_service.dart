import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> scanTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String finalNumber = "";
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          String clean = line.text.replaceAll(RegExp(r'[^0-9.]'), '');
          if (clean.isNotEmpty) {
            finalNumber = clean;
            break;
          }
        }
        if (finalNumber.isNotEmpty) {
          break;
        }
      }

      if (finalNumber.isEmpty && recognizedText.text.trim().isNotEmpty) {
        finalNumber = recognizedText.text.trim().replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
      }

      return finalNumber;
    } catch (e) {
      debugPrint("❌ OCR Error: $e");
      return "";
    }
  }

  Future<List<Map<String, dynamic>>> recognizeTextLines(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      List<Map<String, dynamic>> results = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          results.add({
            'text': line.text,
            'boundingBox': line.boundingBox,
          });
        }
      }
      return results;
    } catch (e) {
      debugPrint("❌ OCR Line Recognition Error: $e");
      return [];
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
