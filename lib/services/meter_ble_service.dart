import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MeterBleService {
  static const String meterServiceUuid = "0000fff0-0000-1000-8000-00805f9b34fb";
  static const String readingCharacteristicUuid =
      "0000fff1-0000-1000-8000-00805f9b34fb";

  /// 🎯 មុខងារជំនួយ៖ ពិនិត្យ UUID របស់សេវាកម្មនាឡិកាស្ទង់ (គាំទ្រទាំង FFF0 និង AF30)
  static bool _isMeterService(String uuid) {
    final lower = uuid.toLowerCase();
    return lower.contains("fff0") || lower.contains("af30");
  }

  /// 🎯 មុខងារជំនួយ៖ ពិនិត្យ UUID របស់លក្ខណៈអំណាន (គាំទ្រទាំង FFF1 និង AF31)
  static bool _isReadingCharacteristic(String uuid) {
    final lower = uuid.toLowerCase();
    return lower.contains("fff1") || lower.contains("af31");
  }

  /// 🎯 មុខងារជំនួយ៖ បំប្លែងទិន្នន័យពីបៃត៍ទៅជាលេខ (គាំទ្រទាំងអត្ថបទ UTF-8 និងលក្ខណៈ Binary Float/Double)
  static double? _parseValueBytes(List<int> bytes) {
    if (bytes.isEmpty) return null;
    
    // ១. សាកល្បងបកស្រាយជា String UTF-8 (លំនាំដើមរបស់ម៉ែត្រភាគច្រើន)
    try {
      String rawString = utf8.decode(bytes).trim();
      double? val = double.tryParse(rawString);
      if (val != null) return val;
    } catch (_) {}

    // ២. បើបរាជ័យ សាកល្បងបកស្រាយជា Binary Float (4 bytes)
    if (bytes.length == 4) {
      try {
        final data = ByteData.sublistView(Uint8List.fromList(bytes));
        return data.getFloat32(0, Endian.little);
      } catch (_) {}
      try {
        final data = ByteData.sublistView(Uint8List.fromList(bytes));
        return data.getFloat32(0, Endian.big);
      } catch (_) {}
    }

    // ៣. សាកល្បងបកស្រាយជា Binary Double (8 bytes)
    if (bytes.length == 8) {
      try {
        final data = ByteData.sublistView(Uint8List.fromList(bytes));
        return data.getFloat64(0, Endian.little);
      } catch (_) {}
      try {
        final data = ByteData.sublistView(Uint8List.fromList(bytes));
        return data.getFloat64(0, Endian.big);
      } catch (_) {}
    }

    return null;
  }

  /// 🚀 មុខងារទី ១៖ ស្កេន និងទាញទិន្នន័យពីនាឡិកាតែមួយ (Single Scan & Read)
  static Future<double?> readMeterValue(String meterHardwareId) async {
    double? finalReading;

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      debugPrint("❌ សូមបើក Bluetooth ទូរស័ព្ទជាមុនសិន!");
      return null;
    }

    final Completer<double?> completer = Completer<double?>();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    late StreamSubscription<List<ScanResult>> scanSubscription;

    scanSubscription = FlutterBluePlus.onScanResults.listen((results) async {
      for (ScanResult r in results) {
        String deviceName = r.device.platformName.trim();
        String remoteId = r.device.remoteId.str.trim();
        String targetId = meterHardwareId.trim();

        // 🎯 ដំណោះស្រាយ៖ គាំទ្រការស្វែងរកដោយពិនិត្យថាឈ្មោះ Bluetooth មានផ្ទុក ឬបញ្ចប់ដោយលេខនាឡិកា
        if (deviceName.contains("E-POWER") ||
            remoteId == targetId ||
            deviceName == targetId ||
            deviceName.contains(targetId) ||
            deviceName.endsWith(targetId) ||
            targetId.contains(deviceName)) {
          await FlutterBluePlus.stopScan();
          await scanSubscription.cancel();

          try {
            await r.device.connect();

            List<BluetoothService> services = await r.device.discoverServices();
            for (BluetoothService service in services) {
              if (_isMeterService(service.uuid.toString())) {
                for (BluetoothCharacteristic c in service.characteristics) {
                  if (_isReadingCharacteristic(c.uuid.toString())) {
                    List<int> valueBytes = await c.read();
                    finalReading = _parseValueBytes(valueBytes);
                    break;
                  }
                }
              }
            }

            await r.device.disconnect();
            if (!completer.isCompleted) completer.complete(finalReading);
          } catch (e) {
            debugPrint("❌ កំហុសក្នុងការភ្ជាប់៖ $e");
            if (!completer.isCompleted) completer.complete(null);
          }
          break;
        }
      }
    });

    Future.delayed(const Duration(seconds: 5), () async {
      await scanSubscription.cancel();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// 🚀 មុខងារទី ២៖ ស្កេនប្រមូលទិន្នន័យរួមជុំវិញខ្លួន (Batch Scan)
  static Future<List<Map<String, String>>> scanAndCollectAll(
    List<Map<String, dynamic>> customers,
  ) async {
    List<Map<String, String>> collectedData = [];

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      return collectedData;
    }

    Map<String, String> meterToCodeMap = {};
    for (var c in customers) {
      if (c['meter'] != null && c['code'] != null) {
        meterToCodeMap[c['meter'].toString().trim()] = c['code'].toString();
      }
    }

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    List<ScanResult> results = await FlutterBluePlus.scanResults.first;
    await FlutterBluePlus.stopScan();

    for (ScanResult r in results) {
      String deviceName = r.device.platformName.trim();
      String remoteId = r.device.remoteId.str.trim();
      
      // 🎯 ដំណោះស្រាយ៖ ស្វែងរក Code របស់អតិថិជនដោយពិនិត្យលើភាពត្រូវគ្នានៃឈ្មោះ Bluetooth និងលេខនាឡិកា
      String? matchedCode;
      for (var entry in meterToCodeMap.entries) {
        String key = entry.key; // លេខនាឡិកាក្នុង DB
        if (deviceName == key ||
            deviceName.contains(key) ||
            deviceName.endsWith(key) ||
            key.contains(deviceName) ||
            remoteId == key) {
          matchedCode = entry.value;
          break;
        }
      }

      if (matchedCode != null) {
        try {
          await r.device.connect();
          List<BluetoothService> services = await r.device.discoverServices();

          for (BluetoothService service in services) {
            if (_isMeterService(service.uuid.toString())) {
              for (BluetoothCharacteristic c in service.characteristics) {
                if (_isReadingCharacteristic(c.uuid.toString())) {
                  List<int> bytes = await c.read();
                  double? value = _parseValueBytes(bytes);

                  if (value != null) {
                    collectedData.add({
                      'code': matchedCode,
                      'value': value.toString(),
                    });
                  }
                  break;
                }
              }
            }
          }
          await r.device.disconnect();
        } catch (e) {
          debugPrint("កំហុសពេលភ្ជាប់ម៉ែត្រ $deviceName: $e");
        }
      }
    }
    return collectedData;
  }
}
