import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  Future<bool> initSpeech() async {
    return await _speech.initialize();
  }

  void listen({required Function(String) onResult}) {
    _speech.listen(
      localeId: "km_KH",
      onResult: (result) {
        String cleanNumber = convertToArabicNumbers(result.recognizedWords);
        if (cleanNumber.isNotEmpty) {
          onResult(cleanNumber);
        }
      },
    );
  }

  void stop() {
    _speech.stop();
  }

  String convertToArabicNumbers(String input) {
    const Map<String, String> khmerToArabic = {
      'សូន្យ': '0',
      'មួយ': '1',
      'ពីរ': '2',
      'បី': '3',
      'បួន': '4',
      'ប្រាំ': '5',
      'ប្រាំមួយ': '6',
      'ប្រាំពីរ': '7',
      'ប្រាំបួន': '9',
      '១': '1',
      '២': '2',
      '៣': '3',
      '៤': '4',
      '៥': '5',
      '៦': '6',
      '៧': '7',
      '៨': '8',
      '៩': '9',
      '០': '0',
      'ចុច': '.',
      'ដក់': '.',
    };

    String result = input;
    khmerToArabic.forEach((kh, ar) => result = result.replaceAll(kh, ar));
    return result.replaceAll(RegExp(r'[^0-9.]'), '');
  }
}
