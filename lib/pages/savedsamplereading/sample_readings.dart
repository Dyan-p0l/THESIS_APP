import 'package:flutter/material.dart';
import 'package:thesis_app/pages/history/models/reading.dart';
import 'package:thesis_app/pages/history/data/mock_readings.dart';

class SampleReadingsScreen extends StatelessWidget {
  final String sampleLabel;

  const SampleReadingsScreen({super.key, required this.sampleLabel});

  Color _categoryColor(FreshnessCategory category) {
    switch (category) {
      case FreshnessCategory.fresh:
        return const Color(0xFF56DFB1);
      case FreshnessCategory.moderate:
        return const Color(0xFFFFAA00);
      case FreshnessCategory.spoiled:
        return Colors.redAccent;
    }
  }

  IconData _categoryIcon(FreshnessCategory category) {
    switch (category) {
      case FreshnessCategory.fresh:
        return Icons.shield_outlined;
      case FreshnessCategory.moderate:
        return Icons.shield_outlined;
      case FreshnessCategory.spoiled:
        return Icons.warning_amber_rounded;
    }
  }

  String _categoryLabel(FreshnessCategory category) {
    switch (category) {
      case FreshnessCategory.fresh:
        return "FRESH";
      case FreshnessCategory.moderate:
        return "MODERATE";
      case FreshnessCategory.spoiled:
        return "SPOILED";
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
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
    return "${months[dt.month]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF021E28);
    const accent = Color(0xFF56DFB1);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Filter readings for this sample, sorted newest first
    final readings =
        mockReadings.where((r) => r.sampleLabel == sampleLabel).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Group by date
    final Map<String, List<Reading>> grouped = {};
    for (final r in readings) {
      final dateKey = _formatDate(r.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(r);
    }
    final dateKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.055,
            vertical: screenHeight * 0.022,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: screenHeight * 0.02),

              // ── HEADER ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.03,
                        vertical: screenHeight * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      ),
                      child: Text(
                        "«",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF021E28),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Text(
                    sampleLabel,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: screenWidth * 0.058,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.03),

              // ── READINGS LIST grouped by date ──
              Expanded(
                child: ListView.builder(
                  itemCount: dateKeys.length,
                  itemBuilder: (context, dateIndex) {
                    final dateKey = dateKeys[dateIndex];
                    final dayReadings = grouped[dateKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: screenHeight * 0.012,
                            top: dateIndex == 0 ? 0 : screenHeight * 0.02,
                          ),
                          child: Text(
                            dateKey,
                            style: TextStyle(
                              fontFamily: "Inter",
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),

                        // Readings under this date
                        ...dayReadings.map((reading) {
                          final color = _categoryColor(reading.category);
                          final icon = _categoryIcon(reading.category);
                          final label = _categoryLabel(reading.category);

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: screenHeight * 0.014,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Category icon
                                Icon(
                                  icon,
                                  color: color,
                                  size: screenWidth * 0.09,
                                ),

                                SizedBox(width: screenWidth * 0.03),

                                // Capacitance value
                                Text(
                                  "${reading.capacitance.toInt()}pF",
                                  style: TextStyle(
                                    fontFamily: "Inter",
                                    fontSize: screenWidth * 0.07,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),

                                SizedBox(width: screenWidth * 0.03),

                                // Divider line
                                Container(
                                  width: 1,
                                  height: screenHeight * 0.045,
                                  color: Colors.white24,
                                ),

                                SizedBox(width: screenWidth * 0.03),

                                // ID + time
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reading.id,
                                        style: TextStyle(
                                          fontFamily: "Inter",
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                        ),
                                      ),
                                      Text(
                                        _formatTime(reading.timestamp),
                                        style: TextStyle(
                                          fontFamily: "Inter",
                                          fontSize: screenWidth * 0.028,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Category label
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "CATEGORY:",
                                      style: TextStyle(
                                        fontFamily: "Inter",
                                        fontSize: screenWidth * 0.026,
                                        color: Colors.white54,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontFamily: "Inter",
                                        fontSize: screenWidth * 0.03,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // ── VIEW AS GRAPH ──
              SizedBox(
                width: screenWidth * 0.70,
                child: ElevatedButton(
                  onPressed: () {
                    // Will route to graph view later
                    Navigator.pushNamed(context,'/sample_graph', arguments: sampleLabel,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: const Color(0xFF021E28),
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    ),
                  ),
                  child: Text(
                    "VIEW AS GRAPH",
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: screenWidth * 0.043,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.012),
            ],
          ),
        ),
      ),
    );
  }
}
