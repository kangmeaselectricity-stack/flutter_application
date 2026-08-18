import 'package:flutter/material.dart';

class BatteryAnalysisScreen extends StatefulWidget {
  const BatteryAnalysisScreen({super.key});

  @override
  State<BatteryAnalysisScreen> createState() => _BatteryAnalysisScreenState();
}

class _BatteryAnalysisScreenState extends State<BatteryAnalysisScreen> {
  double _customerCount = 600.0;
  int _batteryCapacity = 4000; // in mAh

  // Constants representing power consumption (current draw in mA) and average time per customer (in seconds)
  final Map<String, Map<String, dynamic>> _modesData = {
    'manual': {
      'name': 'បញ្ចូលដោយដៃ (Manual Keyboard)',
      'icon': Icons.keyboard,
      'color': Colors.blue,
      'currentDraw': 200.0, // mA
      'avgTime': 12.0, // seconds
      'description': 'ការវាយបញ្ចូលលេខដោយប្រើក្តារចុចទូរស័ព្ទផ្ទាល់ ល្បឿនល្មម ស៊ីថ្មតិចបំផុត។',
    },
    'voice': {
      'name': 'ស្រង់ដោយសំឡេង (Voice Input)',
      'icon': Icons.mic,
      'color': Colors.orange,
      'currentDraw': 350.0, // mA
      'avgTime': 6.0, // seconds
      'description': 'ការនិយាយបញ្ជាលេខអំណានថ្មី ល្បឿនលឿន ស៊ីថ្មទាបទៅមធ្យម។',
    },
    'camera': {
      'name': 'ស្កេនកាមេរ៉ា (Camera OCR + GPS)',
      'icon': Icons.camera_alt,
      'color': Colors.red,
      'currentDraw': 1000.0, // mA
      'avgTime': 25.0, // seconds
      'description': 'ការថតរូប កាត់តម្រឹម ស្កេន OCR ទីតាំង GPS និងបោះត្រាទឹក។ ស៊ីថ្មខ្លាំងបំផុត។',
    },
    'ble': {
      'name': 'ប៊្លូធូសស្កេន (Bluetooth BLE)',
      'icon': Icons.bluetooth,
      'color': Colors.teal,
      'currentDraw': 250.0, // mA
      'avgTime': 3.5, // seconds
      'description': 'ការអានទិន្នន័យដោយស្វ័យប្រវត្តិតាម Bluetooth រយៈពេលលឿនបំផុត និងសន្សំសំចៃថ្មខ្ពស់។',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "វិភាគការប្រើប្រាស់ថាមពលថ្ម",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
              _buildConfigCard(),
              const SizedBox(height: 20),
              const Text(
                "លទ្ធផលប្រៀបធៀបតាមមុខងារ (Comparison)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              ..._modesData.entries.map((entry) => _buildMethodAnalysisCard(entry.key, entry.value)),
              const SizedBox(height: 20),
              _buildRecommendationsCard(),
              const SizedBox(height: 24),
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
          colors: [Colors.teal, Colors.tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                "របាយការណ៍វិភាគថាមពលថ្ម",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "ការវិភាគ និងប៉ាន់ប្រមាណលើការចុះស្រង់អំណាននាឡិកាស្ទង់ សម្រាប់កម្មវិធីទូរស័ព្ទដៃ ដោយផ្អែកលើការស៊ីថាមពលឧបករណ៍ពិតប្រាកដ។",
            style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.people, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(
                      "ចំនួនអតិថិជនសរុប",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    "${_customerCount.toInt()} នាក់",
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            Slider(
              value: _customerCount,
              min: 100.0,
              max: 3000.0,
              divisions: 29,
              activeColor: Colors.teal,
              inactiveColor: Colors.teal[100],
              label: "${_customerCount.toInt()} នាក់",
              onChanged: (value) {
                setState(() {
                  _customerCount = value;
                });
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.battery_std, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(
                      "ទំហំថ្មទូរស័ព្ទ (Battery Capacity)",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                DropdownButton<int>(
                  value: _batteryCapacity,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                  underline: Container(height: 0),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _batteryCapacity = newValue;
                      });
                    }
                  },
                  items: <int>[3000, 4000, 5000, 6000].map<DropdownMenuItem<int>>((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text("$value mAh"),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodAnalysisCard(String key, Map<String, dynamic> data) {
    final double currentDraw = data['currentDraw'];
    final double avgTime = data['avgTime'];
    final Color color = data['color'];
    final IconData icon = data['icon'];
    final String name = data['name'];
    final String desc = data['description'];

    // Calculations
    final double totalSeconds = _customerCount * avgTime;
    final double totalHours = totalSeconds / 3600.0;
    
    // mAh consumed = Current (mA) * Time (hours)
    final double mahConsumed = currentDraw * totalHours;
    final double percentUsed = (mahConsumed / _batteryCapacity) * 100.0;
    
    final int chargesRequired = (mahConsumed / _batteryCapacity).ceil();

    // Time display format (Hours and Minutes)
    String timeDisplay = "";
    int hrs = totalHours.floor();
    int mins = ((totalHours - hrs) * 60).round();
    if (hrs > 0) {
      timeDisplay += "$hrs ម៉ោង ";
    }
    timeDisplay += "$mins នាទី";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn("រយៈពេលសរុប", timeDisplay),
                _buildMetricColumn("ថាមពលអស់", "${mahConsumed.toStringAsFixed(0)} mAh"),
                _buildMetricColumn("ភាគរយថ្ម", "${percentUsed.toStringAsFixed(1)}%"),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (percentUsed / 100.0).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentUsed > 80.0 ? Colors.red : (percentUsed > 40.0 ? Colors.orange : Colors.green),
                ),
                minHeight: 8,
              ),
            ),
            if (percentUsed > 100.0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "⚠️ ត្រូវការថ្មទូរស័ព្ទពេញចំនួន $chargesRequired ដង ដើម្បីបង្ហើយការងារ!",
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildRecommendationsCard() {
    return Card(
      elevation: 2,
      color: Colors.teal[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.shade200, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  "អនុសាសន៍សម្រាប់ការសន្សំសំចៃថ្ម (Field Tips)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem("ប្រើប្រាស់សំឡេង (Voice Mode) ឬប៊្លូធូស (BLE) នៅពេលអាចធ្វើទៅបាន ព្រោះលឿន និងស៊ីថាមពលថ្មតិចជាងកាមេរ៉ាដល់ទៅ ៣-៤ ដង។"),
            _buildTipItem("ប្រសិនបើត្រូវប្រើកាមេរ៉ាស្កេន OCR គួរតែទម្លាក់ពន្លឺអេក្រង់ទូរស័ព្ទមកត្រឹម ៤០% ឬ ៥០% ដើម្បីជួយសន្សំសំចៃថាមពលបានរហូតដល់ ២០% បន្ថែម។"),
            _buildTipItem("បិទកម្មវិធីផ្សេងៗដែលរត់ក្នុង Background (ដូចជា Social Media, GPS Maps ផ្សេងទៀត) មុនពេលចុះអានកុងទ័រ។"),
            _buildTipItem("ត្រៀម Power Bank ជាប់ខ្លួនជានិច្ច ករណីចំនួនអតិថិជនចាប់ពី ៦០០នាក់ឡើងទៅ ហើយត្រូវប្រើមុខងារស្កេនរូបថតកាមេរ៉ា OCR។"),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Icon(Icons.check_circle_outline, color: Colors.teal, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
