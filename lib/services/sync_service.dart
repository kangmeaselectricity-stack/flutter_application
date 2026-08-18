import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isFirebaseInitialized = false;
  String? _deviceId;
  String? _deviceName;

  /// 🎯 ពិនិត្យ Firebase Initialization (main.dart ហៅ initializeApp ហើយ)
  Future<void> initialize() async {
    if (_isFirebaseInitialized) return;
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
        debugPrint("🔥 [SyncService] Firebase ready!");
        await _loadDeviceInfo();
      } else {
        debugPrint("⚠️ [SyncService] Firebase apps empty — មិនទាន់ Initialize ទេ");
      }
    } catch (e) {
      debugPrint("❌ [SyncService Init Error] $e");
      _isFirebaseInitialized = false;
    }
  }

  /// 🎯 ទាញយក ឬបង្កើតអត្តសញ្ញាណឧបករណ៍ (Device ID/Name)
  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('cloud_device_id');
    _deviceName = prefs.getString('cloud_device_name');

    if (_deviceId == null || _deviceName == null) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          _deviceId = androidInfo.id; // Android ID
          _deviceName = "${androidInfo.brand} ${androidInfo.model}";
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          _deviceId = iosInfo.identifierForVendor; // IOS Vendor ID
          _deviceName = iosInfo.name;
        }
      } catch (e) {
        debugPrint("⚠️ មិនអាចចាប់ឧបករណ៍ដោយស្វ័យប្រវត្ត៖ $e");
      }

      // ប្រសិនបើនៅតែទទេ បង្កើត UUID ជំនួសវិញ
      _deviceId ??= _generateUuid();
      _deviceName ??= "ទូរស័ព្ទដៃជំនួយ (${Platform.operatingSystem})";

      await prefs.setString('cloud_device_id', _deviceId!);
      await prefs.setString('cloud_device_name', _deviceName!);
    }
    debugPrint("📱 Device ID: $_deviceId, Device Name: $_deviceName");
  }

  /// 🎯 ទាញយក Device ID
  Future<String> getDeviceId() async {
    if (_deviceId == null) await _loadDeviceInfo();
    return _deviceId!;
  }

  /// 🎯 ទាញយក Device Name
  Future<String> getDeviceName() async {
    if (_deviceName == null) await _loadDeviceInfo();
    return _deviceName!;
  }

  /// 🎯 ចូលគណនី Firebase Auth (Email ឬ Anonymous) ដើម្បីឱ្យមានសិទ្ធិ Rule ក្នុង Cloud Firestore
  Future<void> _ensureAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        try {
          await auth.signInWithEmailAndPassword(
            email: "kangmeaselectricity@gmail.com",
            password: "K.Meas@\$88",
          );
          debugPrint("👤 [Firebase Auth] Logged in with Email");
        } catch (e) {
          debugPrint("⚠️ Email Auth failed ($e), trying Anonymous Auth...");
          await auth.signInAnonymously();
          debugPrint("👤 [Firebase Auth] Logged in Anonymously");
        }
      }
    } catch (e) {
      debugPrint("⚠️ [Firebase Auth Exception] $e");
    }
  }

  /// 🚀 មុខងារបញ្ជូនលេខអំណានកុងទ័រទោ Firebase ស្វ័យប្រវត្ត (Auto Sync Single Reading)
  Future<void> syncReading(Map<String, dynamic> row) async {
    await initialize();
    if (!_isFirebaseInitialized) {
      debugPrint("⚠️ [Sync Info] Firebase មិនទាន់ដំណើរការ (Skip Firestore Sync)");
      return;
    }

    try {
      await _ensureAuth();
      final String dId = await getDeviceId();
      final String dName = await getDeviceName();
      final String code = row['code']?.toString().trim() ?? "";

      if (code.isEmpty) return;

      final firestore = FirebaseFirestore.instance;

      // ១. រក្សាទុកព័ត៌មានឧបករណ៍
      await firestore.collection('devices').doc(dId).set({
        'deviceId': dId,
        'deviceName': dName,
        'lastSyncTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ២. ផ្ញើ Fields ទាំងអស់ដែលមានក្នុង Database Row (Dynamic — គ្មាន Field ណាខ្វះ)
      final Map<String, dynamic> docData = {};
      for (final entry in row.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val == null) continue;
        if (val is double || val is int || val is String || val is bool) {
          docData[key] = val;
        } else {
          docData[key] = val.toString();
        }
      }
      docData['syncedAt'] = FieldValue.serverTimestamp();

      await firestore
          .collection('devices')
          .doc(dId)
          .collection('readings')
          .doc(code)
          .set(docData, SetOptions(merge: true));

      debugPrint("☁️ [Firebase Sync OK] Code=$code Fields=${docData.keys.join(',')}");
    } catch (e) {
      debugPrint("❌ [Firebase Sync Error] $e");
    }
  }

  /// 🚀 មុខងារបញ្ជូនទិន្នន័យអតិថិជនទាំងអស់ដែលមានស្រាប់ក្នុង SQLite ទៅកាន់ Cloud (Batch Sync)
  /// ត្រឡប់មកវិញនូវ null ប្រសិនបើជោគជ័យ ឬ String នៃ Error ប្រសិនបើមានបញ្ហា
  Future<String?> syncAllReadings(List<Map<String, dynamic>> allCustomers) async {
    await initialize();
    if (!_isFirebaseInitialized) {
      return "Firebase មិនទាន់ដំណើរការក្នុងកម្មវិធីទេ (Init Failed)";
    }

    try {
      await _ensureAuth();

      final String dId = await getDeviceId();
      final String dName = await getDeviceName();
      final firestore = FirebaseFirestore.instance;

      // ១. កត់ត្រាព័ត៌មានឧបករណ៍
      await firestore.collection('devices').doc(dId).set({
        'deviceId': dId,
        'deviceName': dName,
        'lastSyncTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ២. បញ្ជូនជាបណ្ដុំ (Batch) ការពារការបុក Request ខ្លាំងពេក
      WriteBatch batch = firestore.batch();
      int count = 0;
      int batchNum = 0;

      for (var row in allCustomers) {
        final String code = row['code']?.toString().trim() ?? "";
        if (code.isEmpty) continue;

        final docRef = firestore
            .collection('devices')
            .doc(dId)
            .collection('readings')
            .doc(code);

        // ផ្ញើ Fields ទាំងអស់ក្នុង Row ដោយ Dynamic (គ្មាន Field ណាត្រូវបានភ្លេច)
        final Map<String, dynamic> docData = {};
        for (final entry in row.entries) {
          final key = entry.key.toString();
          final val = entry.value;
          if (val == null) continue;
          if (val is double || val is int || val is String || val is bool) {
            docData[key] = val;
          } else {
            docData[key] = val.toString();
          }
        }
        docData['syncedAt'] = FieldValue.serverTimestamp();

        batch.set(docRef, docData, SetOptions(merge: true));
        count++;

        // Firestore Batch Limit = 500 documents → Commit រៀងរាល់ 450 docs
        if (count % 450 == 0) {
          await batch.commit();
          batchNum++;
          debugPrint("☁️ [Batch $batchNum] Committed 450 docs (total=$count)...");
          batch = firestore.batch(); // បង្កើត Batch ថ្មី
        }
      }

      // Commit ចុងក្រោយ (ករណីចំនួនអតិថិជន < 450 ឬសល់)
      if (count % 450 != 0) {
        await batch.commit();
        debugPrint("☁️ [Batch Sync Done] ផ្ញើអតិថិជន $count នាក់ ទៅ Cloud ជោគជ័យ!");
      }

      if (count == 0) {
        return "គ្មានទិន្នន័យអតិថិជនដែលមាន Code ត្រឹមត្រូវដើម្បី Sync ទេ";
      }

      return null; // Null means SUCCESS
    } catch (e) {
      debugPrint("❌ [Firebase Batch Sync Error] $e");
      return "កំហុស Firebase: $e";
    }
  }




  /// 🎯 មុខងារជំនួយ៖ បង្កើត UUID v4 (Random) ដោយមិនប្រើប្រាស់បណ្ណាល័យក្រៅ
  String _generateUuid() {
    final random = Random.secure();
    final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));

    // Set version to 4 (random)
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();

    return "${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-${hex.sublist(10, 16).join()}";
  }
}
