import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/readings.dart';
import '../../db/dbhelper.dart';

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
  DateTime _focusedDate = DateTime.now();
  List<Reading> _allReadings = [];
  bool _isLoading = true;

  static const Color _fresh = Color(0xFF56DFB1);
  static const Color _moderate = Color(0xFFFFAA00);
  static const Color _spoiled = Color(0xFFFF5252);
  static const Color _bg = Color(0xFF021E28);
  static const Color _accent = Color(0xFF56DFB1);

  // ── Y-axis: FRESH = top (high pF), SPOILED = bottom (low pF) ──
  static const double _minPf = 0.0;
  static const double _maxPf = 10.0;
  static const double _spoiledMax = 3.3; // 0 – 3.3 pF  = Spoiled  (bottom)
  static const double _moderateMax = 5.3; // 3.4 – 5.3 pF = Moderate (middle)
  // 5.4 – 10 pF = Fresh (top)

  // ── Horizontal scroll (pan only, no zoom) ──
  // The visible window is always 12 hours wide.
  static const double _totalHours = 24.0;
  static const double _visibleHours = 12.0; // always show 12-hour window

  double _offsetX = 0.0; // left edge of the visible window, in hours

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    final readings = await DBhelper.instance.fetchReadingsBySample(
      widget.sampleId,
    );
    if (mounted) {
      setState(() {
        _allReadings = readings;
        _isLoading = false;
        if (readings.isNotEmpty) {
          final sorted = [...readings]
            ..sort((a, b) => a.carriedOutAt.compareTo(b.carriedOutAt));
          _focusedDate = DateTime.parse(sorted.last.carriedOutAt);
        } else {
          _focusedDate = DateTime.now();
        }
        _offsetX = 0.0; // always start at midnight
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

  Color _dotColorForValue(double y) {
    if (y <= _spoiledMax) return _spoiled;
    if (y <= _moderateMax) return _moderate;
    return _fresh;
  }

  List<Reading> _filteredReadings() {
    return [..._allReadings]
      ..sort((a, b) => a.carriedOutAt.compareTo(b.carriedOutAt))
      ..retainWhere((r) {
        final dt = DateTime.parse(r.carriedOutAt);
        return dt.year == _focusedDate.year &&
            dt.month == _focusedDate.month &&
            dt.day == _focusedDate.day;
      });
  }

  void _previousDay() => setState(() {
    _focusedDate = _focusedDate.subtract(const Duration(days: 1));
    _offsetX = 0.0;
  });

  void _nextDay() => setState(() {
    _focusedDate = _focusedDate.add(const Duration(days: 1));
    _offsetX = 0.0;
  });

  String _dateLabel() {
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
    return "${months[_focusedDate.month]} "
        "${_focusedDate.day.toString().padLeft(2, '0')}, "
        "${_focusedDate.year}";
  }

  // Clamp offset so the window never goes past midnight or 11 PM
  void _clampOffset() {
    _offsetX = _offsetX.clamp(0.0, _totalHours - _visibleHours);
  }

  double get _minX => _offsetX;
  double get _maxX => _offsetX + _visibleHours;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    final readings = _isLoading ? <Reading>[] : _filteredReadings();

    final List<FlSpot> spots = readings.map((r) {
      final dt = DateTime.parse(r.carriedOutAt);
      final x = dt.hour + dt.minute / 60.0;
      final y = r.value.clamp(_minPf, _maxPf).toDouble();
      return FlSpot(x, y);
    }).toList()..sort((a, b) => a.x.compareTo(b.x));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sw * 0.055,
            vertical: sh * 0.022,
          ),
          child: Column(
            children: [
              SizedBox(height: sh * 0.02),

              // ── HEADER ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: sw * 0.03,
                        vertical: sh * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(sw * 0.02),
                      ),
                      child: Text(
                        "«",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: sw * 0.045,
                          fontWeight: FontWeight.w800,
                          color: _bg,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: sw * 0.04),
                  Text(
                    widget.sampleLabel,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: sw * 0.058,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              SizedBox(height: sh * 0.025),

              // ── DATE NAVIGATOR ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousDay,
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    iconSize: sw * 0.06,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Text(
                    _dateLabel(),
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: sw * 0.038,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextDay,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                    iconSize: sw * 0.06,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              SizedBox(height: sh * 0.025),

              // ── CHART (horizontal pan only) ──
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
                            fontSize: sw * 0.038,
                          ),
                        ),
                      )
                    : GestureDetector(
                        // Horizontal drag to pan within the day
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            // Pixels → hours: chart width ≈ sw * 0.82
                            final hoursPerPixel = _visibleHours / (sw * 0.82);
                            _offsetX -= details.delta.dx * hoursPerPixel;
                            _clampOffset();
                          });
                        },
                        child: LineChart(
                          LineChartData(
                            minX: _minX,
                            maxX: _maxX,
                            minY: _minPf,
                            maxY: _maxPf,
                            clipData: const FlClipData.all(),

                            // ── Tooltip ──
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    Reading? closest;
                                    double minDist = double.infinity;
                                    for (final r in readings) {
                                      final dt = DateTime.parse(r.carriedOutAt);
                                      final rx = dt.hour + dt.minute / 60.0;
                                      final dist = (rx - spot.x).abs();
                                      if (dist < minDist) {
                                        minDist = dist;
                                        closest = r;
                                      }
                                    }
                                    return LineTooltipItem(
                                      "${spot.y.toStringAsFixed(2)} pF\n${closest?.category ?? ''}",
                                      TextStyle(
                                        fontFamily: "Inter",
                                        fontSize: sw * 0.030,
                                        fontWeight: FontWeight.w700,
                                        color: _categoryColor(
                                          closest?.category,
                                        ),
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),

                            // ── Grid ──
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 0.5,
                              getDrawingHorizontalLine: (_) => FlLine(
                                color: Colors.white.withOpacity(0.05),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),

                            // ── Axes ──
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: sw * 0.14,
                                  interval: 0.5,
                                  getTitlesWidget: (value, meta) {
                                    // Only label whole numbers to avoid clutter
                                    if (value % 1 != 0) return const SizedBox();
                                    return Text(
                                      "${value.toInt()} pF",
                                      style: TextStyle(
                                        fontFamily: "Inter",
                                        fontSize: sw * 0.022,
                                        color: Colors.white38,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // 2-hour intervals on x-axis
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 2,
                                  getTitlesWidget: (value, meta) {
                                    final hour = value.round();
                                    if (hour % 2 != 0) return const SizedBox();
                                    final String label;
                                    if (hour == 0 || hour == 24)
                                      label = '12AM';
                                    else if (hour == 12)
                                      label = '12PM';
                                    else if (hour < 12)
                                      label = '${hour}AM';
                                    else
                                      label = '${hour - 12}PM';
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontFamily: "Inter",
                                          fontSize: sw * 0.022,
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

                            // ── Category bands: FRESH=top, SPOILED=bottom ──
                            rangeAnnotations: RangeAnnotations(
                              horizontalRangeAnnotations: [
                                HorizontalRangeAnnotation(
                                  y1: _minPf,
                                  y2: _spoiledMax,
                                  color: _spoiled.withOpacity(0.08),
                                ),
                                HorizontalRangeAnnotation(
                                  y1: _spoiledMax,
                                  y2: _moderateMax,
                                  color: _moderate.withOpacity(0.08),
                                ),
                                HorizontalRangeAnnotation(
                                  y1: _moderateMax,
                                  y2: _maxPf,
                                  color: _fresh.withOpacity(0.08),
                                ),
                              ],
                            ),

                            // ── Threshold dashed lines with labels ──
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
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
                                      fontSize: sw * 0.026,
                                      color: _spoiled.withOpacity(0.8),
                                      fontWeight: FontWeight.w700,
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
                                      fontSize: sw * 0.026,
                                      color: _moderate.withOpacity(0.8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                HorizontalLine(
                                  y: _maxPf,
                                  color: _fresh.withOpacity(0.4),
                                  strokeWidth: 1,
                                  dashArray: [4, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.bottomLeft,
                                    labelResolver: (_) => "  FRESH",
                                    style: TextStyle(
                                      fontFamily: "Inter",
                                      fontSize: sw * 0.026,
                                      color: _fresh.withOpacity(0.8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // ── Line ──
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                curveSmoothness: 0.35,
                                color: _accent,
                                barWidth: 2.5,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) {
                                        return FlDotCirclePainter(
                                          radius: 5,
                                          color: _dotColorForValue(spot.y),
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
              ),

              SizedBox(height: sh * 0.010),

              // ── Scroll hint ──
              if (!_isLoading && readings.isNotEmpty)
                Text(
                  "Swipe left / right to scroll",
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: sw * 0.028,
                    color: Colors.white24,
                  ),
                ),

              SizedBox(height: sh * 0.016),

              // ── LEGEND ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: _fresh, label: "Fresh"),
                  SizedBox(width: sw * 0.05),
                  _LegendDot(color: _moderate, label: "Moderate"),
                  SizedBox(width: sw * 0.05),
                  _LegendDot(color: _spoiled, label: "Spoiled"),
                ],
              ),

              SizedBox(height: sh * 0.022),

              // ── VIEW AS LIST ──
              SizedBox(
                width: sw * 0.70,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _bg,
                    padding: EdgeInsets.symmetric(vertical: sh * 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(sw * 0.04),
                    ),
                  ),
                  child: Text(
                    "VIEW AS LIST",
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: sw * 0.043,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              SizedBox(height: sh * 0.012),
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
    final sw = MediaQuery.of(context).size.width;
    return Row(
      children: [
        Container(
          width: sw * 0.025,
          height: sw * 0.025,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: sw * 0.015),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Inter",
            fontSize: sw * 0.032,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
