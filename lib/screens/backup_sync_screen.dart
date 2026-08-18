import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../database_service.dart';

class BackupSyncScreen extends StatefulWidget {
  const BackupSyncScreen({super.key});

  @override
  State<BackupSyncScreen> createState() => _BackupSyncScreenState();
}

class _BackupSyncScreenState extends State<BackupSyncScreen> {
  final SyncService _syncService = SyncService();

  String _deviceId = "កំពុងទាញយក...";
  String _deviceName = "កំពុងទាញយក...";
  bool _isSyncing = false;
  bool _isFirebaseReady = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    await _syncService.initialize();
    final String dId = await _syncService.getDeviceId();
    final String dName = await _syncService.getDeviceName();

    if (mounted) {
      setState(() {
        _deviceId = dId;
        _deviceName = dName;
        _isFirebaseReady = true;
      });
    }
  }

  /// 🚀 Sync ទិន្នន័យការអំណានទាំងអស់ទៅ Firebase Firestore
  Future<void> _handleSyncToFirebase() async {
    setState(() => _isSyncing = true);

    final List<Map<String, dynamic>> customers = await DatabaseService()
        .getCustomers();

    if (customers.isEmpty) {
      setState(() => _isSyncing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ គ្មានទិន្នន័យអតិថិជនដើម្បីធ្វើសមកាលកម្មទេ!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final String? errorMsg = await _syncService.syncAllReadings(customers);
    setState(() => _isSyncing = false);
    if (!mounted) return;

    if (errorMsg == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_done, color: Colors.teal),
              SizedBox(width: 8),
              Text("Sync ជោគជ័យ!"),
            ],
          ),
          content: Text(
            "ទិន្នន័យអំណានចំនួន ${customers.length} នាក់ ត្រូវបានបញ្ជូនទៅ Firebase Cloud ជោគជ័យ!\n\nបងអាចបើក Firebase Console ដើម្បីពិនិត្យទិន្នន័យ។",
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "យល់ព្រម",
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ មិនអាចបញ្ជូនទៅ Firebase ទេ! ($errorMsg)"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "ការពារទិន្នន័យ (Cloud Sync)",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildAutoSyncInfo(),
              const SizedBox(height: 16),
              _buildManualSyncCard(),
              const SizedBox(height: 16),
              _buildDeviceInfo(),
              const SizedBox(height: 16),
              _buildInfoFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF009688), Color(0xFF4DB6AC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: Colors.white, size: 26),
              SizedBox(width: 10),
              Text(
                "ការពារទិន្នន័យការស្រង់អំណាន",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            "ប្រព័ន្ធនឹងបញ្ជូនលេខអំណានកុងទ័ររបស់អតិថិជននីមួយៗទៅកាន់ Firebase Cloud ស្វ័យប្រវត្តិ ដើម្បីការពារការបាត់បង់ទិន្នន័យ ករណីទូរស័ព្ទខូច ឬបាត់។",
            style: TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSyncInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            _isFirebaseReady ? Icons.check_circle : Icons.hourglass_bottom,
            color: _isFirebaseReady ? Colors.green : Colors.orange,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "🔄 Auto Sync — ដំណើរការស្វ័យប្រវត្តិ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "រាល់ពេលអ្នកបញ្ចូល និងរក្សាទុកលេខអំណានកុងទ័ររបស់អតិថិជននីមួយៗ ប្រព័ន្ធបញ្ជូនទៅ Firebase Cloud ស្វ័យប្រវត្តិក្នុង Background ភ្លាមៗ (ត្រូវការ WiFi ឬ Data)។",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSyncCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_upload, color: Colors.teal, size: 22),
                SizedBox(width: 8),
                Text(
                  "Sync ទិន្នន័យទាំងអស់តែម្ដង",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "ប្រើក្នុងករណី៖ ចាប់ផ្ដើមប្រើប្រាស់ App ថ្មី, ភ្ជាប់ Internet ថ្មី, ឬចង់ធានា Sync ទិន្នន័យគ្រប់អតិថិជន",
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_sync),
                label: Text(
                  _isSyncing
                      ? "កំពុង Sync ទិន្នន័យ..."
                      : "ចាប់ផ្ដើម Sync ទិន្នន័យទាំងអស់",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onPressed: _isSyncing ? null : _handleSyncToFirebase,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Card(
      elevation: 1,
      color: Colors.blueGrey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ព័ត៌មានឧបករណ៍ (Device Identity)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.phone_android,
                  color: Colors.blueGrey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ឈ្មោះឧបករណ៍",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        _deviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.fingerprint, color: Colors.blueGrey, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sync ID (Cloud Key)",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      SelectableText(
                        _deviceId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.blueGrey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200, width: 0.5),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "ចំណាំ៖ ទិន្នន័យដែល Sync ទៅ Cloud គឺជាលេខអំណាន (code, name, old, new, date) ប៉ុណ្ណោះ — មិនមែន File .db ទាំងមូល ដូចនេះ Cloud ផ្ទុកបានតូចគ្រប់គ្រាន់ ហើយ Free Plan គ្រប់ 600-2000 នាក់ ១០០%!",
              style: TextStyle(fontSize: 11, color: Colors.brown, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
