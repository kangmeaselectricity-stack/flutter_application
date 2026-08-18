import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../database_service.dart';
import 'sync_service.dart';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive
          .DriveApi
          .driveFileScope, // សិទ្ធិបង្កើត និងកែប្រែហ្វាល់ដែលបង្កើតឡើងដោយ App នេះ
    ],
  );

  GoogleSignInAccount? _currentUser;

  /// 🎯 ទាញយកគណនីដែលកំពុង Sign-In ស្រាប់
  Future<GoogleSignInAccount?> get currentUser async {
    _currentUser ??= _googleSignIn.currentUser;
    _currentUser ??= await _googleSignIn.signInSilently();
    return _currentUser;
  }

  /// 🎯 ចុះឈ្មោះចូលគណនី (Sign In)
  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      debugPrint("👤 Google Sign-In Success: ${_currentUser?.email}");
      return _currentUser;
    } catch (e) {
      debugPrint("❌ Google Sign-In Error: $e");
      return null;
    }
  }

  /// 🎯 ចាកចេញពីគណនី (Sign Out)
  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
      _currentUser = null;
      debugPrint("👤 Google Signed Out!");
    } catch (e) {
      debugPrint("❌ Google Sign-Out Error: $e");
    }
  }

  /// 🎯 ពិនិត្យស្ថានភាព Sign-In
  Future<bool> isSignedIn() async {
    final user = await currentUser;
    return user != null;
  }

  /// 🎯 ទាញយក Email គណនីដែលកំពុងប្រើ
  Future<String?> getUserEmail() async {
    final user = await currentUser;
    return user?.email;
  }

  /// 🚀 មុខងាររក្សាទុក Database (sn_meter.db) ទៅកាន់ Google Drive
  Future<bool> uploadDatabaseToDrive() async {
    try {
      final user = await currentUser;
      if (user == null) {
        debugPrint("⚠️ មិនទាន់បាន Sign-In គណនី Google ទេ (Skip upload)");
        return false;
      }

      // ១. បង្កើត Authenticated Client សម្រាប់ Drive API
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        debugPrint("❌ មិនអាចបង្កើត Auth Client សម្រាប់ Google Drive បានទេ");
        return false;
      }

      final driveApi = drive.DriveApi(httpClient);

      // ២. ទាញយកទីតាំងឯកសារ Database
      final String dbPath = await DatabaseService().getDatabasePath();
      final File dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        debugPrint("❌ រកមិនឃើញឯកសារ Database (.db) ក្នុងម៉ាស៊ីនទេ");
        return false;
      }

      // ៣. បង្កើត ឬស្វែងរក Folder ឈ្មោះ "SN_Meter_Backups" លើ Drive
      String? folderId = await _findOrCreateBackupFolder(driveApi);
      if (folderId == null) {
        debugPrint("❌ មិនអាចបង្កើត Folder សម្រាប់ Backup លើ Drive បានទេ");
        return false;
      }

      // ៤. កំណត់ឈ្មោះហ្វាល់ Backup (ឧទាហរណ៍៖ sn_meter_backup_[DeviceName].db)
      final String deviceName = await SyncService().getDeviceName();
      final String cleanDeviceName = deviceName.replaceAll(
        RegExp(r'[^a-zA-Z0-9_]'),
        '_',
      );
      final String backupFileName = "sn_meter_backup_$cleanDeviceName.db";

      // ៥. ឆែកមើលក្រែងលោមានហ្វាល់ចាស់ដែលមានឈ្មោះដូចគ្នាក្នុង Folder នោះ
      final String query =
          "name = '$backupFileName' and '$folderId' in parents and trashed = false";
      final drive.FileList existingFiles = await driveApi.files.list(
        q: query,
        spaces: 'drive',
      );

      final drive.File driveFile = drive.File();
      driveFile.name = backupFileName;

      // បើជាហ្វាល់ថ្មី ត្រូវកំណត់ Parent Folder ឱ្យវា
      if (existingFiles.files == null || existingFiles.files!.isEmpty) {
        driveFile.parents = [folderId];
      }

      final media = drive.Media(dbFile.openRead(), dbFile.lengthSync());

      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        // ធ្វើបច្ចុប្បន្នភាពហ្វាល់ចាស់ (Update existing backup file)
        final String existingFileId = existingFiles.files!.first.id!;
        await driveApi.files.update(
          driveFile,
          existingFileId,
          uploadMedia: media,
        );
        debugPrint(
          "💾 [Google Drive] បានធ្វើបច្ចុប្បន្នភាពឯកសារ Backup ចាស់ (ID: $existingFileId)",
        );
      } else {
        // បង្កើតហ្វាល់ថ្មី (Create new backup file)
        final drive.File result = await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
        debugPrint(
          "💾 [Google Drive] បានបង្កើតឯកសារ Backup ថ្មី (ID: ${result.id})",
        );
      }

      return true;
    } catch (e) {
      debugPrint("❌ [Google Drive Backup Error] $e");
      return false;
    }
  }

  /// 🎯 មុខងារជំនួយ៖ ស្វែងរក ឬបង្កើត Backup Folder
  Future<String?> _findOrCreateBackupFolder(drive.DriveApi driveApi) async {
    const String folderName = "SN_Meter_Backups";
    const String folderMime = "application/vnd.google-apps.folder";

    try {
      // ១. ស្វែងរក Folder ឈ្មោះ "SN_Meter_Backups"
      final String query =
          "name = '$folderName' and mimeType = '$folderMime' and trashed = false";
      final drive.FileList result = await driveApi.files.list(
        q: query,
        spaces: 'drive',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id;
      }

      // ២. បង្កើតថ្មីបើមិនទាន់មាន
      final drive.File folderMetadata = drive.File();
      folderMetadata.name = folderName;
      folderMetadata.mimeType = folderMime;

      final drive.File folder = await driveApi.files.create(folderMetadata);
      debugPrint("📁 [Google Drive] បានបង្កើត Folder ថ្មី៖ ${folder.id}");
      return folder.id;
    } catch (e) {
      debugPrint("❌ មិនអាចគ្រប់គ្រង Folder លើ Google Drive ៖ $e");
      return null;
    }
  }
}
