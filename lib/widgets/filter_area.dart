import 'package:flutter/material.dart';

class FilterArea extends StatelessWidget {
  final List<String> areas;
  final List<String> poles;
  final List<String> boxes;
  final String? selectedArea;
  final String? selectedPole;
  final String? selectedBox;
  final Function(String?) onAreaChanged;
  final Function(String?) onPoleChanged;
  final Function(String?) onBoxChanged;

  const FilterArea({
    super.key,
    required this.areas,
    required this.poles,
    required this.boxes,
    this.selectedArea,
    this.selectedPole,
    this.selectedBox,
    required this.onAreaChanged,
    required this.onPoleChanged,
    required this.onBoxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the inner row width: constraints.maxWidth - 20 (Card margin) - 20 (Card padding)
        final double innerRowWidth = constraints.maxWidth - 40;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _buildFilterBox("តំបន់", areas, selectedArea, onAreaChanged, menuWidth: innerRowWidth),
                const SizedBox(width: 5),
                _buildFilterBox("បង្គោល", poles, selectedPole, onPoleChanged),
                const SizedBox(width: 5),
                _buildFilterBox("ប្រអប់", boxes, selectedBox, onBoxChanged),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterBox(
    String label,
    List<String> items,
    String? selectedValue,
    Function(String?) onChanged, {
    double? menuWidth,
  }) {
    return Expanded(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            menuWidth: menuWidth,
            hint: Text(label, style: const TextStyle(fontSize: 11)),
            value: selectedValue,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text("ទាំងអស់", style: TextStyle(fontSize: 11)),
              ),
              ...items.map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(v, style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
