import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/readings.dart';
import '../../db/dbhelper.dart';
import 'dart:math';

class ViewGraphScreen extends StatefulWidget {
  final int sampleId;
  final String sampleLabel;

  const ViewGraphScreen({
    super.key,
    required this.sampleId,
    required this.sampleLabel,
  });

  @override
  State<ViewGraphScreen> createState() => _ViewGraphScreenState();
}

class _ViewGraphScreenState extends State<ViewGraphScreen> {
  String _selectedTab = 'Day';
  DateTime _focusedDate = DateTime.now();

  List<Reading> _allReadings = [];
  bool _isLoading = true;

  final List<String> _tabs = ['Day', 'Week', 'Month'];

  static const Color _fresh    = Color(0xFF56DFB1);
  static const Color _moderate = Color(0xFFFFAA00);
  static const Color _spoiled  = Color(0xFFFF5252);
  static const Color _bg       = Color(0xFF021E28);
  static const Color _accent   = Color(0xFF56DFB1);

  static const double _freshMax    = 20.0;
  static const double _moderateMax = 40.0;
  static const double _spoiledMax  = 65.0;

  double _categoryY (String? category) {
    final rand = Random().nextDouble();
    switch (category?.toLowerCase()) {
      case 'fresh':
        return 1.0 + rand * 0.5;
      case 'moderate':
        return 21.0 + rand * 0.5;
      case 'spoiled':
        return 41.0 + rand * 0.5;
      default:
        return 1.0 + rand * 0.5;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    final readings = await DBhelper.instance.fetchReadingsBySample(widget.sampleId);
    if (mounted) {
      setState(() {
        _allReadings = readings;
        _isLoading = false;

        // Default focusedDate to the most recent reading's date, or today
        if (readings.isNotEmpty) {
          final sorted = [...readings]
            ..sort((a, b) => a.carriedOutAt.compareTo(b.carriedOutAt));
          _focusedDate = DateTime.parse(sorted.last.carriedOutAt);
        } else {
          _focusedDate = DateTime.now();
        }
      });
    }
  }

  Color _categoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'fresh':
        return _fresh;
      case 'moderate':
        return _moderate;
      case 'spoiled':
        return _spoiled;
      default:
        return _accent;
    }
  }

  List<Reading> _filteredReadings() {
    final all = [..._allReadings]
      ..sort((a, b) => a.carriedOutAt.compareTo(b.carriedOutAt));

    switch (_selectedTab) {
      case 'Day':
        return all.where((r) {
          final dt = DateTime.parse(r.carriedOutAt);
          return dt.year == _focusedDate.year &&
              dt.month == _focusedDate.month &&
              dt.day == _focusedDate.day;
        }).toList();

      case 'Week':
        final start = _focusedDate.subtract(
          Duration(days: _focusedDate.weekday % 7),
        );
        final end = start.add(const Duration(days: 6));
        return all.where((r) {
          final dt = DateTime.parse(r.carriedOutAt);
          return !dt.isBefore(DateTime(start.year, start.month, start.day)) &&
              !dt.isAfter(DateTime(end.year, end.month, end.day, 23, 59));
        }).toList();

      case 'Month':
        return all.where((r) {
          final dt = DateTime.parse(r.carriedOutAt);
          return dt.year == _focusedDate.year &&
              dt.month == _focusedDate.month;
        }).toList();

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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
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
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final readings = _isLoading ? <Reading>[] : _filteredReadings();

    // For 'Day' tab: x-axis is hour of day (0–24)
    // For 'Week' tab: x-axis is day-of-week (0–6)
    // For 'Month' tab: x-axis is day-of-month (1–31)
    List<FlSpot> spots = [];
    double minX = 0, maxX = 24;

    if (!_isLoading) {
      switch (_selectedTab) {
        case 'Day':
          minX = 0; maxX = 24;
            spots = readings.map((r) {
              final dt = DateTime.parse(r.carriedOutAt);
              return FlSpot(dt.hour + dt.minute / 60.0, _categoryY(r.category));
            }).toList();
          break;

        case 'Week':
          final weekStart = _focusedDate.subtract(
            Duration(days: _focusedDate.weekday % 7),
          );
          minX = 0; maxX = 6;
            spots = readings.map((r) {
              final dt = DateTime.parse(r.carriedOutAt);
              final dayOffset = dt.difference(DateTime(
                weekStart.year, weekStart.month, weekStart.day,
              )).inDays.toDouble();
              return FlSpot(dayOffset.clamp(0, 6), _categoryY(r.category));
            }).toList();
          break;

        case 'Month':
          final daysInMonth = DateTime(
            _focusedDate.year, _focusedDate.month + 1, 0,
          ).day;
          minX = 1; maxX = daysInMonth.toDouble();
            spots = readings.map((r) {
              final dt = DateTime.parse(r.carriedOutAt);
              return FlSpot(dt.day.toDouble(), _categoryY(r.category));
            }).toList();
          break;
      }
    }

    final maxY = _spoiledMax + 3;

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
                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
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
                    icon: const Icon(Icons.chevron_right, color: Colors.white70),
                    iconSize: screenWidth * 0.06,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),

              // ── CHART ──
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _accent),
                      )
                    : readings.isEmpty
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
                              minX: minX,
                              maxX: maxX,
                              minY: 0,
                              maxY: maxY,
                              clipData: const FlClipData.all(),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final reading = readings[spot.spotIndex];
                                      return LineTooltipItem(
                                        "${reading.value.toStringAsFixed(2)} pF\n${reading.category ?? ''}",
                                        TextStyle(
                                          fontFamily: "Inter",
                                          fontSize: screenWidth * 0.030,
                                          fontWeight: FontWeight.w700,
                                          color: _categoryColor(reading.category),
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
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
                                      if (value == 10) {
                                        return Text(
                                          "FRESH",
                                          style: TextStyle(
                                            fontFamily: "Inter",
                                            fontSize: screenWidth * 0.026,
                                            color: _fresh.withOpacity(0.85),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      } else if (value == 30) {
                                        return Text(
                                          "MOD.",
                                          style: TextStyle(
                                            fontFamily: "Inter",
                                            fontSize: screenWidth * 0.026,
                                            color: _moderate.withOpacity(0.85),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      } else if (value == 50) {
                                        return Text(
                                          "SPOIL",
                                          style: TextStyle(
                                            fontFamily: "Inter",
                                            fontSize: screenWidth * 0.026,
                                            color: _spoiled.withOpacity(0.85),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: _selectedTab == 'Day' ? 4 : 1,
                                    getTitlesWidget: (value, meta) {
                                      String? label;

                                      if (_selectedTab == 'Day') {
                                        final labels = {
                                          0.0: '12AM', 4.0: '4AM', 8.0: '8AM',
                                          12.0: '12PM', 16.0: '4PM', 20.0: '8PM',
                                        };
                                        label = labels[value];
                                      } else if (_selectedTab == 'Week') {
                                        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                                        final idx = value.toInt();
                                        if (idx >= 0 && idx < 7) label = days[idx];
                                      } else if (_selectedTab == 'Month') {
                                        final v = value.toInt();
                                        if (v % 5 == 0 || v == 1) label = "$v";
                                      }

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
                              rangeAnnotations: RangeAnnotations(
                                horizontalRangeAnnotations: [
                                  HorizontalRangeAnnotation(
                                    y1: 0, y2: _freshMax,
                                    color: _fresh.withOpacity(0.08),
                                  ),
                                  HorizontalRangeAnnotation(
                                    y1: _freshMax, y2: _moderateMax,
                                    color: _moderate.withOpacity(0.08),
                                  ),
                                  HorizontalRangeAnnotation(
                                    y1: _moderateMax, y2: maxY,
                                    color: _spoiled.withOpacity(0.08),
                                  ),
                                ],
                              ),
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
                                      labelResolver: (_) => "",
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
                                      labelResolver: (_) => "",
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
                                      labelResolver: (_) => "",
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
                  _LegendDot(color: _fresh,    label: "Fresh"),
                  SizedBox(width: screenWidth * 0.05),
                  _LegendDot(color: _moderate, label: "Moderate"),
                  SizedBox(width: screenWidth * 0.05),
                  _LegendDot(color: _spoiled,  label: "Spoiled"),
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
                    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
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