import 'package:flutter/material.dart';

class CustomerCard extends StatelessWidget {
  final Map<String, dynamic> cust;
  final bool isActive;
  final String inputMode;
  final TextEditingController mainController;
  final FocusNode focusNode;
  final TextEditingController multController;
  final double previewUsage;
  final VoidCallback onTap;
  final Function(String) onPreviewChanged;
  final Function(String) onSubmitted;

  const CustomerCard({
    super.key,
    required this.cust,
    required this.isActive,
    required this.inputMode,
    required this.mainController,
    required this.focusNode,
    required this.multController,
    required this.previewUsage,
    required this.onTap,
    required this.onPreviewChanged,
    required this.onSubmitted,
  });

  // 🚀 មុខងារបង្ហាញផ្ទាំង Dialog ប្រវត្តិប្រើប្រាស់ប្រចាំខែដេញថយក្រោយ
  void _showHistoryDialog(
    BuildContext context,
    List<String> sortedDateKeys,
    String currentMonthName,
    double lastMonthUsage,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.history_edu, color: Colors.blue.shade900),
              const SizedBox(width: 8),
              const Text(
                "សូមពិនិត្យប្រវត្តិប្រើប្រាស់៖",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildHistoryRow(
                  "ខែនេះ ($currentMonthName)",
                  "${previewUsage.toStringAsFixed(1)} kWh",
                  Colors.blue.shade900,
                  isBold: true,
                ),
                const Divider(),
                if (sortedDateKeys.length >= 2) ...[
                  for (int i = sortedDateKeys.length - 2; i >= 0; i--) ...[
                    _buildHistoryRow(
                      "ខែមុន (${sortedDateKeys[i]})",
                      "${double.tryParse(cust[sortedDateKeys[i]]?.toString() ?? '0')?.toStringAsFixed(1)} kWh",
                      Colors.black87,
                    ),
                    if (i > 0) const Divider(height: 8, thickness: 0.5),
                  ],
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      "មិនមានប្រវត្តិខែចាស់ៗផ្សេងទៀតទេ",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade900,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "បិទផ្ទាំង",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryRow(
    String title,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? color : Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final String name = cust['name']?.toString() ?? "";

    final double oldVal =
        double.tryParse(
          cust['old_value']?.toString() ?? cust['old']?.toString() ?? '0',
        ) ??
        0;

    final double currentNew = double.tryParse(mainController.text) ?? 0;

    // 💡 ប្រព័ន្ធស្កេនរក Column ខែ-ឆ្នាំ
    double lastMonthUsage = 0.0;
    String lastMonthName = "ខែមុន";
    String currentMonthName = "05-2026";
    List<String> dateKeys = [];

    try {
      dateKeys = cust.keys.where((key) {
        return RegExp(r'^\d{2}-\d{4}$').hasMatch(key);
      }).toList();

      if (dateKeys.isNotEmpty) {
        dateKeys.sort((a, b) {
          List<String> partsA = a.split('-');
          List<String> partsB = b.split('-');
          int yearA = int.parse(partsA[1]);
          int monthA = int.parse(partsA[0]);
          int yearB = int.parse(partsB[1]);
          int monthB = int.parse(partsB[0]);

          if (yearA != yearB) return yearA.compareTo(yearB);
          return monthA.compareTo(monthB);
        });

        currentMonthName = dateKeys.last;

        if (dateKeys.length >= 2) {
          lastMonthName = dateKeys[dateKeys.length - 2];
        } else {
          lastMonthName = dateKeys.last;
        }

        lastMonthUsage =
            double.tryParse(cust[lastMonthName]?.toString() ?? '0') ?? 0.0;
      }
    } catch (e) {
      debugPrint("❌ កំហុសក្នុងការស្កេនរក Column ខែ-ឆ្នាំ៖ $e");
    }

    // 🎯 ប្រព័ន្ធវិភាគភាពមិនប្រក្រតី
    String anomalyStatus = "";
    if (mainController.text.isNotEmpty &&
        mainController.text.trim() != "" &&
        currentNew > 0) {
      // ពិនិត្យករណីអតិថិជនថ្មី (អំណានចាស់ = 0 និងប្រវត្តិប្រើប្រាស់ 0 ទាំង 12 ខែ)
      bool isNewCustomer = oldVal == 0 &&
          (dateKeys.isEmpty ||
              dateKeys.every((key) =>
                  (double.tryParse(cust[key]?.toString() ?? '0') ?? 0) == 0));

      if (isNewCustomer) {
        final String ampClean = cust['amp']?.toString().toUpperCase().replaceAll(' ', '') ?? '';
        if ((ampClean == '10A' || ampClean == '10') && previewUsage > 50) {
          anomalyStatus = "⚠️ កើនឡើងខ្លាំងខុសធម្មតា";
        } else if ((ampClean == '20A' || ampClean == '20') && previewUsage > 100) {
          anomalyStatus = "⚠️ កើនឡើងខ្លាំងខុសធម្មតា";
        } else if ((ampClean == '32A' || ampClean == '32') && previewUsage > 150) {
          anomalyStatus = "⚠️ កើនឡើងខ្លាំងខុសធម្មតា";
        } else if ((ampClean == '63A' || ampClean == '63') && previewUsage > 300) {
          anomalyStatus = "⚠️ កើនឡើងខ្លាំងខុសធម្មតា";
        }
      } else {
        if (previewUsage == 0 && lastMonthUsage > 1.6) {
          anomalyStatus = "🔴 សូន្យខុសធម្មតា";
        } else if (lastMonthUsage > 0 &&
            previewUsage >= (lastMonthUsage * 2) &&
            previewUsage > 10) {
          anomalyStatus = "⚠️ កើនឡើងខ្លាំងខុសធម្មតា";
        } else if (lastMonthUsage > 0 && previewUsage < (lastMonthUsage * 0.3)) {
          anomalyStatus = "🟠 ថយចុះខ្លាំងខុសធម្មតា";
        }
      }
    }

    // 🎨 ប្រព័ន្ធពណ៌ប្រអប់ព័ត៌មានវិភាគ
    Color containerBg;
    Color textColor;
    IconData statusIcon;

    if (currentNew > 0 && currentNew < oldVal) {
      containerBg = Colors.orange.shade50;
      textColor = Colors.orange.shade900;
      statusIcon = Icons.cached;
    } else if (anomalyStatus.contains("🔴")) {
      containerBg = Colors.red.shade50;
      textColor = Colors.red.shade900;
      statusIcon = Icons.error_outline;
    } else if (anomalyStatus.contains("ថយចុះ") ||
        anomalyStatus.contains("⚠️")) {
      containerBg = Colors.amber.shade50;
      textColor = Colors.orange.shade900;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      containerBg = Colors.blue.shade50;
      textColor = Colors.blue.shade900;
      statusIcon = Icons.bar_chart;
    }

    return Card(
      elevation: isActive ? 6 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.blue : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        // 🚀 គន្លឹះសំខាន់៖ ពេលចុចលើផ្ទៃ Card ទាំងមូល វានឹងរត់ទៅ Focus ក្នុងប្រអប់បញ្ចូលភ្លាមៗ
        onTap: () {
          onTap(); // ហៅមុខងារជ្រើសរើស Card ដើមរបស់ HomeScreen
          // 🎯 Auto Focus ចំពោះ Manual Mode ប៉ុណ្ណោះ ដើម្បីការពារ Keyboard លោតពេល Camera/Voice Mode
          if (inputMode == 'manual') {
            focusNode.requestFocus();
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ក្បាលកាតបង្ហាញកូដ និងប្រអប់
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "កូដ: ${cust['code'] ?? ''}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                      fontSize: 14,
                    ),
                  ),
                  if (cust['box'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "ប្រអប់: ${cust['box']}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              // ជួរនាឡិកាស្ទង់ និងអំពែរ
              Text(
                "នាឡិកាស្ទង់ [Meter]: ${cust['meter'] ?? '-'}  |  អំពែរ [amp]: ${cust['amp'] ?? '-'}",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const Divider(height: 16, thickness: 0.5),

              // ជួរអំណានចាស់ និងខែមុន
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "អំណានចាស់: ${oldVal.toStringAsFixed(1)}",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "ខែមុន ($lastMonthName): ${lastMonthUsage.toStringAsFixed(1)} kWh",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 🎯 ប្រអប់បញ្ចូលលេខអំណានថ្មីវែងដាច់ពេញអេក្រង់ ទំហំលេខ ២២ ធំច្បាស់ល្អ
              TextField(
                controller: mainController,
                focusNode: focusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                // 🚀 ដំណោះស្រាយដាច់ណាត់៖ ប្តូរទៅជា Done ដើម្បីឱ្យចុចដាច់ការងារតែម្ដង
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                decoration: InputDecoration(
                  labelText: "Enter អំណានថ្មី",
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(
                    Icons.edit,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                onChanged: onPreviewChanged,
                // 🚀 ពេលវាយលេខចប់ហើយចុចប៊ូតុង Done នៅលើ Keyboard វានឹងរុញទៅរក្សាទុកដាច់ណាត់ចូល SQLite ភ្លាមៗ!
                onSubmitted: (value) {
                  onSubmitted(value);
                },
              ),
              const SizedBox(height: 10),

              // ជួរមេគុណឧបករណ៍ដេកខាងក្រោម
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    "មេគុណ៖ ",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  SizedBox(
                    width: 90,
                    height: 38,
                    child: TextField(
                      controller: multController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onChanged: (val) {
                        onPreviewChanged(mainController.text);
                      },
                      onSubmitted: onSubmitted,
                    ),
                  ),
                ],
              ),

              // ផ្នែកប្រអប់បង្ហាញព័ត៌មានវិភាគភាពមិនប្រក្រតី
              if (mainController.text.isNotEmpty &&
                  mainController.text.trim() != "") ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    _showHistoryDialog(
                      context,
                      dateKeys,
                      currentMonthName,
                      lastMonthUsage,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: containerBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: textColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 18, color: textColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (currentNew > 0 && currentNew < oldVal)
                                ? "វិលជុំស្មាន: ${previewUsage.toStringAsFixed(2)}"
                                : (anomalyStatus.isNotEmpty
                                      ? "⚠️ $anomalyStatus: ${previewUsage.toStringAsFixed(2)} kWh"
                                      : "ប្រើប្រាស់ប្រក្រតី: ${previewUsage.toStringAsFixed(2)} kWh"),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
