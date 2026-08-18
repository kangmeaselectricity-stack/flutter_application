import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/ocr_service.dart';

class GoogleLensScreen extends StatefulWidget {
  final File imageFile;
  final String customerName;
  final String customerCode;

  const GoogleLensScreen({
    super.key,
    required this.imageFile,
    required this.customerName,
    required this.customerCode,
  });

  @override
  State<GoogleLensScreen> createState() => _GoogleLensScreenState();
}

class _GoogleLensScreenState extends State<GoogleLensScreen> {
  int _imageWidth = 0;
  int _imageHeight = 0;
  List<Map<String, dynamic>> _detectedLines = [];
  bool _isLoading = true;
  String _selectedText = "";
  final TextEditingController _textController = TextEditingController();
  final OcrService _ocrService = OcrService();

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _processImage() async {
    try {
      // ១. ស្វែងរកទំហំពិតរបស់រូបភាព
      final Uint8List bytes = await widget.imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // ២. ស្កេនអក្សរ និងទីតាំង Bounding Box
      final lines = await _ocrService.recognizeTextLines(widget.imageFile.path);

      if (mounted) {
        setState(() {
          _imageWidth = image.width;
          _imageHeight = image.height;
          _detectedLines = lines;
          _isLoading = false;
        });

        // ស្វែងរកលេខកុងទ័រដំបូងគេជាស្វ័យប្រវត្ត ដើម្បីសម្រួលដល់អ្នកប្រើប្រាស់
        for (var line in lines) {
          String text = line['text'] as String;
          String clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
          if (clean.isNotEmpty && clean.length >= 3) {
            setState(() {
              _selectedText = text;
              _textController.text = clean;
            });
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error GoogleLensScreen processing: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "ស្កេន និងជ្រើសរើសលេខ (Google Lens)",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 16),
                  Text(
                    "កំពុងវិភាគរូបភាព...",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ផ្នែកបង្ហាញរូបថត និងប្រអប់ជ្រើសរើសលេខ
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (_imageWidth == 0 || _imageHeight == 0) {
                        return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                      }

                      // គណនាទំហំការបង្ហាញរូបភាពក្នុង BoxFit.contain
                      final double imageRatio = _imageWidth / _imageHeight;
                      final double screenRatio = constraints.maxWidth / constraints.maxHeight;

                      double displayWidth, displayHeight;
                      double offsetX = 0, offsetY = 0;

                      if (imageRatio > screenRatio) {
                        displayWidth = constraints.maxWidth;
                        displayHeight = constraints.maxWidth / imageRatio;
                        offsetY = (constraints.maxHeight - displayHeight) / 2;
                      } else {
                        displayHeight = constraints.maxHeight;
                        displayWidth = constraints.maxHeight * imageRatio;
                        offsetX = (constraints.maxWidth - displayWidth) / 2;
                      }

                      final double scaleX = displayWidth / _imageWidth;
                      final double scaleY = displayHeight / _imageHeight;

                      return Stack(
                        children: [
                          // រូបភាព
                          Positioned.fill(
                            child: Image.file(
                              widget.imageFile,
                              fit: BoxFit.contain,
                            ),
                          ),

                          // ប្រអប់អក្សរដែលស្កេនឃើញ (Bounding Boxes)
                          for (var line in _detectedLines) ...[
                            () {
                              final String text = line['text'] as String;
                              final Rect box = line['boundingBox'] as Rect;

                              final double left = offsetX + box.left * scaleX;
                              final double top = offsetY + box.top * scaleY;
                              final double width = box.width * scaleX;
                              final double height = box.height * scaleY;

                              final String cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
                              final bool isSelected = _selectedText == text;

                              return Positioned(
                                left: left,
                                top: top,
                                width: width,
                                height: height,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedText = text;
                                      _textController.text = cleaned;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      // ignore: deprecated_member_use
                                      color: isSelected
                                          // ignore: deprecated_member_use
                                          ? Colors.blue.withOpacity(0.35)
                                          // ignore: deprecated_member_use
                                          : Colors.yellow.withOpacity(0.2),
                                      border: Border.all(
                                        color: isSelected ? Colors.blueAccent : Colors.yellow.shade700,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              );
                            }(),
                          ],

                          // ជំនួយណែនាំ
                          Positioned(
                            top: 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.touch_app, color: Colors.yellow, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    "ចុចលើប្រអប់ព័ណ៌លឿង ដើម្បីជ្រើសរើសលេខ",
                                    style: TextStyle(color: Colors.white, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // ផ្នែកផ្ទាំងបញ្ជាខាងក្រោម
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ព័ត៌មានអតិថិជន
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.customerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                // ignore: deprecated_member_use
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blueAccent, width: 0.5),
                              ),
                              child: Text(
                                "កូដ: ${widget.customerCode}",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_selectedText.isNotEmpty)
                          Text(
                            "អត្ថបទដែលបានជ្រើសរើស៖ \"$_selectedText\"",
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        const SizedBox(height: 14),

                        // ប្រអប់បញ្ចូលលេខអំណានថ្មី
                        TextField(
                          controller: _textController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: "អំណាននាឡិកាស្ទង់ថ្មី",
                            labelStyle: const TextStyle(color: Colors.blueAccent, fontSize: 14),
                            hintText: "សូមវាយបញ្ចូល ឬចុចជ្រើសរើសលេខលើរូបភាព",
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70),
                              onPressed: () => _textController.clear(),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade700),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // គ្រាប់ចុចបញ្ជា (បោះបង់ / រក្សាទុក)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(color: Colors.grey.shade700),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text("បោះបង់ (Cancel)"),
                                onPressed: () {
                                  Navigator.pop(context, null);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text("រក្សាទុក (Save)"),
                                onPressed: () {
                                  final val = _textController.text.trim();
                                  if (val.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("⚠️ សូមវាយបញ្ចូល ឬជ្រើសរើសលេខជាមុនសិន!"),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context, val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
