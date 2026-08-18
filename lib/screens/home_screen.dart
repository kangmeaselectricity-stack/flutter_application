import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide TextSpan, Border;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../database_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/filter_area.dart';
import '../widgets/customer_card.dart';

import '../services/camera_service.dart';
import '../services/ocr_service.dart';
import '../services/watermark_service.dart';
import '../services/meter_ble_service.dart';
import 'google_lens_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool filterRemaining;
  const HomeScreen({super.key, this.filterRemaining = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> allCustomers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  bool isLoading = true;
  bool isSearching = false;
  bool _isRolloverWarning = false;
  String _warningMessage = "";

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _activeCode = "";
  String _inputMode = 'manual';
  String _listeningCustomerName = "";

  final TextEditingController searchController = TextEditingController();
  final Map<String, TextEditingController> controllers = {};
  final Map<String, FocusNode> focusNodes = {};
  final Map<String, TextEditingController> multiplierControllers = {};
  final Map<String, double> previewUsage = {};

  final OcrService _ocrService = OcrService();

  int totalCount = 0;
  int doneCount = 0;

  String? selectedArea;
  String? selectedPole;
  String? selectedBox;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _speech = stt.SpeechToText();
    _refreshData();
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
    for (var m in multiplierControllers.values) {
      m.dispose();
    }
    super.dispose();
  }

  String _convertToArabicNumbers(String input) {
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

  void _listenToVoice(String code) async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _activeCode = code;
      });
      _speech.listen(
        localeId: "km_KH",
        onResult: (result) {
          String cleanNumber = _convertToArabicNumbers(result.recognizedWords);
          if (cleanNumber.isNotEmpty) {
            setState(() {
              controllers[code]?.text = cleanNumber;
              _updatePreview(code, cleanNumber);
            });
            final cust = filteredCustomers.firstWhere(
              (e) => e['code'].toString() == code,
              orElse: () => {},
            );
            if (cust.isNotEmpty) {
              _handleSave(code, controllers[code]?.text ?? "", cust);
            }
          }
        },
      );
    }
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isListening = false);
      }
    });
  }

  Future<void> _captureAndScan(String code) async {
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ សូមជ្រើសរើសអតិថិជនម្នាក់ជាមុនសិន!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ១. ថតរូប និង Crop
    File? croppedImage = await CameraService.captureAndCrop();
    if (croppedImage == null) return;

    final cust = allCustomers.firstWhere(
      (e) => e['code'].toString() == code,
      orElse: () => {},
    );

    if (cust.isEmpty) return;

    // ២. ហៅផ្ទាំង Google Lens Screen ដើម្បីជ្រើសរើសលេខ
    if (!mounted) return;
    String? selectedNumber = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => GoogleLensScreen(
          imageFile: croppedImage,
          customerName: cust['name']?.toString() ?? "Unknown",
          customerCode: code,
        ),
      ),
    );

    if (selectedNumber == null || selectedNumber.isEmpty) {
      // អ្នកប្រើប្រាស់បដិសេធ ឬមិនជ្រើសរើសលេខ
      return;
    }

    String scannedNumber = selectedNumber;

    setState(() {
      controllers[code]?.text = scannedNumber;
      _updatePreview(code, scannedNumber);
    });

    // ៣. រក្សាទុកលេខចូល Database
    await DatabaseService().updateReading(code, scannedNumber);

    // 🎯 ៤. ហៅបោះត្រា Watermark + Location GPS លើរូបភាព
    File watermarkedFile = await WatermarkService.drawWatermark(
      croppedImage,
      cust,
      scannedNumber,
    );

    if (!mounted) return;

    // 🎯 ៥. រក្សាទុករូបភាពដែលបោះត្រារួច
    await WatermarkService.askToSaveImage(
      context,
      watermarkedFile,
      code,
      cust['name'] ?? "Unknown",
    );

    _handleSave(code, scannedNumber, cust);
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

  void _updatePreview(String code, String value) {
    final newVal = double.tryParse(value) ?? 0;
    final cust = allCustomers.firstWhere(
      (e) => e['code'].toString() == code,
      orElse: () => {},
    );
    if (cust.isEmpty) {
      return;
    }

    final oldVal = double.tryParse(cust['old_value']?.toString() ?? '0') ?? 0;
    final multiplier =
        double.tryParse(multiplierControllers[code]?.text ?? '1') ?? 1.0;

    setState(() {
      previewUsage[code] = _calculateUsageLogic(oldVal, newVal, multiplier);
    });
  }

  Future<void> _handleSave(
    String code,
    String value,
    Map<String, dynamic> cust,
  ) async {
    final double multiplier =
        double.tryParse(multiplierControllers[code]?.text ?? '1') ?? 1.0;

    // Save multiplier to database
    await DatabaseService().updateMultiplier(code, multiplier);

    setState(() {
      cust['multiplier'] = multiplier;
    });

    final String actualValue = controllers[code]?.text ?? "";
    if (actualValue.isEmpty) {
      _updatePreview(code, "");
      runFilter();
      return;
    }

    final double? currentNew = double.tryParse(actualValue);
    if (currentNew == null) {
      return;
    }

    final double oldVal =
        double.tryParse(
          cust['old_value']?.toString() ?? cust['old']?.toString() ?? '0',
        ) ??
        0;

    if (currentNew < oldVal && currentNew > 0) {
      setState(() {
        _isRolloverWarning = true;
        _warningMessage =
            "⚠️ លេខថ្មី ($currentNew) តូចជាងលេខចាស់ ($oldVal)៖ ប្រព័ន្ធគណនាជាការវិលជុំ!";
      });
    } else {
      setState(() {
        _isRolloverWarning = false;
      });
    }

    final int result = await DatabaseService().updateReading(code, actualValue);
    if (!mounted) {
      return;
    }

    if (result > 0) {
      final double usageResult = _calculateUsageLogic(
        oldVal,
        currentNew,
        multiplier,
      );

      setState(() {
        cust['new_value'] = actualValue;
        cust['new'] = actualValue;
        previewUsage[code] = usageResult;
      });

      runFilter();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ បានរក្សាទុកលេខ [$actualValue] ចូលដាតាបេសជោគជ័យ!"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  List<String> get availableAreas =>
      allCustomers
          .map((e) => e['area']?.toString() ?? "")
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<String> get availablePoles {
    var list = allCustomers;
    if (selectedArea != null) {
      list = list.where((e) => e['area'] == selectedArea).toList();
    }
    return list
        .map((e) => e['pole']?.toString() ?? "")
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get availableBoxes {
    var list = allCustomers;
    if (selectedArea != null) {
      list = list.where((e) => e['area'] == selectedArea).toList();
    }
    if (selectedPole != null) {
      list = list.where((e) => e['pole'] == selectedPole).toList();
    }
    return list
        .map((e) => e['box']?.toString() ?? "")
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    final data = await DatabaseService().getCustomers();

    for (var cust in data) {
      String code = cust['code'].toString();
      String currentNewVal =
          cust['new_value']?.toString() ?? cust['new']?.toString() ?? "";

      if (!controllers.containsKey(code)) {
        controllers[code] = TextEditingController(text: currentNewVal);
      } else {
        controllers[code]!.text = currentNewVal;
      }
      if (!focusNodes.containsKey(code)) {
        focusNodes[code] = FocusNode();
      }

      String mVal = "1";
      if (cust['multiplier'] != null) {
        double mDouble = double.tryParse(cust['multiplier'].toString()) ?? 1.0;
        mVal = mDouble == mDouble.toInt() ? mDouble.toInt().toString() : mDouble.toString();
      }

      if (!multiplierControllers.containsKey(code)) {
        multiplierControllers[code] = TextEditingController(text: mVal);
      } else {
        multiplierControllers[code]!.text = mVal;
      }

      if (currentNewVal.isNotEmpty) {
        final nv = double.tryParse(currentNewVal) ?? 0;
        final ov = double.tryParse(cust['old_value']?.toString() ?? '0') ?? 0;
        final m = double.tryParse(cust['multiplier']?.toString() ?? '1') ?? 1.0;
        previewUsage[code] = _calculateUsageLogic(ov, nv, m);
      }
    }

    if (mounted) {
      setState(() {
        allCustomers = data;
        if (widget.filterRemaining) {
          filteredCustomers = data.where((cust) {
            String newVal =
                cust['new']?.toString().trim() ??
                cust['new_value']?.toString().trim() ??
                "";
            return newVal.isEmpty;
          }).toList();
        } else {
          filteredCustomers = List.from(data);
        }

        isLoading = false;
        if (!widget.filterRemaining) {
          runFilter();
        }
      });

      if (widget.filterRemaining) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "🔍 បានចម្រោះបង្ហាញតែអតិថិជននៅសល់ចំនួន ${filteredCustomers.length} នាក់",
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void runFilter() {
    List<Map<String, dynamic>> results = List.from(allCustomers);
    String query = searchController.text.toLowerCase().trim();

    if (query.isNotEmpty) {
      results = results.where((c) {
        return c['name'].toString().toLowerCase().contains(query) ||
            c['meter'].toString().toLowerCase().contains(query) ||
            c['code'].toString().toLowerCase().contains(query);
      }).toList();
    }

    if (selectedArea != null) {
      results = results.where((c) => c['area'] == selectedArea).toList();
    }
    if (selectedPole != null) {
      results = results.where((c) => c['pole'] == selectedPole).toList();
    }
    if (selectedBox != null) {
      results = results.where((c) => c['box'] == selectedBox).toList();
    }

    if (widget.filterRemaining) {
      results = results.where((cust) {
        String newVal =
            cust['new']?.toString().trim() ??
            cust['new_value']?.toString().trim() ??
            "";
        return newVal.isEmpty;
      }).toList();
    }

    setState(() {
      filteredCustomers = results;
      totalCount = allCustomers.length;
      doneCount = allCustomers.where((item) {
        var val = item['new_value'] ?? item['new'];
        if (val == null || val.toString().isEmpty) {
          return false;
        }
        final parsedVal = double.tryParse(val.toString()) ?? 0;
        return parsedVal > 0;
      }).length;
    });
  }

  void _selectCustomer(String code, String name) {
    setState(() {
      _activeCode = code;
      _listeningCustomerName = name;
    });
  }

  Future<void> _exportDatabase(String inspector) async {
    try {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚀 កំពុងដោះសោរ និងរៀបចំឯកសារថ្មីចុងក្រោយបង្អស់..."),
          backgroundColor: Colors.blue,
        ),
      );

      final db = await DatabaseService().database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL);');

      final String actualDbPath = db.path;
      final File sourceFile = File(actualDbPath);
      String shareText = 'ទិន្នន័យស្រង់អំណាន "$inspector"';

      if (await sourceFile.exists()) {
        final String cacheDir = (await getTemporaryDirectory()).path;
        final int timestamp = DateTime.now().millisecondsSinceEpoch;
        final String backupFilePath = "$cacheDir/sn_meter_export_$timestamp.db";
        final File backupFile = File(backupFilePath);

        final Directory dir = Directory(cacheDir);
        if (await dir.exists()) {
          final List<FileSystemEntity> entities = dir.listSync();
          for (var entity in entities) {
            if (entity is File && entity.path.contains('sn_meter_export')) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }

        await sourceFile.copy(backupFilePath);

        final XFile xFile = XFile(
          backupFile.path,
          name: "sn_meter_export.db",
          mimeType: 'application/octet-stream',
        );

        if (!mounted) {
          return;
        }
        await Share.shareXFiles([xFile], text: shareText, subject: shareText);
      }
    } catch (e) {
      debugPrint("កំហុសក្នុងការ Export: $e");
    }
  }

  Future<void> _handleImport() async {
    try {
      if (!mounted) return;

      // 🚀 បង្ហាញផ្ទាំង Dialog បញ្ជាក់ ការពារទិន្នន័យ មុននឹងនាំចូល
      bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "⚠️ បញ្ជាក់ការនាំចូលទិន្នន័យ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "ការនាំចូលទិន្នន័យខែថ្មីនឹង៖",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "លុបទិន្នន័យអំណានខែបច្ចុប្បន្នទាំងអស់ចោល!",
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "ជំនួសដោយទិន្នន័យអតិថិជនខែថ្មីទាំងស្រុង!",
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  "📌 សូមប្រាកដថាអ្នកបាននាំចេញ (Export) ទិន្នន័យខែបច្ចុប្បន្ន និងបានចែករំលែករួចរាល់ជាមុន មុននឹងធ្វើការនាំចូល!",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "បោះបង់ (Cancel)",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text(
                  "យល់ព្រម នាំចូល",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        debugPrint("🚫 អ្នកប្រើប្រាស់បានបដិសេធការនាំចូលទិន្នន័យ។");
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "📥 💾 កំពុងនាំចូលដាតាបេស និងរៀបចំរចនាសម្ព័ន្ធស្វ័យប្រវត្តិ...",
            ),
            backgroundColor: Colors.blueAccent,
          ),
        );

        await DatabaseService().importDatabase(File(filePath));
        await _refreshData();

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "✅ នាំចូលដាតាបេស និងសមកាលកម្មរៀបតាមបង្គោល (Pole) ជោគជ័យ!",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ កំហុសក្នុងការនាំចូលអូតូ៖ $e");
    }
  }

  Future<void> _exportToExcel(String inspector) async {
    try {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📊 💾 កំពុងប្រមូលទិន្នន័យខែ-ឆ្នាំ និងរៀបចំ Excel..."),
          backgroundColor: Colors.teal,
        ),
      );

      final db = await DatabaseService().database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL);');

      final List<Map<String, dynamic>> dbRows = await db.query('sn_meter');
      if (dbRows.isEmpty) {
        return;
      }

      var excel = Excel.createExcel();
      var sheet1 = excel['Sheet1'];

      sheet1.appendRow([
        TextCellValue("ល.រ"),
        TextCellValue("កូដអតិថិជន"),
        TextCellValue("ឈ្មោះអតិថិជន"),
        TextCellValue("បង្គោល"),
        TextCellValue("ប្រអប់"),
        TextCellValue("អំពែ"),
        TextCellValue("នាឡិកាស្ទង់"),
        TextCellValue("អំណានចាស់"),
        TextCellValue("អំណានថ្មី"),
        TextCellValue("មេគុណ"),
        TextCellValue("ថាមពលសរុប"),
        TextCellValue("ថ្ងៃស្រង់"),
        TextCellValue("ស្ថានភាព"),
      ]);

      int index = 1;
      for (var row in dbRows) {
        double oldVal = double.tryParse(row['old']?.toString() ?? '0') ?? 0.0;

        String newValStr = row['new']?.toString() ?? "";
        if (newValStr.isEmpty || newValStr == "0" || newValStr == "0.0") {
          newValStr = row['new_value']?.toString() ?? "";
        }

        final double parsedNew = double.tryParse(newValStr) ?? 0.0;
        final bool isChecked = parsedNew > 0;

        double multiplier =
            double.tryParse(row['multiplier']?.toString() ?? '1') ?? 1.0;
        double usageResult = isChecked
            ? _calculateUsageLogic(oldVal, parsedNew, multiplier)
            : 0.0;

        sheet1.appendRow([
          IntCellValue(index++),
          TextCellValue(row['code']?.toString() ?? ""),
          TextCellValue(row['name']?.toString() ?? ""),
          TextCellValue(row['pole']?.toString() ?? ""),
          TextCellValue(row['box']?.toString() ?? ""),
          TextCellValue(row['amp']?.toString() ?? ""),
          TextCellValue(row['meter']?.toString() ?? ""),
          DoubleCellValue(oldVal),
          TextCellValue(isChecked ? newValStr : ""),
          DoubleCellValue(multiplier),
          DoubleCellValue(usageResult),
          TextCellValue(row['date_checked']?.toString() ?? ""),
          TextCellValue(isChecked ? "ប្រក្រតី" : "មិនទាន់ស្រង់"),
        ]);
      }

      final List<int>? bytes = excel.encode();
      if (bytes != null) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String excelPath =
            "${appDocDir.path}/report_meter_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        final File excelFile = File(excelPath);
        await excelFile.writeAsBytes(bytes, flush: true);

        final XFile xFile = XFile(
          excelFile.path,
          name: "របាយការណ៍ស្រង់អំណាន.xlsx",
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        if (!mounted) {
          return;
        }
        await Share.shareXFiles([
          xFile,
        ], text: '📊 របាយការណ៍ស្រង់អំណាន "$inspector"');
      }
    } catch (e) {
      debugPrint("❌ កំហុសក្នុងការនាំចេញ Excel៖ $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _isRolloverWarning
            ? Colors.redAccent
            : Colors.blueAccent,
        title: _isRolloverWarning
            ? Text(
                _warningMessage,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
            : (isSearching
                  ? TextField(
                      controller: searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: "ស្វែងរកឈ្មោះ ឬលេខនាឡិកាស្ទង់...",
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => runFilter(),
                    )
                  : const Text(
                      "ស្រង់អំណាននាឡិកា",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    )),
        actions: [
          if (_isRolloverWarning)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() => _isRolloverWarning = false),
            ),
          if (!_isRolloverWarning)
            IconButton(
              icon: Icon(
                isSearching ? Icons.cancel : Icons.search,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  isSearching = !isSearching;
                  if (!isSearching) {
                    searchController.clear();
                    runFilter();
                  }
                });
              },
            ),
          if (!isSearching && !_isRolloverWarning) ...[
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                String savedInspector =
                    prefs.getString('selected_inspector') ?? "អ្នកស្រង់ទី១";
                _exportDatabase(savedInspector);
              },
              tooltip: "Export Database",
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshData,
              tooltip: "ទាញទិន្នន័យថ្មី",
            ),
          ],
        ],
      ),
      drawer: AppDrawer(
        totalCount: allCustomers.length,
        doneCount: doneCount,
        inputMode: _inputMode,
        onBackup: (String inspector) => _exportDatabase(inspector),
        onImport: _handleImport,
        onExportExcel: (String inspector) => _exportToExcel(inspector),
        onModeChanged: (mode) {
          setState(() => _inputMode = mode);
        },
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                FilterArea(
                  areas: availableAreas,
                  poles: availablePoles,
                  boxes: availableBoxes,
                  selectedArea: selectedArea,
                  selectedPole: selectedPole,
                  selectedBox: selectedBox,
                  onAreaChanged: (val) {
                    setState(() {
                      selectedArea = val;
                      selectedPole = null;
                      selectedBox = null;
                    });
                    runFilter();
                  },
                  onPoleChanged: (val) {
                    setState(() {
                      selectedPole = val;
                      selectedBox = null;
                    });
                    runFilter();
                  },
                  onBoxChanged: (val) {
                    setState(() {
                      selectedBox = val;
                    });
                    runFilter();
                  },
                ),
                Expanded(
                  child: filteredCustomers.isEmpty
                      ? const Center(child: Text("មិនមានទិន្នន័យបង្ហាញទេ"))
                      : ListView.builder(
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = filteredCustomers[index];
                            final String code =
                                customer['code']?.toString() ?? "";
                            return CustomerCard(
                              cust: customer,
                              isActive: _activeCode == code,
                              inputMode: _inputMode,
                              mainController:
                                  controllers[code] ?? TextEditingController(),
                              focusNode: focusNodes[code] ?? FocusNode(),
                              multController:
                                  multiplierControllers[code] ??
                                  TextEditingController(text: "1"),
                              previewUsage: previewUsage[code] ?? 0,
                              onTap: () {
                                _selectCustomer(code, customer['name'] ?? "");
                                if (_inputMode == "manual") {
                                  focusNodes[code]?.requestFocus();
                                }
                              },
                              onPreviewChanged: (val) =>
                                  _updatePreview(code, val),
                              onSubmitted: (val) =>
                                  _handleSave(code, val, customer),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: (_inputMode == "camera" || _inputMode == "voice")
          ? _buildBottomActionControl()
          : null,
    );
  }

  Widget _buildBottomActionControl() {
    final bool hasSelected = _activeCode.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: hasSelected ? Colors.white : Colors.grey[50],
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ──── ដំណឹងអតិថិជនដែលកំពុងជ្រើសរើស ────
            Row(
              children: [
                Icon(
                  hasSelected ? Icons.person_pin : Icons.touch_app,
                  size: 18,
                  color: hasSelected ? Colors.blue[800] : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasSelected
                        ? "🎯 កំពុងរៀបចំ: $_listeningCustomerName"
                        : "សូមចុចលើបញ្ជីអតិថិជនខាងលើ ដើម្បីជ្រើសរើស...",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: hasSelected ? Colors.blue[800] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // ── Stand-by indicator dot ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasSelected
                        ? (_isListening ? Colors.red : Colors.green)
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ──── ប៊ូតុង Camera / Voice ────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_inputMode == "voice") _buildVoiceButton(hasSelected),
                if (_inputMode == "camera") _buildCameraButton(hasSelected),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraButton(bool hasSelected) {
    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasSelected ? Colors.orange : Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: Icon(
          Icons.camera_alt,
          color: hasSelected ? Colors.white : Colors.white70,
        ),
        label: Text(
          hasSelected ? "ថតរូបស្កេនលេខ" : "Stand by...",
          style: TextStyle(
            color: hasSelected ? Colors.white : Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: hasSelected
            ? () {
                FocusScope.of(context).unfocus();
                _captureAndScan(_activeCode);
              }
            : null,
      ),
    );
  }

  Widget _buildVoiceButton(bool hasSelected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── ប៊ូតុង Mic ──
        GestureDetector(
          onTap: hasSelected
              ? () {
                  FocusScope.of(context).unfocus();
                  _listenToVoice(_activeCode);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !hasSelected
                  ? Colors.grey[400]
                  : (_isListening ? Colors.red : Colors.blue),
              boxShadow: _isListening && hasSelected
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ]
                  : [],
            ),
            width: 66,
            height: 66,
            child: Icon(
              _isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(width: 20),
        // ── ប៊ូតុង Bluetooth ──
        GestureDetector(
          onTap: () async {
            FocusScope.of(context).unfocus();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("📡 កំពុងស្កេនប្រមូលទិន្នន័យពីនាឡិកាជុំវិញ..."),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );

            final List<Map<String, String>> bluetoothResults =
                await MeterBleService.scanAndCollectAll(allCustomers);
            int savedCount = 0;

            for (var data in bluetoothResults) {
              String? code = data['code'];
              String? value = data['value'];
              if (code != null && value != null) {
                await DatabaseService().updateReading(code, value);
                savedCount++;
              }
            }

            _refreshData();

            if (!mounted) {
              return;
            }
            if (savedCount > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "✅ បានទាញយកលេខចូលដាតាបេសចំនួន $savedCount នាឡិកាជោគជ័យ!",
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "❌ រកមិនឃើញនាឡិកាជិតៗនេះ ឬប៊្លូធូសទូរស័ព្ទមិនទាន់បើក",
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const CircleAvatar(
            radius: 33,
            backgroundColor: Colors.green,
            child: Icon(Icons.bluetooth, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }
}
