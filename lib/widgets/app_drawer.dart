import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/power_data_screen.dart';
import '../screens/home_screen.dart';
import '../screens/battery_analysis_screen.dart';
import '../screens/backup_sync_screen.dart';

class AppDrawer extends StatefulWidget {
  final int totalCount;
  final int doneCount;
  final String inputMode;
  final void Function(String selectedInspector) onBackup;
  final VoidCallback onImport;
  final void Function(String selectedInspector) onExportExcel;
  final Function(String) onModeChanged;

  const AppDrawer({
    super.key,
    required this.totalCount,
    required this.doneCount,
    required this.inputMode,
    required this.onBackup,
    required this.onImport,
    required this.onExportExcel,
    required this.onModeChanged,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // 🚀 បង្កើត Controller សម្រាប់គ្រប់គ្រងប្រអប់វាយឈ្មោះអ្នកស្រង់
  final TextEditingController _inspectorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSelectedInspector();
  }

  @override
  void dispose() {
    _inspectorController.dispose();
    super.dispose();
  }

  // 🚀 ទាញយកឈ្មោះអ្នកស្រង់ដែលធ្លាប់រក្សាទុកចុងក្រោយពីទូរស័ព្ទមកបង្ហាញ
  Future<void> _loadSelectedInspector() async {
    final prefs = await SharedPreferences.getInstance();
    String savedName = prefs.getString('selected_inspector') ?? "អ្នកស្រង់ទី១";
    setState(() {
      _inspectorController.text = savedName;
    });
  }

  // 🚀 រក្សាទុកឈ្មោះអ្នកស្រង់ចូល Memory ទូរស័ព្ទភ្លាមៗពេលវាយអក្សរ (OnChanged)
  Future<void> _saveInspector(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_inspector', name.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎯 Header ផ្នែកខាងលើបង្ហាញព័ត៌មានក្រុមការងារ
            Container(
              width: double.infinity,
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: Image.asset(
                        "assets/images/edcon.png",
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.electric_meter,
                            color: Colors.blue,
                            size: 26,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "ក្រុមស្រង់អំណាននាឡិកាស្ទង់",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "ថ្ងៃនេះ: ${DateTime.now().toString().split(' ')[0]}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 📊 ផ្នែកបង្ហាញទិន្នន័យស្ថិតិ (សរុប | រួច | សល់) ទំហំស្មើគ្នា
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _statBox(
                      "សរុប",
                      "${widget.totalCount}",
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _statBox("រួច", "${widget.doneCount}", Colors.green),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const HomeScreen(filterRemaining: true),
                          ),
                          (route) => false,
                        );
                      },
                      child: _statBox(
                        "សល់",
                        "${widget.totalCount - widget.doneCount}",
                        Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 🚀 🎯 ផ្នែកបញ្ចូលឈ្មោះអ្នកស្រង់ (TextField) ត្រូវតាមបំណងបងប្រុស ១០០%
            Padding(
              padding: const EdgeInsets.only(
                left: 14,
                top: 8,
                bottom: 4,
                right: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ឈ្មោះអ្នកស្រង់បច្ចុប្បន្ន (Input Name)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.purple[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _inspectorController,
                      decoration: InputDecoration(
                        hintText: "វាយបញ្ចូលឈ្មោះអ្នកស្រង់ទីនេះ...",
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        prefixIcon: const Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.purple,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 10,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (value) {
                        _saveInspector(
                          value,
                        ); // វាយអក្សរបណ្ដើរ លួច Save ទុកបណ្ដើរស្វ័យប្រវត្តិ
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ⚡ មុខងារស្រង់នាឡិកាមេ
            ListTile(
              leading: const Icon(Icons.bolt, color: Colors.teal),
              title: const Text("ស្រង់អំណាននាឡិកាស្ទង់មេ"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PowerDataScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.battery_saver, color: Colors.teal),
              title: const Text("វិភាគការប្រើប្រាស់ថ្ម"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BatteryAnalysisScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync, color: Colors.teal),
              title: const Text("រក្សាទុកលើ Cloud (Cloud Sync)"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BackupSyncScreen(),
                  ),
                );
              },
            ),

            // 📂 ផ្នែកប៊ូតុងមុខងារ (បម្រុងទុកភ្ជាប់ឈ្មោះអ្នកស្រង់ដែលបានវាយ)
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              leading: const Icon(Icons.backup, color: Colors.blue, size: 20),
              title: const Text(
                "បម្រុងទុកទិន្នន័យ (Backup)",
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                String name = _inspectorController.text.trim();
                if (name.isEmpty) name = "មិនស្គាល់ឈ្មោះ";
                widget.onBackup(name); // បោះឈ្មោះទៅក្រៅ
              },
            ),
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              leading: const Icon(
                Icons.border_outer_rounded,
                color: Colors.teal,
                size: 20,
              ),
              title: const Text(
                "នាំចេញបញ្ជីអតិថិនជន",
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                String name = _inspectorController.text.trim();
                if (name.isEmpty) name = "មិនស្គាល់ឈ្មោះ";
                widget.onExportExcel(name); // បោះឈ្មោះទៅក្រៅ
              },
            ),
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              leading: const Icon(
                Icons.file_upload,
                color: Colors.green,
                size: 20,
              ),
              title: const Text(
                "នាំចូលទិន្នន័យខែថ្មី (.db)",
                style: TextStyle(fontSize: 14),
              ),
              onTap: widget.onImport,
            ),
            const Divider(height: 1),

            // 🎯 ផ្នែកវិធីសាស្ត្របញ្ចូលលេខ (Mode)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 6, bottom: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "វិធីសាស្រ្តបញ្ចូលលេខ (Mode)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  _buildModeTile(
                    context,
                    "បញ្ចូលដោយដៃ (Keyboard)",
                    Icons.keyboard,
                    "manual",
                  ),
                  _buildModeTile(
                    context,
                    "ប្រើសម្លេង (Voice Mode)",
                    Icons.mic,
                    "voice",
                  ),
                  _buildModeTile(
                    context,
                    "ប្រើកាមេរ៉ា (Camera Mode)",
                    Icons.camera_alt,
                    "camera",
                  ),
                ],
              ),
            ),

            const Divider(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Version 1.0.3\nBy: HEM CHANPOLIN",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTile(
    BuildContext context,
    String title,
    IconData icon,
    String modeValue,
  ) {
    final bool isSelected = widget.inputMode == modeValue;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      height: 38,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue : Colors.grey[600],
          size: 18,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue[900] : Colors.black87,
          ),
        ),
        trailing: Icon(
          isSelected ? Icons.check_circle : Icons.circle_outlined,
          color: isSelected ? Colors.blue : Colors.grey[400],
          size: 16,
        ),
        onTap: () {
          widget.onModeChanged(modeValue);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _statBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
