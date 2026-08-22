import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database_service.dart';
import 'sync_service.dart';

class WebDavService {
  static final WebDavService _instance = WebDavService._internal();
  factory WebDavService() => _instance;
  WebDavService._internal();

  final http.Client _client = http.Client();

  /// 🎯 រក្សាទុកព័ត៌មានគណនី WebDAV ទៅក្នុង SharedPreferences
  Future<void> saveCredentials({
    required String url,
    required String username,
    required String password,
    required String folderPath,
    required bool autoSync,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', url.trim());
    await prefs.setString('webdav_username', username.trim());
    await prefs.setString('webdav_password', password.trim());
    await prefs.setString('webdav_folder', folderPath.trim());
    await prefs.setBool('webdav_autosync', autoSync);
    debugPrint("💾 [WebDavService] Credentials saved!");
  }

  /// 🎯 ទាញយកព័ត៌មានគណនី WebDAV
  Future<Map<String, dynamic>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString('webdav_url') ?? '',
      'username': prefs.getString('webdav_username') ?? '',
      'password': prefs.getString('webdav_password') ?? '',
      'folder': prefs.getString('webdav_folder') ?? '/SN_Meter_Backups',
      'autoSync': prefs.getBool('webdav_autosync') ?? false,
    };
  }

  /// 🎯 បង្កើត Authorization Header សម្រាប់ Basic Auth
  String _getAuthHeader(String username, String password) {
    final credentials = '$username:$password';
    final stringToBase64 = utf8.fuse(base64);
    return 'Basic ${stringToBase64.encode(credentials)}';
  }

  /// 🎯 តេស្តការតភ្ជាប់ទៅកាន់ WebDAV Server
  Future<bool> testConnection(String url, String username, String password) async {
    try {
      final cleanUrl = url.endsWith('/') ? url : '$url/';
      final uri = Uri.parse(cleanUrl);

      // ប្រើវិធី PROPFIND (Depth: 0) ដើម្បីផ្ទៀងផ្ទាត់ការតភ្ជាប់
      final response = await _client.send(
        http.Request('PROPFIND', uri)
          ..headers['Authorization'] = _getAuthHeader(username, password)
          ..headers['Depth'] = '0',
      );

      debugPrint("📡 [WebDAV Test] Status code: ${response.statusCode}");
      // Status code 200 (OK) ឬ 207 (Multi-Status) មានន័យថាតភ្ជាប់បានជោគជ័យ
      return response.statusCode == 200 || response.statusCode == 207;
    } catch (e) {
      debugPrint("❌ [WebDAV Test Error] $e");
      return false;
    }
  }

  /// 🎯 បង្កើត Directory លើ WebDAV (បើមិនទាន់មាន)
  Future<bool> _createFolderIfNotExist(
    String baseUrl,
    String username,
    String password,
    String folderPath,
  ) async {
    try {
      if (folderPath == '/' || folderPath.trim().isEmpty) return true;

      final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final cleanFolder = folderPath.startsWith('/') ? folderPath : '/$folderPath';
      final folderWithSlash = cleanFolder.endsWith('/') ? cleanFolder : '$cleanFolder/';
      final uri = Uri.parse('$cleanUrl$folderWithSlash');

      // ឆែកមើលជាមុនសិនតាមរយៈ PROPFIND
      final checkRes = await _client.send(
        http.Request('PROPFIND', uri)
          ..headers['Authorization'] = _getAuthHeader(username, password)
          ..headers['Depth'] = '0',
      );

      if (checkRes.statusCode == 200 || checkRes.statusCode == 207) {
        return true; // មានរួចហើយ
      }

      // បើមិនទាន់មាន បង្កើតវាឡើងមកដោយ MKCOL
      final mkcolRes = await _client.send(
        http.Request('MKCOL', uri)..headers['Authorization'] = _getAuthHeader(username, password),
      );

      debugPrint("📁 [WebDAV MKCOL] Folder creation status: ${mkcolRes.statusCode}");
      return mkcolRes.statusCode == 201; // 201 Created
    } catch (e) {
      debugPrint("❌ [WebDAV MKCOL Error] $e");
      return false;
    }
  }

  /// 🚀 មុខងារចម្បង៖ រក្សាទុក Database (sn_meter.db) ទៅកាន់ Synology NAS
  Future<bool> uploadDatabase() async {
    try {
      final creds = await getCredentials();
      final String url = creds['url'];
      final String username = creds['username'];
      final String password = creds['password'];
      final String folder = creds['folder'];

      if (url.isEmpty || username.isEmpty || password.isEmpty) {
        debugPrint("⚠️ [WebDAV Sync] Credentials incomplete. Skipping backup.");
        return false;
      }

      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

      // ១. បង្កើត Folder លើ NAS
      await _createFolderIfNotExist(cleanUrl, username, password, folder);

      // ២. ទាញយកទីតាំងឯកសារ Database
      final String dbPath = await DatabaseService().getDatabasePath();
      final File dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        debugPrint("❌ [WebDAV Sync] Database file not found local!");
        return false;
      }

      // ៣. កំណត់ឈ្មោះហ្វាល់ Backup (sn_meter_backup_[DeviceName].db)
      final String deviceName = await SyncService().getDeviceName();
      final String cleanDeviceName = deviceName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final String backupFileName = "sn_meter_backup_$cleanDeviceName.db";

      // ៤. ផ្លូវទិសដៅសម្រាប់រក្សាទុក
      final cleanFolder = folder.startsWith('/') ? folder : '/$folder';
      final String targetPath = cleanFolder.endsWith('/')
          ? '$cleanFolder$backupFileName'
          : '$cleanFolder/$backupFileName';
      
      final uri = Uri.parse('$cleanUrl$targetPath');

      // ៥. ផ្ញើឯកសារតាមរយៈ HTTP PUT
      final request = http.StreamedRequest('PUT', uri)
        ..headers['Authorization'] = _getAuthHeader(username, password)
        ..headers['Content-Type'] = 'application/octet-stream'
        ..headers['Content-Length'] = dbFile.lengthSync().toString();

      dbFile.openRead().listen(
        request.sink.add,
        onDone: request.sink.close,
        onError: (err) {
          debugPrint("❌ [WebDAV Stream Error] $err");
          request.sink.close();
        },
        cancelOnError: true,
      );

      final response = await _client.send(request);
      final bool success =
          response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;

      if (success) {
        debugPrint("💾 [WebDAV Sync OK] Uploaded database successfully to $targetPath");
        return true;
      } else {
        debugPrint("❌ [WebDAV Sync Failed] Status code: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ [WebDAV Sync Exception] $e");
      return false;
    }
  }
}
