import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:thesis_app/pages/history/models/reading.dart';
import 'package:thesis_app/pages/history/data/mock_readings.dart';

class ViewGraphScreen extends StatefulWidget {
  final String sampleLabel;

  const ViewGraphScreen({super.key, required this.sampleLabel});

  @override
  State<ViewGraphScreen> createState() => _ViewGraphScreenState();
}

class _ViewGraphScreenState extends State<ViewGraphScreen> {
  String _selectedTab = 'Day';
  DateTime _focusedDate = DateTime(2025, 12, 6);

  final List<String> _tabs = ['Day', 'Week', 'Month'];

  static const Color _fresh = Color(0xFF56DFB1);
  static const Color _moderate = Color(0xFFFFAA00);
  static const Color _spoiled = Color(0xFFFF5252);
  static const Color _bg = Color(0xFF021E28);
  static const Color _accent = Color(0xFF56DFB1);

  static const double _freshMax = 20.0;
  static const double _moderateMax = 40.0;
  static const double _spoiledMax = 65.0;

  Color _categoryColor(FreshnessCategory cat) {
    switch (cat) {
      case FreshnessCategory.fresh:
        return _fresh;
      case FreshnessCategory.moderate:
        return _moderate;
      case FreshnessCategory.spoiled:
        return _spoiled;
    }
  }

  List<Reading> _filteredReadings() {
    final all =
        mockReadings.where((r) => r.sampleLabel == widget.sampleLabel).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    switch (_selectedTab) {
      case 'Day':
        return all
            .where(
              (r) =>
                  r.timestamp.year == _focusedDate.year &&
                  r.timestamp.month == _focusedDate.month &&
                  r.timestamp.day == _focusedDate.day,
            )
            .toList();
      case 'Week':
        final start = _focusedDate.subtract(
          Duration(days: _focusedDate.weekday % 7),
        );
        final end = start.add(const Duration(days: 6));
        return all
            .where(
              (r) =>
                  !r.timestamp.isBefore(
                    DateTime(start.year, start.month, start.day),
                  ) &&
                  !r.timestamp.isAfter(
                    DateTime(end.year, end.month, end.day, 23, 59),
                  ),
            )
            .toList();
      case 'Month':
        return all
            .where(
              (r) =>
                  r.timestamp.year == _focusedDate.year &&
                  r.timestamp.month == _focusedDate.month,
            )
            .toList();
      default:
        return all;
    }
  }

  void _previousPeriod() {
    setState(() {
      switch (_selectedTab) {
        case 'Day':
          _focusedDate = _focusedDate.subtract(const Duration(days: 1));
          break;
        case 'Week':
          _focusedDate = _focusedDate.subtract(const Duration(days: 7));
          break;
        case 'Month':
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
          break;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_selectedTab) {
        case 'Day':
          _focusedDate = _focusedDate.add(const Duration(days: 1));
          break;
        case 'Week':
          _focusedDate = _focusedDate.add(const Duration(days: 7));
          break;
        case 'Month':
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
          break;
      }
    });
  }

  String _periodLabel() {
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
    switch (_selectedTab) {
      case 'Day':
        return "${months[_focusedDate.month]} ${_focusedDate.day.toString().padLeft(2, '0')}, ${_focusedDate.year}";
      case 'Week':
        final start = _focusedDate.subtract(
          Duration(days: _focusedDate.weekday % 7),
        );
        final end = start.add(const Duration(days: 6));
        return "${months[start.month]} ${start.day} – ${months[end.month]} ${end.day}";
      case 'Month':
        return "${months[_focusedDate.month]} ${_focusedDate.year}";
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final readings = _filteredReadings();

    final spots = readings.map((r) {
      final x = r.timestamp.hour + r.timestamp.minute / 60.0;
      return FlSpot(x, r.capacitance);
    }).toList();

    final maxY = readings.isEmpty
        ? _spoiledMax
        : (readings.map((r) => r.capacitance).reduce((a, b) => a > b ? a : b) +
                  10)
              .clamp(_spoiledMax, double.infinity);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.055,
            vertical: screenHeight * 0.022,
          ),
          child: Column(
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
                        color: _accent,
                        borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      ),
                      child: Text(
                        "«",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.w800,
                          color: _bg,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Text(
                    widget.sampleLabel,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: screenWidth * 0.058,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),

              // ── DAY / WEEK / MONTH TABS ──
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2E3D),
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                ),
                child: Row(
                  children: _tabs.map((tab) {
                    final selected = _selectedTab == tab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = tab),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.013,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? _accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.03,
                            ),
                          ),
                          child: Text(
                            tab,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: "Inter",
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w700,
                              color: selected ? _bg : Colors.white60,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              SizedBox(height: screenHeight * 0.018),

              // ── DATE NAVIGATOR ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousPeriod,
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    iconSize: screenWidth * 0.06,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Text(
                    _periodLabel(),
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: screenWidth * 0.038,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextPeriod,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                    iconSize: screenWidth * 0.06,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),

              // ── CHART ──
              Expanded(
                child: readings.isEmpty
                    ? Center(
                        child: Text(
                          "No readings for this period.",
                          style: TextStyle(
                            fontFamily: "Inter",
                            color: Colors.white38,
                            fontSize: screenWidth * 0.038,
                          ),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 24,
                          minY: 0,
                          maxY: maxY,
                          clipData: const FlClipData.all(),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 10,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: Colors.white.withOpacity(0.06),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: screenWidth * 0.1,
                                interval: 10,
                                getTitlesWidget: (value, meta) {
                                  if (value % 10 != 0) return const SizedBox();
                                  return Text(
                                    "${value.toInt()}",
                                    style: TextStyle(
                                      fontFamily: "Inter",
                                      fontSize: screenWidth * 0.026,
                                      color: Colors.white38,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 4,
                                getTitlesWidget: (value, meta) {
                                  final labels = {
                                    0.0: '12AM',
                                    4.0: '4AM',
                                    8.0: '8AM',
                                    12.0: '12PM',
                                    16.0: '4PM',
                                    20.0: '8PM',
                                  };
                                  final label = labels[value];
                                  if (label == null) return const SizedBox();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontFamily: "Inter",
                                        fontSize: screenWidth * 0.024,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          // ── Zone bands ──
                          rangeAnnotations: RangeAnnotations(
                            horizontalRangeAnnotations: [
                              HorizontalRangeAnnotation(
                                y1: 0,
                                y2: _freshMax,
                                color: _fresh.withOpacity(0.08),
                              ),
                              HorizontalRangeAnnotation(
                                y1: _freshMax,
                                y2: _moderateMax,
                                color: _moderate.withOpacity(0.08),
                              ),
                              HorizontalRangeAnnotation(
                                y1: _moderateMax,
                                y2: maxY,
                                color: _spoiled.withOpacity(0.08),
                              ),
                            ],
                          ),
                          // ── Zone boundary lines ──
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: _freshMax,
                                color: _fresh.withOpacity(0.4),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topLeft,
                                  labelResolver: (_) => "  FRESH",
                                  style: TextStyle(
                                    fontFamily: "Inter",
                                    fontSize: screenWidth * 0.026,
                                    color: _fresh.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              HorizontalLine(
                                y: _moderateMax,
                                color: _moderate.withOpacity(0.4),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topLeft,
                                  labelResolver: (_) => "  MODERATE",
                                  style: TextStyle(
                                    fontFamily: "Inter",
                                    fontSize: screenWidth * 0.026,
                                    color: _moderate.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              HorizontalLine(
                                y: _spoiledMax,
                                color: _spoiled.withOpacity(0.4),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topLeft,
                                  labelResolver: (_) => "  SPOILED",
                                  style: TextStyle(
                                    fontFamily: "Inter",
                                    fontSize: screenWidth * 0.026,
                                    color: _spoiled.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: _accent,
                              barWidth: 2.5,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  final cat = readings[index].category;
                                  return FlDotCirclePainter(
                                    radius: 5,
                                    color: _categoryColor(cat),
                                    strokeWidth: 2,
                                    strokeColor: _bg,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: _accent.withOpacity(0.08),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // ── LEGEND ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: _fresh, label: "Fresh"),
                  SizedBox(width: screenWidth * 0.05),
                  _LegendDot(color: _moderate, label: "Moderate"),
                  SizedBox(width: screenWidth * 0.05),
                  _LegendDot(color: _spoiled, label: "Spoiled"),
                ],
              ),

              SizedBox(height: screenHeight * 0.022),

              // ── VIEW AS LIST ──
              SizedBox(
                width: screenWidth * 0.70,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _bg,
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    ),
                  ),
                  child: Text(
                    "VIEW AS LIST",
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      children: [
        Container(
          width: screenWidth * 0.025,
          height: screenWidth * 0.025,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: screenWidth * 0.015),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Inter",
            fontSize: screenWidth * 0.032,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
