import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'services/sync_service.dart';

class DatabaseService {
  static DatabaseService _instance = DatabaseService.internal();
  factory DatabaseService() => _instance;

  @visibleForTesting
  DatabaseService.internal();

  @visibleForTesting
  static set instance(DatabaseService value) => _instance = value;

  Database? _database;

  // 🎯 កែសម្រួលសុវត្ថិភាពខ្ពស់៖ បើដាតាបេសត្រូវបានបិទ គឺវាបើកឡើងវិញភ្លាម លែងគាំងអេក្រង់ខ្មៅ
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, "sn_meter.db");
    bool exists = await databaseExists(path);

    if (!exists) {
      debugPrint("កំពុងចម្លង Database ពី Assets...");
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(join("assets", "sn_meter.db"));
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        debugPrint("កំហុសក្នុងការចម្លង Database: $e");
      }
    }

    Database db = await openDatabase(path, version: 1);

    // បង្ខំឱ្យ SQLite សរសេរទិន្នន័យចូលសាច់ហ្វាល់ចំៗ (បិទប្រព័ន្ធ WAL Mode ញ៉េរញ៉ៃចោល)
    try {
      await db.rawQuery('PRAGMA journal_mode = DELETE');
    } catch (_) {}

    await _checkAndAddMissingColumns(db);
    return db;
  }

  // 🎯 មុខងារនាំចូលទិន្នន័យខែថ្មី៖ លុបហ្វាល់ចាស់ចោលឱ្យដាច់ស្រឡះ ដើម្បីទទួលយកទិន្នន័យថ្មី
  Future<void> importDatabase(File pickedFile) async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, "sn_meter.db");

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final File oldDbFile = File(path);
    if (await oldDbFile.exists()) {
      await oldDbFile.delete();
    }

    await pickedFile.copy(path);

    // បើកដំណើរការឡើងវិញភ្លាមៗ
    _database = await _initDb();
  }

  Future<void> _checkAndAddMissingColumns(Database db) async {
    try {
      var columns = await db.rawQuery("PRAGMA table_info(sn_meter)");

      // ពិនិត្យ Column multiplier
      bool hasMultiplier = columns.any(
        (column) => column['name'] == 'multiplier',
      );
      if (!hasMultiplier) {
        await db.execute(
          "ALTER TABLE sn_meter ADD COLUMN multiplier REAL DEFAULT 1.0",
        );
        debugPrint("✅ បានបន្ថែម Column: multiplier");
      }

      // ពិនិត្យ Column date_checked
      bool hasDateChecked = columns.any(
        (column) => column['name'] == 'date_checked',
      );
      if (!hasDateChecked) {
        await db.execute(
          "ALTER TABLE sn_meter ADD COLUMN date_checked TEXT",
        );
        debugPrint("✅ បានបន្ថែម Column: date_checked");
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final db = await database;
      // ទាញយកទិន្នន័យពីតារាង sn_meter ដើមរបស់បង
      final List<Map<String, dynamic>> res = await db.query('sn_meter');

      return res.map((item) {
        final newItem = Map<String, dynamic>.from(item);

        // 🎯 ពិនិត្យឈ្មោះ Column ឱ្យត្រូវជាមួយ File ដើមរបស់បង
        if (newItem.containsKey('old') && !newItem.containsKey('old_value')) {
          newItem['old_value'] = newItem['old'];
        } else if (newItem.containsKey('old_value') &&
            !newItem.containsKey('old')) {
          newItem['old'] = newItem['old_value'];
        }

        // 🎯 ចាប់តម្លៃពីជួរ 'new' ឬ 'new_value' មកបង្ហាញលើ UI ឱ្យចំៗ
        String currentNewVal = "";
        dynamic rawNew = newItem['new'] ?? newItem['new_value'];
        if (rawNew != null) {
          String valStr = rawNew.toString().trim();
          if (valStr.isNotEmpty && valStr != "0" && valStr != "0.0") {
            currentNewVal = valStr;
          }
        }

        newItem['new_value'] = currentNewVal;
        newItem['new'] = currentNewVal;

        return newItem;
      }).toList();
    } catch (e) {
      debugPrint("Error query: $e");
      return [];
    }
  }

  // 💡 🎯 ដំណោះស្រាយចុងក្រោយបង្អស់៖ ប្តូរមកប្រើ RAW SQL បង្ខំបុកចូល Column 'new' ត្រង់ៗ ដោយមិនប្រើ Map នាំឱ្យវង្វេងឈ្មោះ Column ទៀតឡើយ
  Future<int> updateReading(String code, String newValue) async {
    try {
      final db = await database;
      final String trimmed = newValue.trim();

      // បំប្លែងទៅជាប្រភេទលេខ double ដើម្បីឱ្យត្រូវទម្រង់ REAL របស់ Python លើ Desktop
      final double numericValue = double.tryParse(trimmed) ?? 0.0;

      // 🗓️ ចាប់ថ្ងៃបច្ចុប្បន្នក្នុងទម្រង់ YYYY-MM-DD HH:MM:SS
      final String dateNow = DateTime.now().toString().split('.')[0];

      // 🚀 ១. បុកបញ្ជា UPDATE ទៅលើ Column "new" និង "date_checked" ត្រង់ៗចំៗ ១០០%
      // ដោយប្រើ TRIM(code) ដើម្បីការពារក្រែងលោ Python មានថែមដកឃ្លាលើកូដអតិថិជន
      int count = await db.rawUpdate(
        'UPDATE sn_meter SET "new" = ?, "date_checked" = ? WHERE TRIM(code) = TRIM(?)',
        [numericValue, dateNow, code.trim()],
      );

      // ២. ឆែកមើលក្រែងលោក្នុងដាតាបេសបងមាន Column ឈ្មោះ new_value មួយទៀត ឱ្យវាកែជាមួយការពារកុំឱ្យចន្លោះ
      try {
        await db.rawUpdate(
          'UPDATE sn_meter SET "new_value" = ? WHERE TRIM(code) = TRIM(?)',
          [numericValue, code.trim()],
        );
      } catch (_) {}

      // 🎯 ៣. បង្ខំឱ្យប្រព័ន្ធ SQLite រុញទិន្នន័យ (២៨០២, ៥៨០) ទម្លុះចូលសាច់ហ្វាល់ .db ភ្លាមៗ លែងឱ្យដេកក្នុង Memory
      await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE)');

      debugPrint(
        "💾 [RAW SQL SUCCESS] បានរក្សាទុកលេខ $numericValue ចូលអតិថិជនកូដ $code ថ្ងៃ $dateNow (បានកែប្រែ $count រ៉ូ)",
      );

      // ☁️ ៤. បញ្ជូនទិន្នន័យទៅកាន់ Firebase Cloud ក្នុង Background ភ្លាមៗ (Auto Sync)
      if (count > 0) {
        try {
          final List<Map<String, dynamic>> res = await db.query(
            'sn_meter',
            where: 'TRIM(code) = ?',
            whereArgs: [code.trim()],
            limit: 1,
          );
          if (res.isNotEmpty) {
            final row = Map<String, dynamic>.from(res.first);
            // ពិនិត្យឈ្មោះ Column ឱ្យត្រូវ
            if (row.containsKey('old') && !row.containsKey('old_value')) {
              row['old_value'] = row['old'];
            }
            if (row.containsKey('new') && !row.containsKey('new_value')) {
              row['new_value'] = row['new'];
            }
            unawaited(SyncService().syncReading(row));
          }
        } catch (syncErr) {
          debugPrint("⚠️ [Auto Sync Warning] Error querying for sync: $syncErr");
        }
      }

      return count;
    } catch (e) {
      debugPrint("❌ កំហុសក្នុងការរក្សាទុក៖ $e");
      return 0;
    }
  }

  Future<int> updateMultiplier(String code, double multiplier) async {
    try {
      final db = await database;
      int count = await db.rawUpdate(
        'UPDATE sn_meter SET "multiplier" = ? WHERE TRIM(code) = TRIM(?)',
        [multiplier, code.trim()],
      );
      await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE)');
      debugPrint("💾 [MULTIPLIER SUCCESS] បានរក្សាទុកមេគុណ $multiplier ចូលអតិថិជនកូដ $code");
      return count;
    } catch (e) {
      debugPrint("❌ កំហុសក្នុងការរក្សាទុកមេគុណ៖ $e");
      return 0;
    }
  }

  Future<String> getDatabasePath() async {
    String databasesPath = await getDatabasesPath();
    return join(databasesPath, "sn_meter.db");
  }

  // 💡 មុខងារពិសេស៖ បង្ហាញការបង្កើត File ដាតាបេសថ្មីស្រឡាងមួយដោយខ្លួនឯងលើទូរស័ព្ទ ដើម្បីសាកល្បង
  Future<void> createNewDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, "sn_meter.db");

    // ១. បិទដាតាបេសចាស់សិន
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // ២. លុប File ចាស់ចោលដើម្បីកុំឱ្យជាន់គ្នា
    final File dbFile = File(path);
    if (await dbFile.exists()) {
      await dbFile.delete();
    }

    // ៣. បង្កើត File ថ្មីចែស និងបង្កើតតារាង sn_meter ស្ដង់ដារមួយឡើងមក
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        // បង្កើតតារាងសាកល្បង (បងអាចថែមជួរផ្សេងៗទៀតបានតាមចិត្ត)
        await db.execute('''
          CREATE TABLE sn_meter (
            code TEXT PRIMARY KEY,
            name TEXT,
            old REAL DEFAULT 0.0,
            new REAL DEFAULT 0.0,
            multiplier REAL DEFAULT 1.0,
            date_checked TEXT
          )
        ''');

        // ញាត់ទិន្នន័យគំរូសាកល្បងចំនួន ២ នាក់ចូលទៅ
        await db.rawInsert(
          "INSERT INTO sn_meter (code, name, old, new) VALUES ('001', 'អតិថិជន តេស្តទី១', 100.0, 0.0)",
        );
        await db.rawInsert(
          "INSERT INTO sn_meter (code, name, old, new) VALUES ('002', 'អតិថិជន តេស្តទី២', 250.0, 0.0)",
        );
      },
    );

    // បង្ខំឱ្យប្រើ Mode ធម្មតា លែងបង្កើតហ្វាល់បណ្ដោះអាសន្ន
    await _database!.rawQuery('PRAGMA journal_mode = DELETE');
    debugPrint("✨ បានបង្កើត File ថ្មីស្រឡាង និងតារាងតេស្តជោគជ័យដាច់ណាត់!");
  }

  /// 🎯 បិទការតភ្ជាប់ Database ជាបណ្ដោះអាសន្ន ដើម្បីសរសេរហ្វាល់ឡើងវិញ
  Future<void> closeDatabaseConnection() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint("💾 [SQLite] Closed database connection for restoration.");
    }
  }
}
