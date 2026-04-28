import 'package:flutter/material.dart';

class DisplaySettingsData {
  final bool showCalibrationBaseline;
  final bool showCapacitanceDifference;
  final bool showStabilityIndicator;

  const DisplaySettingsData({
    this.showCalibrationBaseline = false,
    this.showCapacitanceDifference = false,
    this.showStabilityIndicator = false,
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
}

// ============================================================
// DUMMY DATA — swap this out when your service is ready
// ============================================================
const DisplaySettingsData kDummyDisplayData = DisplaySettingsData(
  showCalibrationBaseline: true,
  showCapacitanceDifference: true,
  showStabilityIndicator: true,
);

// ============================================================
// RESPONSIVE HELPERS
// ============================================================

/// Scales a font size relative to a 390 px reference width (iPhone 14).
/// Clamped to ±20 % of the base value.
double _rfs(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  return (base * (width / 390.0)).clamp(base * 0.8, base * 1.2);
}

/// Scales a spacing / dimension value the same way.
double _rs(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  return (base * (width / 390.0)).clamp(base * 0.75, base * 1.3);
}

// ============================================================
// DISPLAY SETTINGS SCREEN
// ============================================================
class SettingsDisplayScreen extends StatefulWidget {
  /// Inject real data from your service layer; falls back to dummy data.
  final DisplaySettingsData? data;

  // ── Callbacks ── wire these to your service/BLoC later ────
  /// Called whenever any toggle changes.
  /// Receives the full updated [DisplaySettingsData] snapshot.
  final ValueChanged<DisplaySettingsData>? onSettingsChanged;

  /// Fine-grained callbacks if you prefer per-field wiring.
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

  DisplaySettingsData get _effectiveData => widget.data ?? kDummyDisplayData;

  @override
  void initState() {
    super.initState();
    _settings = _effectiveData;
  }

  @override
  void didUpdateWidget(SettingsDisplayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync local state when real data arrives from outside.
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

  // ── Helpers ───────────────────────────────────────────────
  void _update(DisplaySettingsData updated) {
    setState(() => _settings = updated);
    widget.onSettingsChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double hPad = (mq.size.width * 0.05).clamp(14.0, 28.0);

    return Scaffold(
      backgroundColor: _bgColor,
      // ── AppBar ─────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0, // keeps bg flat when scrolled under
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left, color: Colors.white, size: 28),
              const SizedBox(width: 2),
              Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _rfs(context, 16),
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 80,
      ),
      // ── Body ───────────────────────────────────────────────
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Screen title
            _ScreenTitle(accentRed: _accentRed),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: _rs(context, 12),
                ),
                child: Column(
                  children: [
                    // Toggle: Calibration Baseline
                    _DisplayToggleCard(
                      label: 'Display Calibration Baseline value\non Analysis Page',
                      value: _settings.showCalibrationBaseline,
                      onChanged: (val) {
                        _update(_settings.copyWith(showCalibrationBaseline: val));
                        widget.onCalibrationBaselineToggled?.call(val);
                      },
                      cardColor: _cardColor,
                      accentCyan: _accentCyan,
                      labelColor: _labelColor,
                    ),
                    SizedBox(height: _rs(context, 12)),

                    // Toggle: Capacitance Difference
                    _DisplayToggleCard(
                      label:
                          'Display capacitance difference per IDE\nchannel in the analysis page',
                      value: _settings.showCapacitanceDifference,
                      onChanged: (val) {
                        _update(_settings.copyWith(showCapacitanceDifference: val));
                        widget.onCapacitanceDifferenceToggled?.call(val);
                      },
                      cardColor: _cardColor,
                      accentCyan: _accentCyan,
                      labelColor: _labelColor,
                    ),
                    SizedBox(height: _rs(context, 12)),

                    // Toggle: Stability Indicator
                    _DisplayToggleCard(
                      label: 'Display stability indicator',
                      value: _settings.showStabilityIndicator,
                      onChanged: (val) {
                        _update(_settings.copyWith(showStabilityIndicator: val));
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

// ── Screen Title ─────────────────────────────────────────────
class _ScreenTitle extends StatelessWidget {
  final Color accentRed;
  const _ScreenTitle({required this.accentRed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: _rs(context, 4),
        bottom: _rs(context, 20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monitor,
            color: accentRed,
            size: _rs(context, 32),
          ),
          SizedBox(width: _rs(context, 10)),
          Text(
            'Display',
            style: TextStyle(
              color: Colors.white,
              fontSize: _rfs(context, 22),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Display Toggle Card ───────────────────────────────────────
/// A self-contained, reusable toggle card.
/// All colours are passed in so it stays theme-agnostic.
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
        horizontal: _rs(context, 20),
        vertical: _rs(context, 18),
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_rs(context, 14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label — flex so it never pushes the switch off-screen
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: _rfs(context, 14),
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(width: _rs(context, 12)),
          // Switch
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