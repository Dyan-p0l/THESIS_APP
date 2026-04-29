import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys used across both screens
class DisplaySettingsKeys {
  static const calibrationBaseline = 'display_calibration_baseline';
  static const capacitanceDifference = 'display_capacitance_difference';
  static const stabilityIndicator = 'display_stability_indicator';
}

class DisplaySettingsData {
  final bool showCalibrationBaseline;
  final bool showCapacitanceDifference;
  final bool showStabilityIndicator;

  const DisplaySettingsData({
    this.showCalibrationBaseline = true,   // ← default ON
    this.showCapacitanceDifference = true,
    this.showStabilityIndicator = true,
  });

  DisplaySettingsData copyWith({
    bool? showCalibrationBaseline,
    bool? showCapacitanceDifference,
    bool? showStabilityIndicator,
  }) {
    return DisplaySettingsData(
      showCalibrationBaseline:
          showCalibrationBaseline ?? this.showCalibrationBaseline,
      showCapacitanceDifference:
          showCapacitanceDifference ?? this.showCapacitanceDifference,
      showStabilityIndicator:
          showStabilityIndicator ?? this.showStabilityIndicator,
    );
  }

  /// Load from SharedPreferences (defaults to all true if not yet saved)
  static Future<DisplaySettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DisplaySettingsData(
      showCalibrationBaseline:
          prefs.getBool(DisplaySettingsKeys.calibrationBaseline) ?? true,
      showCapacitanceDifference:
          prefs.getBool(DisplaySettingsKeys.capacitanceDifference) ?? true,
      showStabilityIndicator:
          prefs.getBool(DisplaySettingsKeys.stabilityIndicator) ?? true,
    );
  }

  /// Persist all fields
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        DisplaySettingsKeys.calibrationBaseline, showCalibrationBaseline);
    await prefs.setBool(
        DisplaySettingsKeys.capacitanceDifference, showCapacitanceDifference);
    await prefs.setBool(
        DisplaySettingsKeys.stabilityIndicator, showStabilityIndicator);
  }
}

// ── Dummy data for preview ────────────────────────────────────
const DisplaySettingsData kDummyDisplayData = DisplaySettingsData(
  showCalibrationBaseline: true,
  showCapacitanceDifference: true,
  showStabilityIndicator: true,
);

// ── Responsive helpers (unchanged) ───────────────────────────
double _rfs(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  return (base * (width / 390.0)).clamp(base * 0.8, base * 1.2);
}

double _rs(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  return (base * (width / 390.0)).clamp(base * 0.75, base * 1.3);
}

// ── Screen ────────────────────────────────────────────────────
class SettingsDisplayScreen extends StatefulWidget {
  final DisplaySettingsData? data;
  final ValueChanged<DisplaySettingsData>? onSettingsChanged;
  final ValueChanged<bool>? onCalibrationBaselineToggled;
  final ValueChanged<bool>? onCapacitanceDifferenceToggled;
  final ValueChanged<bool>? onStabilityIndicatorToggled;

  const SettingsDisplayScreen({
    super.key,
    this.data,
    this.onSettingsChanged,
    this.onCalibrationBaselineToggled,
    this.onCapacitanceDifferenceToggled,
    this.onStabilityIndicatorToggled,
  });

  @override
  State<SettingsDisplayScreen> createState() => _SettingsDisplayScreenState();
}

class _SettingsDisplayScreenState extends State<SettingsDisplayScreen> {
  late DisplaySettingsData _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Prefer injected data, otherwise read from disk
    final loaded = widget.data ?? await DisplaySettingsData.load();
    if (!mounted) return;
    setState(() {
      _settings = loaded;
      _loading = false;
    });
  }

  @override
  void didUpdateWidget(SettingsDisplayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data && widget.data != null) {
      setState(() => _settings = widget.data!);
    }
  }

  // ── Theme ─────────────────────────────────────────────────
  static const Color _bgColor = Color(0xFF021E28);
  static const Color _cardColor = Color.fromARGB(193, 2, 60, 81);
  static const Color _accentCyan = Color(0xFF4DD9C0);
  static const Color _accentRed = Color(0xFFE05A5A);
  static const Color _labelColor = Color(0xFFB0BEC5);

  void _update(DisplaySettingsData updated) {
    setState(() => _settings = updated);
    updated.save(); // ← persist immediately
    widget.onSettingsChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final mq = MediaQuery.of(context);
    final double hPad = (mq.size.width * 0.05).clamp(14.0, 28.0);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left, color: Colors.white, size: 28),
              const SizedBox(width: 2),
              Text('Back',
                  style: TextStyle(
                      color: Colors.white, fontSize: _rfs(context, 16))),
            ],
          ),
        ),
        leadingWidth: 80,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScreenTitle(accentRed: _accentRed),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: hPad, vertical: _rs(context, 12)),
                child: Column(
                  children: [
                    _DisplayToggleCard(
                      label:
                          'Display Calibration Baseline value\non Analysis Page',
                      value: _settings.showCalibrationBaseline,
                      onChanged: (val) {
                        _update(_settings.copyWith(
                            showCalibrationBaseline: val));
                        widget.onCalibrationBaselineToggled?.call(val);
                      },
                      cardColor: _cardColor,
                      accentCyan: _accentCyan,
                      labelColor: _labelColor,
                    ),
                    SizedBox(height: _rs(context, 12)),
                    _DisplayToggleCard(
                      label:
                          'Display capacitance difference per IDE\nchannel in the analysis page',
                      value: _settings.showCapacitanceDifference,
                      onChanged: (val) {
                        _update(_settings.copyWith(
                            showCapacitanceDifference: val));
                        widget.onCapacitanceDifferenceToggled?.call(val);
                      },
                      cardColor: _cardColor,
                      accentCyan: _accentCyan,
                      labelColor: _labelColor,
                    ),
                    SizedBox(height: _rs(context, 12)),
                    _DisplayToggleCard(
                      label: 'Display stability indicator',
                      value: _settings.showStabilityIndicator,
                      onChanged: (val) {
                        _update(_settings.copyWith(
                            showStabilityIndicator: val));
                        widget.onStabilityIndicatorToggled?.call(val);
                      },
                      cardColor: _cardColor,
                      accentCyan: _accentCyan,
                      labelColor: _labelColor,
                    ),
                    SizedBox(height: mq.padding.bottom + _rs(context, 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── sub-widgets unchanged below this line ─────────────────────
class _ScreenTitle extends StatelessWidget {
  final Color accentRed;
  const _ScreenTitle({required this.accentRed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: _rs(context, 4), bottom: _rs(context, 20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor, color: accentRed, size: _rs(context, 32)),
          SizedBox(width: _rs(context, 10)),
          Text('Display',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: _rfs(context, 22),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DisplayToggleCard extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color cardColor;
  final Color accentCyan;
  final Color labelColor;

  const _DisplayToggleCard({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.cardColor,
    required this.accentCyan,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: _rs(context, 20), vertical: _rs(context, 18)),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(_rs(context, 14))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: labelColor,
                    fontSize: _rfs(context, 14),
                    fontWeight: FontWeight.w400,
                    height: 1.4)),
          ),
          SizedBox(width: _rs(context, 12)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: accentCyan,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF37474F),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}