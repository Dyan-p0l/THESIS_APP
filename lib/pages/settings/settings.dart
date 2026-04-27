import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settings',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF021E28),
      ),
      home: const SettingsPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Responsive scale helper
// ---------------------------------------------------------------------------
class _Scale {
  final double factor;

  const _Scale(this.factor);

  factory _Scale.of(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return _Scale(w / 390.0);
  }

  double w(double value) => value * factor;
  double f(double value) => value * factor.clamp(0.85, 1.4);
}

class _SettingsItem {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool iconIsInBadge;
  final bool isFaIcon;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.iconIsInBadge = false,
    this.isFaIcon = false,
  });
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const List<_SettingsItem> _items = [
    _SettingsItem(
      icon: FontAwesomeIcons.hexagonNodes,
      iconColor: Color(0xFFF5A623),
      label: 'Model and Performance',
      onTap: _noop,
      isFaIcon: true,
    ),
    _SettingsItem(
      icon: FontAwesomeIcons.database,
      iconColor: Color(0xFF4DD9C0),
      label: 'Data Retention',
      onTap: _noop,
      isFaIcon: true,
    ),
    _SettingsItem(
      icon: FontAwesomeIcons.bluetooth,
      iconColor: Color(0xFF4DD9C0),
      label: 'Connectivity',
      onTap: _noop,
      isFaIcon: true,
    ),
    _SettingsItem(
      icon: FontAwesomeIcons.display,
      iconColor: Color(0xFFE05555),
      label: 'Display',
      onTap: _noop,
      isFaIcon: true,
    ),
    _SettingsItem(
      icon: FontAwesomeIcons.sliders,
      iconColor: Color(0xFFF5A623),
      label: 'Calibration',
      onTap: _noop,
      isFaIcon: true,
    ),
  ];

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final s = _Scale.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF021E28),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: s.w(20),
            vertical: s.w(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.gear,
                    color: Colors.white,
                    size: s.f(24),
                  ),
                  SizedBox(width: s.w(10)),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: s.f(26),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: s.w(10)),
              Text(
                'Configure measurement, model, and system preferences.',
                style: TextStyle(
                  color: const Color(0xFF8CA0B3),
                  fontSize: s.f(13),
                  height: 1.5,
                ),
              ),
              SizedBox(height: s.w(28)),

              // ── Tiles ──────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => SizedBox(height: s.w(14)),
                  itemBuilder: (context, index) =>
                      _SettingsTile(item: _items[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------
class _SettingsTile extends StatelessWidget {
  final _SettingsItem item;

  const _SettingsTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final s = _Scale.of(context);

    final double iconBoxSize = s.w(42);
    final double iconSize    = s.f(26);
    final double badgeRadius = s.w(10);
    final double tileRadius  = s.w(14);
    final double tilePadH    = s.w(18);
    final double tilePadV    = s.w(20);

    // Builds FaIcon or Icon depending on the flag
    Widget buildIcon({required Color color}) {
      return item.isFaIcon
          ? FaIcon(item.icon, color: color, size: iconSize)
          : Icon(item.icon,   color: color, size: iconSize);
    }

    return Material(
      color: const Color.fromARGB(215, 2, 60, 81),
      borderRadius: BorderRadius.circular(tileRadius),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(tileRadius),
        splashColor: const Color(0xFF4DD9C0).withOpacity(0.08),
        highlightColor: const Color(0xFF4DD9C0).withOpacity(0.04),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tilePadH,
            vertical: tilePadV,
          ),
          child: Row(
            children: [
              // Icon — badge style or plain
              item.iconIsInBadge
                  ? Container(
                      width: iconBoxSize,
                      height: iconBoxSize,
                      decoration: BoxDecoration(
                        color: item.iconColor,
                        borderRadius: BorderRadius.circular(badgeRadius),
                      ),
                      child: Center(
                        child: buildIcon(color: Colors.white),
                      ),
                    )
                  : SizedBox(
                      width: iconBoxSize,
                      height: iconBoxSize,
                      child: Center(
                        child: buildIcon(color: item.iconColor),
                      ),
                    ),

              SizedBox(width: s.w(18)),

              // Label — Expanded pushes chevron to the far right edge
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: s.f(16),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),

              // Chevron — always pinned to the far right
              FaIcon(
                FontAwesomeIcons.chevronRight,
                color: const Color(0xFF4DD9C0),
                size: s.f(16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}