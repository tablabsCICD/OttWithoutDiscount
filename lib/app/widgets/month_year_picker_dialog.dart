import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/provider/themeProvider.dart';

const List<String> kBirthMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

List<int> getBirthYears() {
  final currentYear = DateTime.now().year;
  return List.generate(
    currentYear - 1900 + 1,
    (index) => currentYear - index,
  );
}

Map<String, dynamic> parseBirthMonthAndYear(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return {'month': null, 'year': null};
  }
  final text = raw.trim();

  // Pattern 1: "October 1992"
  final parts = text.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    final m = kBirthMonths.firstWhere(
      (m) => m.toLowerCase() == parts[0].toLowerCase(),
      orElse: () => '',
    );
    final y = int.tryParse(parts[1]);
    if (m.isNotEmpty && y != null) {
      return {'month': m, 'year': y};
    }
  }

  // Pattern 2: "1992-10-15" or "1992-10"
  final parsed = DateTime.tryParse(text);
  if (parsed != null && parsed.month >= 1 && parsed.month <= 12) {
    return {
      'month': kBirthMonths[parsed.month - 1],
      'year': parsed.year,
    };
  }

  return {'month': null, 'year': null};
}

Future<Map<String, dynamic>?> showBirthMonthYearPicker({
  required BuildContext context,
  String? currentValue,
}) async {
  final parsed = parseBirthMonthAndYear(currentValue);
  String? selectedMonth = parsed['month'];
  int? selectedYear = parsed['year'];

  final currentYear = DateTime.now().year;
  final currentMonth = DateTime.now().month;
  final years = getBirthYears();
  final themeData = Provider.of<ThemeProvider>(context, listen: false).getTheme;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          String? errorMessage;
          if (selectedYear == currentYear && selectedMonth != null) {
            final monthIndex = kBirthMonths.indexOf(selectedMonth!) + 1;
            if (monthIndex > currentMonth) {
              errorMessage = 'Birth month cannot be in the future';
            }
          }

          return AlertDialog(
            backgroundColor: themeData.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: themeData.primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Birth Month & Year',
                  style: TextStyle(
                    color: themeData.canvasColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Month Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: selectedMonth,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          dropdownColor: themeData.scaffoldBackgroundColor,
                          items: kBirthMonths
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m,
                                    style: TextStyle(
                                      color: themeData.canvasColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedMonth = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Year Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          dropdownColor: themeData.scaffoldBackgroundColor,
                          items: years
                              .map(
                                (y) => DropdownMenuItem(
                                  value: y,
                                  child: Text(
                                    '$y',
                                    style: TextStyle(
                                      color: themeData.canvasColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedYear = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (selectedMonth != null && selectedYear != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: themeData.cardColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: themeData.primaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Selected: $selectedMonth $selectedYear',
                        style: TextStyle(
                          color: themeData.canvasColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(null),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: themeData.canvasColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeData.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (selectedMonth == null ||
                        selectedYear == null ||
                        errorMessage != null)
                    ? null
                    : () {
                        Navigator.of(dialogCtx).pop({
                          'month': selectedMonth,
                          'year': selectedYear,
                        });
                      },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
