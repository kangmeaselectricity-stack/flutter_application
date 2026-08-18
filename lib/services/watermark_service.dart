import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'location_service.dart';

class WatermarkService {
  // 🎯 មុខងារគូរត្រា Location UTM + Watermark
  static Future<File> drawWatermark(
    File imageFile,
    Map<String, dynamic> cust,
    String finalNumber, {
    bool isPowerData =
        false, // 🎯 ប្រសិនបើ true = PowerDataScreen, false = HomeScreen (រក្សាដដែល)
  }) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      canvas.drawImage(image, Offset.zero, Paint());

      String utmCoords = await LocationService.getUTMCoordinates();
      String meterId = cust['meter']?.toString().trim() ?? 'មិនស្គាល់';
      String dateStr = DateTime.now().toString().split('.')[0];

      String line2Text = "";

      if (isPowerData) {
        // 🎯 សម្រាប់ PowerDataScreen ៖ "អត្តលេខ: [code]-[village]"
        String code = cust['code']?.toString().trim() ?? 'មិនស្គាល់';
        String village =
            cust['display_village']?.toString().trim() ??
            cust['village']?.toString().trim() ??
            'មិនស្គាល់';
        line2Text = "អត្តលេខ: $code-$village";
      } else {
        // 🎯 សម្រាប់ HomeScreen ៖ "អតិថិជន: [ឈ្មោះ]" (រក្សាដដែល ១០០%)
        String customerName = cust['name']?.toString().trim() ?? 'មិនស្គាល់';
        line2Text = "អតិថិជន: $customerName";
      }

      String textToDraw =
          "នាឡិកាស្ទង់: $meterId\n$line2Text\nUTM: $utmCoords\nថ្ងៃស្រង់: $dateStr";

      double fontSize = image.width * 0.04;

      // --- ១. គូរស្រមោលអក្សរពណ៌ខ្មៅ (Offset ងាក 3px) ---
      final ui.ParagraphBuilder shadowBuilder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: TextAlign.left,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            )
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000)))
            ..addText(textToDraw);

      final ui.Paragraph shadowParagraph = shadowBuilder.build();
      shadowParagraph.layout(
        ui.ParagraphConstraints(width: image.width.toDouble()),
      );

      canvas.drawParagraph(
        shadowParagraph,
        Offset(27, image.height - shadowParagraph.height - 32),
      );

      // --- ២. គូរអក្សរពិតពណ៌លឿងចែសពីលើ ---
      final ui.ParagraphBuilder textBuilder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: TextAlign.left,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            )
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFF00)))
            ..addText(textToDraw);

      final ui.Paragraph textParagraph = textBuilder.build();
      textParagraph.layout(
        ui.ParagraphConstraints(width: image.width.toDouble()),
      );

      canvas.drawParagraph(
        textParagraph,
        Offset(24, image.height - textParagraph.height - 35),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image imgWithWatermark = await picture.toImage(
        image.width,
        image.height,
      );
      final ByteData? byteData = await imgWithWatermark.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        await imageFile.writeAsBytes(
          byteData.buffer.asUint8List(),
          flush: true,
        );
        debugPrint("✅ បោះត្រា Watermark រួចរាល់!");
      }
    } catch (e) {
      debugPrint("❌ Watermark Error: $e");
    }
    return imageFile;
  }

  // 🎯 មុខងាររក្សាទុករូបភាពចូល Gallery
  static Future<void> askToSaveImage(
    BuildContext context,
    File originalFile,
    String code,
    String customerName,
  ) async {
    try {
      if (!context.mounted) return;

      // 🚀 បង្ហាញផ្ទាំង Dialog សួរបញ្ជាក់ចង់រក្សាទុក (Yes/No)
      bool? shouldSave = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.save_alt, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text(
                  "រក្សាទុករូបភាព",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              "តើអ្នកចង់រក្សាទុករូបភាពរបស់អតិថិជន $customerName ($code) ចូលក្នុងទូរស័ព្ទដែរឬទេ?",
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "ទេ (No)",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "រក្សាទុក (Yes)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (shouldSave != true) {
        debugPrint("💾 អ្នកប្រើប្រាស់បានបដិសេធមិនរក្សាទុករូបភាព។");
        return;
      }

      await Gal.putImage(originalFile.path, album: "Meter_Readings");

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.photo_library, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "🖼️ បានរក្សាទុករូបភាព ($code) ចូលក្នុង Gallery ជោគជ័យ!",
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint("❌ Save Image Error: $e");
    }
  }
}
