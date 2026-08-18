import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService Tests', () {
    setUp(() async {
      // កំណត់តម្លៃ SharedPreferences Mock ឱ្យទទេមុនពេលធ្វើតេស្តនីមួយៗ
      SharedPreferences.setMockInitialValues({});
    });

    test('Test Device Info generation and retrieval', () async {
      final syncService = SyncService();
      
      // ១. ទាញយក Device ID និង Name លើកដំបូង (គួរតែបង្កើតឡើងដោយស្វ័យប្រវត្តិតាមរយៈ UUID)
      final deviceId = await syncService.getDeviceId();
      final deviceName = await syncService.getDeviceName();

      expect(deviceId, isNotEmpty);
      expect(deviceName, contains("ទូរស័ព្ទដៃជំនួយ"));

      // ២. ផ្ទៀងផ្ទាត់ថាវាត្រូវបានរក្សាទុកក្នុង SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cloud_device_id'), equals(deviceId));
      expect(prefs.getString('cloud_device_name'), equals(deviceName));

      // ៣. ពិនិត្យមើលថាក្នុងការហៅលើកទី២ តម្លៃត្រូវនៅរក្សាដដែល (មិនបង្កើតថ្មីទៀតទេ)
      final secondDeviceId = await syncService.getDeviceId();
      expect(secondDeviceId, equals(deviceId));
    });
  });
}
