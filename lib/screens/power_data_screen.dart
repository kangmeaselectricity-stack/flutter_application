import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../database_service.dart';
import '../services/camera_service.dart';
import '../services/ocr_service.dart';
import '../services/watermark_service.dart';
import 'google_lens_screen.dart';

class PowerDataScreen extends StatefulWidget {
  final bool filterRemaining;
  final String? initialCode;

  const PowerDataScreen({
    super.key,
    this.filterRemaining = false,
    this.initialCode,
  });

  @override
  State<PowerDataScreen> createState() => _PowerDataScreenState();
}

class _PowerDataScreenState extends State<PowerDataScreen> {
  List<Map<String, dynamic>> allPowerData = [];
  List<Map<String, dynamic>> filteredPowerData = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();
  bool filterRemaining = false;
  String? selectedCode;

  final Map<String, TextEditingController> controllers = {};
  final Map<String, FocusNode> focusNodes = {};
  final Map<String, double> calculatedUsage = {};
  String latestMonthDisplay = "";
  String _currentMode = "camera";

  final OcrService _ocrService = OcrService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _listeningIdKey = "";

  @override
  void initState() {
    super.initState();
    filterRemaining = widget.filterRemaining;
    selectedCode = widget.initialCode;
    _loadPowerData();
    _loadInputMode();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    searchController.dispose();
    for (var c in controllers.values) {
      c.dispose();
    }
    for (var f in focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInputMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentMode = prefs.getString('input_mode') ?? "camera";
      });
    }
  }

  Future<void> _loadPowerData() async {
    try {
      setState(() => isLoading = true);
      final db = await DatabaseService().database;

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='power_data';",
      );

      if (tables.isEmpty) {
        setState(() {
          allPowerData = [];
          filteredPowerData = [];
          isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> rawData = await db.query('power_data');
      latestMonthDisplay = "";

      controllers.clear();
      focusNodes.clear();
      calculatedUsage.clear();

      List<Map<String, dynamic>> mutableData = [];
      String lastValidVillage = "";
      String lastValidPole = "";

      for (int i = 0; i < rawData.length; i++) {
        var row = Map<String, dynamic>.from(rawData[i]);

        if (row['village'] != null &&
            row['village'].toString().trim().isNotEmpty) {
          lastValidVillage = row['village'].toString().trim();
        }
        if (row['pole'] != null && row['pole'].toString().trim().isNotEmpty) {
          lastValidPole = row['pole'].toString().trim();
        }

        row['display_village'] =
            row['village'] != null &&
                row['village'].toString().trim().isNotEmpty
            ? row['village']
            : lastValidVillage;
        row['display_pole'] =
            row['pole'] != null && row['pole'].toString().trim().isNotEmpty
            ? row['pole']
            : lastValidPole;

        String idKey = "row_${row['meter']}_$i";
        String currentNewVal = row['new_value']?.toString() ?? "";

        controllers[idKey] = TextEditingController(text: currentNewVal);
        focusNodes[idKey] = FocusNode();

        double ov = double.tryParse(row['old_value']?.toString() ?? '0') ?? 0;
        double nv = double.tryParse(currentNewVal) ?? 0;
        double m = double.tryParse(row['miti']?.toString() ?? '1') ?? 1.0;

        if (currentNewVal.isNotEmpty) {
          calculatedUsage[idKey] = _calculateUsageLogic(ov, nv, m);
        }

        row['_idKey'] = idKey;
        mutableData.add(row);
      }

      mutableData.sort(
        (a, b) => (a['display_pole']?.toString() ?? "").compareTo(
          b['display_pole']?.toString() ?? "",
        ),
      );

      setState(() {
        allPowerData = mutableData;
        isLoading = false;
      });
      _runFilter();
    } catch (e) {
      debugPrint("❌ កំហុសក្នុងការទាញ power_data៖ $e");
      setState(() => isLoading = false);
    }
  }

  double _calculateUsageLogic(
    double oldValue,
    double newValue,
    double multiplier,
  ) {
    if (newValue >= oldValue) {
      return (newValue - oldValue) * multiplier;
    } else {
      return ((100000 - oldValue) + newValue) * multiplier;
    }
  }

  void _runFilter([String? queryParam]) {
    String query = (queryParam ?? searchController.text).toLowerCase().trim();
    List<Map<String, dynamic>> results = List.from(allPowerData);

    if (query.isNotEmpty) {
      results = results.where((row) {
        final village = row['display_village']?.toString().toLowerCase() ?? "";
        final meter = row['meter']?.toString().toLowerCase() ?? "";
        final code = row['code']?.toString().toLowerCase() ?? "";
        final pole = row['display_pole']?.toString().toLowerCase() ?? "";
        return village.contains(query) ||
            meter.contains(query) ||
            code.contains(query) ||
            pole.contains(query);
      }).toList();
    }

    if (selectedCode != null) {
      results = results.where((row) {
        final code = row['code']?.toString() ?? "";
        return code == selectedCode;
      }).toList();
    }

    if (filterRemaining) {
      results = results.where((row) {
        String newVal = row['new_value']?.toString() ?? "";
        return newVal.isEmpty;
      }).toList();
    }

    setState(() {
      filteredPowerData = results;
    });
  }

  Future<void> _saveReading(
    String idKey,
    String value,
    Map<String, dynamic> row,
  ) async {
    try {
      final db = await DatabaseService().database;
      double? parsedNewValue = double.tryParse(value);

      String currentCode = row['code']?.toString() ?? "";
      String currentMeter = row['meter']?.toString().trim() ?? "";
      String currentMonth = row['month']?.toString().trim() ?? "";
      double oldVal =
          double.tryParse(row['old_value']?.toString() ?? '0') ?? 0.0;

      if (currentMeter.isEmpty) {
        return;
      }

      await db.update(
        'power_data',
        {'new_value': parsedNewValue ?? 0.0},
        where: 'code = ? AND meter = ? AND month = ? AND old_value = ?',
        whereArgs: [currentCode, currentMeter, currentMonth, oldVal],
      );

      double ov = oldVal;
      double m = double.tryParse(row['miti']?.toString() ?? '1') ?? 1.0;

      setState(() {
        row['new_value'] = value;
        if (value.isNotEmpty && parsedNewValue != null) {
          calculatedUsage[idKey] = _calculateUsageLogic(ov, parsedNewValue, m);
        } else {
          calculatedUsage.remove(idKey);
        }
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "💾 រក្សាទុកនាឡិកាស្ទង់ [ $currentMeter ] ចំនួន $value ជោគជ័យ!",
          ),
          backgroundColor: Colors.teal,
          duration: const Duration(milliseconds: 700),
        ),
      );
    } catch (e) {
      debugPrint("❌ កំហុសក្នុងការរក្សាទុក៖ $e");
    }
  }

  Future<void> _triggerVoiceRecognition(
    String idKey,
    Map<String, dynamic> row,
  ) async {
    FocusScope.of(context).unfocus();

    bool available = await _speech.initialize();
    if (!available) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ មិនអាចបើកប្រព័ន្ធស្រង់សំឡេងបានទេ")),
      );
      return;
    }

    setState(() {
      _listeningIdKey = idKey;
    });

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "🎙️ កំពុងស្តាប់សំឡេង... សូមនិយាយលេខអំណានថ្មីជាភាសាខ្មែរ",
        ),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 4),
      ),
    );

    _speech.listen(
      listenOptions: stt.SpeechListenOptions(partialResults: false),
      localeId: "km_KH",
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          String cleanNumber = result.recognizedWords.replaceAll(
            RegExp(r'[^0-9.]'),
            '',
          );

          if (cleanNumber.isNotEmpty) {
            setState(() {
              controllers[idKey]?.text = cleanNumber;
            });
            _saveReading(idKey, cleanNumber, row);
          }
        }
        setState(() => _listeningIdKey = "");
      },
    );
  }

  // 🎯 មុខងារ Camera OCR ដោះ Focus រួចហៅ Pop-up កាមេរ៉ា និងបោះត្រារក្សាទុកក្នុង Gallery
  Future<void> _triggerCameraOCR(String idKey, Map<String, dynamic> row) async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));

    // ១. ថត និង Crop រូបភាព
    File? croppedImage = await CameraService.captureAndCrop();
    if (croppedImage == null) {
      return;
    }

    // ២. ហៅផ្ទាំង Google Lens Screen ដើម្បីជ្រើសរើសលេខ
    if (!mounted) return;
    String? selectedNumber = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => GoogleLensScreen(
          imageFile: croppedImage,
          customerName:
              row['display_village']?.toString() ??
              row['village']?.toString() ??
              "Unknown",
          customerCode:
              row['code']?.toString() ?? row['meter']?.toString() ?? "Unknown",
        ),
      ),
    );

    if (selectedNumber == null || selectedNumber.isEmpty) {
      // អ្នកប្រើប្រាស់បដិសេធ ឬមិនជ្រើសរើសលេខ
      return;
    }

    String scannedNumber = selectedNumber;

    setState(() {
      controllers[idKey]?.text = scannedNumber;
    });

    // ៣. រក្សាទុកអំណានចូល SQLite
    await _saveReading(idKey, scannedNumber, row);

    // ៤. បោះត្រា Location UTM + "អត្តលេខ: [code]-[village]" ពណ៌លឿង
    File watermarkedFile = await WatermarkService.drawWatermark(
      croppedImage,
      row,
      scannedNumber,
      isPowerData:
          true, // 🎯 ដាក់ true ដើម្បីប្រើទម្រង់ អត្តលេខ: [code]-[village]
    );

    if (!mounted) {
      return;
    }

    // ៥. រក្សាទុករូបភាពចូល Gallery (Album: Meter_Readings)
    await WatermarkService.askToSaveImage(
      context,
      watermarkedFile,
      row['code']?.toString() ?? row['meter']?.toString() ?? "Master_Meter",
      row['display_village']?.toString() ?? "Unknown",
    );
  }

  void _showHistoryDialog(Map<String, dynamic> row) {
    double historyDistribute =
        double.tryParse(row['distribute']?.toString() ?? '0.0') ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              "ប្រវត្តិប្រើប្រាស់",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "តំបន់៖ ${row['display_village'] ?? '---'}",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "លេខនាឡិកាស្ទង់៖ ${row['meter'] ?? '---'}",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "ខែស្រង់៖ ${row['month'] ?? '---'}",
              style: const TextStyle(fontSize: 14),
            ),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ថាមពលខែមុន (distribute)៖",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  "${historyDistribute.toStringAsFixed(2)} kWh",
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បិទ", style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          latestMonthDisplay.isNotEmpty
              ? "ស្រង់នាឡិកាស្ទង់មេ (ខែ៖ ${DateTime.now().toString().split(' ')[0]})"
              : "ស្រង់អំណាននាឡិកាស្ទង់មេ",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, color: Colors.white),
            tooltip: "ជ្រើសរើសប្រព័ន្ធបញ្ចូលលេខ",
            onSelected: (mode) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('input_mode', mode);
              setState(() => _currentMode = mode);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "camera",
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, color: Colors.green),
                    SizedBox(width: 8),
                    Text("ប្រើប្រាស់កាមេរ៉ា (OCR)"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: "voice",
                child: Row(
                  children: [
                    Icon(Icons.mic, color: Colors.red),
                    SizedBox(width: 8),
                    Text("ប្រើប្រាស់សំឡេង (Voice)"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: "manual",
                child: Row(
                  children: [
                    Icon(Icons.keyboard, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("វាយបញ្ចូលដោយដៃ"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "ស្វែងរកតំបន់, លេខបង្គោល ឬលេខនាឡិកាស្ទង់...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _runFilter,
            ),
          ),
          if (filterRemaining || selectedCode != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "បង្ហាញតែនាឡិកាមេនៅសល់${selectedCode != null ? " អត្តលេខ $selectedCode" : ""}",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          filterRemaining = false;
                          selectedCode = null;
                        });
                        _runFilter();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.orange,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : filteredPowerData.isEmpty
                ? const Center(
                    child: Text("⚠️ គ្មានទិន្នន័យនាឡិកាមេសម្រាប់ខែនេះទេ"),
                  )
                : ListView.builder(
                    itemCount: filteredPowerData.length,
                    itemBuilder: (context, index) {
                      final row = filteredPowerData[index];
                      final idKey = row['_idKey'] ?? index.toString();

                      double oldVal =
                          double.tryParse(
                            row['old_value']?.toString() ?? '0',
                          ) ??
                          0.0;
                      double multiplier =
                          double.tryParse(row['miti']?.toString() ?? '1') ??
                          1.0;

                      Widget suffixIconWidget;
                      if (_currentMode == "voice") {
                        bool isThisListening = _listeningIdKey == idKey;
                        suffixIconWidget = IconButton(
                          icon: Icon(
                            Icons.mic,
                            color: isThisListening
                                ? Colors.red
                                : Colors.blueGrey,
                          ),
                          onPressed: () => _triggerVoiceRecognition(idKey, row),
                        );
                      } else if (_currentMode == "camera") {
                        suffixIconWidget = IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.green,
                          ),
                          onPressed: () => _triggerCameraOCR(idKey, row),
                        );
                      } else {
                        suffixIconWidget = const Icon(
                          Icons.keyboard,
                          color: Colors.blue,
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (_currentMode == "camera") {
                              _triggerCameraOCR(idKey, row);
                            } else if (_currentMode == "voice") {
                              _triggerVoiceRecognition(idKey, row);
                            } else {
                              focusNodes[idKey]?.requestFocus();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.pin_drop,
                                          color: Colors.indigo,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "បង្គោល៖ ${row['display_pole'] ?? '---'}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "មេគុណ៖ $multiplier",
                                        style: const TextStyle(
                                          color: Colors.teal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Text(
                                  "តំបន់៖ ${row['display_village'] ?? '---'}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "អត្តលេខ៖ ${row['code'] ?? '---'}  |  នាឡិកាស្ទង់៖ ${row['meter'] ?? '---'}",
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "អំណានចាស់",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            "$oldVal",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: controllers[idKey],
                                        focusNode: focusNodes[idKey],
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textInputAction: TextInputAction.done,
                                        decoration: InputDecoration(
                                          labelText: "វាយអំណានថ្មី",
                                          labelStyle: const TextStyle(
                                            fontSize: 13,
                                          ),
                                          border: const OutlineInputBorder(),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 10,
                                              ),
                                          suffixIcon: suffixIconWidget,
                                        ),
                                        onChanged: (val) {
                                          double? nv = double.tryParse(val);
                                          setState(() {
                                            if (val.isNotEmpty && nv != null) {
                                              calculatedUsage[idKey] =
                                                  _calculateUsageLogic(
                                                    oldVal,
                                                    nv,
                                                    multiplier,
                                                  );
                                            } else {
                                              calculatedUsage.remove(idKey);
                                            }
                                          });
                                          _saveReading(idKey, val, row);
                                        },
                                        onSubmitted: (val) =>
                                            _saveReading(idKey, val, row),
                                      ),
                                    ),
                                  ],
                                ),
                                if (calculatedUsage.containsKey(idKey)) ...[
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () => _showHistoryDialog(row),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.red.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.bolt,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "ថាមពលសរុប៖ ${calculatedUsage[idKey]!.toStringAsFixed(2)} kWh",
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Icon(
                                            Icons.info_outline,
                                            color: Colors.red,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
