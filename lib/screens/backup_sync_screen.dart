import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../database_service.dart';
import '../services/webdav_service.dart';
import '../services/vpn_helper_service.dart';

class BackupSyncScreen extends StatefulWidget {
  const BackupSyncScreen({super.key});

  @override
  State<BackupSyncScreen> createState() => _BackupSyncScreenState();
}

class _BackupSyncScreenState extends State<BackupSyncScreen>
    with WidgetsBindingObserver {
  final SyncService _syncService = SyncService();
  final WebDavService _webDavService = WebDavService();
  final VpnHelperService _vpnService = VpnHelperService();

  // WebDAV controllers
  final TextEditingController _webdavUrlController = TextEditingController();
  final TextEditingController _webdavUsernameController =
      TextEditingController();
  final TextEditingController _webdavPasswordController =
      TextEditingController();
  final TextEditingController _webdavFolderController = TextEditingController();

  // VPN controllers
  final TextEditingController _vpnServerController = TextEditingController();
  final TextEditingController _vpnPskController = TextEditingController();
  final TextEditingController _vpnUsernameController = TextEditingController();
  final TextEditingController _vpnPasswordController = TextEditingController();

  String _deviceId = "កំពុងទាញយក...";
  String _deviceName = "កំពុងទាញយក...";
  bool _isSyncing = false;
  bool _isFirebaseReady = false;
  bool _webdavAutoSync = false;
  bool _isWebDavTesting = false;
  bool _isWebDavSyncing = false;

  // VPN state
  bool _vpnConnected = false;
  bool _vpnChecking = false;
  bool _vpnSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    _webdavFolderController.dispose();
    _vpnServerController.dispose();
    _vpnPskController.dispose();
    _vpnUsernameController.dispose();
    _vpnPasswordController.dispose();
    super.dispose();
  }

  // ពេល User ត្រឡប់ពី VPN Settings មកវិញ — auto check VPN
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVpnStatus();
    }
  }

  Future<void> _checkStatus() async {
    await _syncService.initialize();
    final String dId = await _syncService.getDeviceId();
    final String dName = await _syncService.getDeviceName();

    final webdavCreds = await _webDavService.getCredentials();
    final vpnConfig = await _vpnService.loadConfig();

    if (mounted) {
      setState(() {
        _deviceId = dId;
        _deviceName = dName;
        _isFirebaseReady = true;
        _webdavUrlController.text = webdavCreds['url'];
        _webdavUsernameController.text = webdavCreds['username'];
        _webdavPasswordController.text = webdavCreds['password'];
        _webdavFolderController.text = webdavCreds['folder'];
        _webdavAutoSync = webdavCreds['autoSync'];
        _vpnServerController.text = vpnConfig['server'] ?? '';
        _vpnPskController.text = vpnConfig['psk'] ?? '';
        _vpnUsernameController.text = vpnConfig['username'] ?? '';
        _vpnPasswordController.text = vpnConfig['password'] ?? '';
      });
    }
    // ពិនិត្យ VPN status ស្វ័យប្រវត្ត
    await _checkVpnStatus();
  }

  Future<void> _checkVpnStatus() async {
    if (!mounted) return;
    setState(() => _vpnChecking = true);

    // ដក IP ចេញពី WebDAV URL
    final webdavUrl = _webdavUrlController.text;
    String nasIp = '';
    try {
      final uri = Uri.tryParse(webdavUrl);
      nasIp = uri?.host ?? '';
    } catch (_) {}

    // fallback: ប្រើ vpn server ជា NAS ip (ប្រសិនបើ WebDAV url ទទេ)
    if (nasIp.isEmpty) nasIp = _vpnServerController.text;

    final status = await _vpnService.checkVpnStatus(nasIp);

    if (mounted) {
      setState(() {
        _vpnConnected = status['isConnected'] as bool;
        _vpnChecking = false;
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
              _buildVpnCard(),
              const SizedBox(height: 16),
              _buildAutoSyncInfo(),
              const SizedBox(height: 16),
              _buildManualSyncCard(),
              const SizedBox(height: 16),
              _buildWebDavSyncCard(),
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

  Widget _buildWebDavSyncCard() {
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
                Icon(Icons.dns, color: Colors.indigo, size: 22),
                SizedBox(width: 8),
                Text(
                  "Synology NAS (WebDAV Sync)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _webdavUrlController,
              label: "NAS WebDAV URL",
              hint: "ឧទាហរណ៍៖ http://192.168.195.129:5005",
              icon: Icons.link,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _webdavUsernameController,
                    label: "Username",
                    hint: "គណនី NAS",
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _webdavPasswordController,
                    label: "Password",
                    hint: "ពាក្យសម្ងាត់",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _webdavFolderController,
              label: "Remote Folder",
              hint: "ឧទាហរណ៍៖ /SN_Meter_Backups",
              icon: Icons.folder_open,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    "🔄 Auto Sync ពេលរក្សាទុកលេខ",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Switch(
                  value: _webdavAutoSync,
                  activeThumbColor: Colors.indigo,
                  activeTrackColor: Colors.indigo.withValues(alpha: 0.5),
                  onChanged: (val) {
                    setState(() {
                      _webdavAutoSync = val;
                    });
                    _saveWebDavSettings();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: const BorderSide(color: Colors.indigo),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isWebDavTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.indigo,
                            ),
                          )
                        : const Icon(Icons.sync_problem, size: 18),
                    label: const Text(
                      "តេស្តការភ្ជាប់",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isWebDavTesting || _isWebDavSyncing
                        ? null
                        : _handleTestWebDav,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    icon: _isWebDavSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.backup, size: 18),
                    label: const Text(
                      "បម្រុងទុកឥឡូវនេះ",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isWebDavTesting || _isWebDavSyncing
                        ? null
                        : _handleUploadWebDav,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
              prefixIcon: Icon(icon, size: 16, color: Colors.indigo),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.indigo),
              ),
            ),
            onChanged: (val) => _saveWebDavSettings(),
          ),
        ),
      ],
    );
  }

  Future<void> _saveWebDavSettings() async {
    await _webDavService.saveCredentials(
      url: _webdavUrlController.text,
      username: _webdavUsernameController.text,
      password: _webdavPasswordController.text,
      folderPath: _webdavFolderController.text,
      autoSync: _webdavAutoSync,
    );
  }

  Future<void> _handleTestWebDav() async {
    setState(() => _isWebDavTesting = true);
    await _saveWebDavSettings();
    final bool success = await _webDavService.testConnection(
      _webdavUrlController.text,
      _webdavUsernameController.text,
      _webdavPasswordController.text,
    );
    setState(() => _isWebDavTesting = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "✅ ភ្ជាប់ទៅកាន់ WebDAV ជោគជ័យ!"
              : "❌ មិនអាចភ្ជាប់ទៅកាន់ WebDAV ទេ! សូមពិនិត្យព័ត៌មានឡើងវិញ",
        ),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Future<void> _handleUploadWebDav() async {
    setState(() => _isWebDavSyncing = true);
    await _saveWebDavSettings();
    final bool success = await _webDavService.uploadDatabase();
    setState(() => _isWebDavSyncing = false);

    if (!mounted) return;
    if (success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_done, color: Colors.indigo),
              SizedBox(width: 8),
              Text("Sync ជោគជ័យ!"),
            ],
          ),
          content: const Text(
            "ឯកសារ Database (.db) ត្រូវបានបម្រុងទុកទៅកាន់ Synology NAS (WebDAV) រួចរាល់ហើយ!",
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "យល់ព្រម",
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ ការបម្រុងទុកទៅ WebDAV បរាជ័យ! សូមពិនិត្យការតភ្ជាប់"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ════════════════════════════════════════
  //  🔒 VPN Card Widget
  // ════════════════════════════════════════

  Widget _buildVpnCard() {
    final bool isConnected = _vpnConnected;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isConnected ? Colors.green.shade300 : Colors.red.shade200,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Icon(
                  Icons.vpn_lock,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  "VPN Settings (L2TP/IPsec)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.deepPurple,
                  ),
                ),
                const Spacer(),
                // ── Status badge ──
                _vpnChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey,
                        ),
                      )
                    : GestureDetector(
                        onTap: _checkVpnStatus,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isConnected
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isConnected
                                  ? Colors.green.shade400
                                  : Colors.red.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: isConnected ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isConnected ? "Connected" : "Disconnected",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isConnected
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),

            const SizedBox(height: 14),

            // ── VPN Config Fields ──
            _buildVpnField(
              controller: _vpnServerController,
              label: "VPN Server (Public IP)",
              hint: "ឧ. 36.37.132.233",
              icon: Icons.dns_outlined,
            ),
            const SizedBox(height: 8),
            _buildVpnField(
              controller: _vpnPskController,
              label: "Pre-Shared Key (PSK)",
              hint: "លេខសម្ងាត់ IPsec",
              icon: Icons.key_outlined,
              obscure: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildVpnField(
                    controller: _vpnUsernameController,
                    label: "Username",
                    hint: "ឧ. chanpolin",
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildVpnField(
                    controller: _vpnPasswordController,
                    label: "Password",
                    hint: "ពាក្យសម្ងាត់",
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Info box ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.deepPurple),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "ជំហាន: ១) រក្សាទុក Config → ២) ចុចភ្ជាប់ VPN → ៣) ភ្ជាប់ VPN-KPC ក្នុង System → ៤) Back ទៅ App — Status នឹង Green ស្វ័យប្រវត្ត",
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.deepPurple,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Buttons Row ──
            Row(
              children: [
                // Save Config
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: _vpnSaving
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.deepPurple),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text("💾 រក្សាទុក",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _vpnSaving ? null : _handleSaveVpnConfig,
                  ),
                ),
                const SizedBox(width: 8),
                // Open VPN Settings
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected
                          ? Colors.green
                          : Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      elevation: 0,
                    ),
                    icon: Icon(
                      isConnected ? Icons.vpn_key : Icons.vpn_key_outlined,
                      size: 18,
                    ),
                    label: Text(
                      isConnected
                          ? "🔒 VPN Connected — Sync Ready"
                          : "🔒 ភ្ជាប់ VPN ឥឡូវ",
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isConnected ? _checkVpnStatus : _handleOpenVpnSettings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVpnField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple)),
        const SizedBox(height: 3),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
              prefixIcon: Icon(icon, size: 15, color: Colors.deepPurple),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.deepPurple)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSaveVpnConfig() async {
    setState(() => _vpnSaving = true);
    await _vpnService.saveConfig(
      server: _vpnServerController.text,
      psk: _vpnPskController.text,
      username: _vpnUsernameController.text,
      password: _vpnPasswordController.text,
    );
    setState(() => _vpnSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ VPN Config រក្សាទុករួចរាល់! ចុច 'ភ្ជាប់ VPN' ដើម្បីភ្ជាប់"),
        backgroundColor: Colors.deepPurple,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleOpenVpnSettings() async {
    // Save first before opening settings so user can reference the config
    await _vpnService.saveConfig(
      server: _vpnServerController.text,
      psk: _vpnPskController.text,
      username: _vpnUsernameController.text,
      password: _vpnPasswordController.text,
    );

    final bool opened = await _vpnService.openVpnSettings();
    if (!mounted) return;

    if (!opened) {
      // Show manual guide if can't auto-open
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_lock, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text("ណែនាំការភ្ជាប់ VPN",
                  style: TextStyle(fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "សូមចូល Settings → Connections → VPN ហើយភ្ជាប់ VPN-KPC ដោយប្រើ Config ខាងក្រោម:",
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              _vpnInfoRow("Server", _vpnServerController.text),
              _vpnInfoRow("Type", "L2TP/IPsec PSK"),
              _vpnInfoRow("Username", _vpnUsernameController.text),
              _vpnInfoRow("PSK", _vpnPskController.text.isEmpty
                  ? "(ដូចដែលបានកំណត់)"
                  : "●" * _vpnPskController.text.length.clamp(0, 8)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("យល់ព្រម",
                  style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Widget _vpnInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text("$label: ",
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple)),
          Expanded(
            child: Text(value.isEmpty ? "-" : value,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

