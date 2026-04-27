import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
// TO UNCOMMENT WHEN DEPLOYING WITH REAL BLE:
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ─────────────────────────────────────────────
// TO DELETE WHEN BLE IS IMPLEMENTED ↓
// ─────────────────────────────────────────────
const bool kUseMockDevices = true;

class _MockDevice {
  final String name;
  final String subtitle;
  final int rssi;
  final bool isEsp32;

  const _MockDevice({
    required this.name,
    required this.subtitle,
    required this.rssi,
    required this.isEsp32,
  });
}

const List<_MockDevice> _mockDevices = [
  _MockDevice(
    name: 'PRESSKO-ESP32',
    subtitle: 'Ready to pair',
    rssi: -52,
    isEsp32: true,
  ),
  _MockDevice(name: 'TWS', subtitle: 'Audio Device', rssi: -68, isEsp32: false),
  _MockDevice(
    name: 'iPhone 15 Pro',
    subtitle: 'Mobile Phone',
    rssi: -78,
    isEsp32: false,
  ),
  _MockDevice(
    name: 'Unknown Device',
    subtitle: 'FC:B4:67:2A:91:DE',
    rssi: -92,
    isEsp32: false,
  ),
];
// ─────────────────────────────────────────────
// TO DELETE WHEN BLE IS IMPLEMENTED ↑
// ─────────────────────────────────────────────

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  // TO DELETE WHEN BLE IS IMPLEMENTED → final List<_MockDevice> _devices = [];
  // REPLACE WITH               → final List<ScanResult> _devices = [];
  final List<_MockDevice> _devices = [];

  bool _isScanning = false;
  Timer? _mockTimer; // TO DELETE WHEN BLE IS IMPLEMENTED

  // Tracks which card index is currently pressed for highlight effect
  int? _pressedIndex;

  static const bg = Color(0xFF021E28);
  static const accent = Color(0xFF56DFB1);
  static const textCyan = Color(0xFF44E6E0);
  static const cardBg = Color(0xFF042535);
  static const cardBorder = Color(0xFF0E3A4A);

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startScan();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _mockTimer?.cancel(); // TO DELETE WHEN BLE IS IMPLEMENTED
    // FlutterBluePlus.stopScan(); // TO UNCOMMENT WHEN BLE IS IMPLEMENTED
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    // ── TO DELETE entire if block when BLE is implemented ──────────
    if (kUseMockDevices) {
      int index = 0;
      _mockTimer?.cancel();
      _mockTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (index < _mockDevices.length) {
          setState(() => _devices.add(_mockDevices[index++]));
        } else {
          t.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _isScanning = false);
              _spinController.stop();
            }
          });
        }
      });
    } else {
      // ── TO UNCOMMENT when BLE is implemented ──────────────────────
      // FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      // FlutterBluePlus.scanResults.listen((results) {
      //   if (mounted) setState(() {
      //     _devices..clear()..addAll(results);
      //   });
      // });
      // FlutterBluePlus.isScanning.listen((s) {
      //   if (mounted) {
      //     setState(() => _isScanning = s);
      //     if (!s) _spinController.stop();
      //   }
      // });
    }
  }

  // ── Helpers — NO changes needed for real BLE ──────────────────────

  // TO UPDATE for real BLE: change parameter type from _MockDevice → ScanResult
  // and read: name     → r.device.platformName (fallback 'Unknown Device')
  //           subtitle → r.device.remoteId.str
  //           rssi     → r.rssi
  //           isEsp32  → r.device.platformName.toLowerCase().contains('esp')
  String _deviceName(_MockDevice d) =>
      d.name.isNotEmpty ? d.name : 'Unknown Device';

  String _deviceSubtitle(_MockDevice d) => d.subtitle;

  bool _isEsp(_MockDevice d) => d.isEsp32;

  String _signalLabel(int rssi) {
    if (rssi >= -60) return "Strong";
    if (rssi >= -70) return "Good";
    if (rssi >= -85) return "Fair";
    return "Weak";
  }

  Color _signalColor(int rssi) {
    if (rssi >= -60) return accent;
    if (rssi >= -70) return accent;
    if (rssi >= -85) return const Color(0xFFFFAA00);
    return Colors.redAccent;
  }

  Widget _signalBars(int rssi, {required double size}) {
    final color = _signalColor(rssi);
    final int filled = rssi >= -60
        ? 3
        : rssi >= -70
        ? 2
        : rssi >= -85
        ? 1
        : 0;

    return SizedBox(
      width: size,
      height: size * 0.75,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (i) {
          final barHeight = (size * 0.3) + (i * size * 0.2);
          return Container(
            width: size * 0.22,
            height: barHeight,
            decoration: BoxDecoration(
              color: i < filled ? color : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // Builds a device card — structure is identical for mock and real BLE.
  // Only the data source changes (see helpers above).
  Widget _buildDeviceCard(_MockDevice d, int index, double sw, double sh) {
    final isEsp = _isEsp(d);
    final name = _deviceName(d);
    final subtitle = _deviceSubtitle(d);
    final label = _signalLabel(d.rssi);
    final sigColor = _signalColor(d.rssi);
    final isPressed = _pressedIndex == index;

    // Highlight: ESP32 always teal border; other devices get teal on press
    final borderColor = (isPressed) ? accent : cardBorder;
    final borderWidth = (isPressed) ? 1.5 : 1.0;
    final bgColor = isPressed ? accent.withValues(alpha: 0.08) : cardBg;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedIndex = index),
      onTapUp: (_) => setState(() => _pressedIndex = null),
      onTapCancel: () => setState(() => _pressedIndex = null),
      onTap: () {
        if (isEsp) {
          // TO DELETE mock snackbar and REPLACE with real connect when BLE is implemented:
          // await d.device.connect(autoConnect: false, timeout: Duration(seconds: 10));
          // if (context.mounted) Navigator.pop(context, d.device);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("[Mock] Connecting to $name..."),
              backgroundColor: accent,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
          horizontal: sw * 0.045,
          vertical: sh * 0.018,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(sw * 0.035),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          children: [
            // ── Name + subtitle ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: sw * 0.042,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isEsp ? "Ready to pair" : subtitle,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: sw * 0.033,
                      fontWeight: FontWeight.w500,
                      color: isEsp ? accent : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),

            // ── Signal bars + label ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _signalBars(d.rssi, size: sw * 0.058),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: sw * 0.028,
                    fontWeight: FontWeight.w600,
                    color: sigColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    // TO UPDATE for real BLE: change _MockDevice → ScanResult in sort
    final sorted = [..._devices]
      ..sort((a, b) {
        if (_isEsp(a) && !_isEsp(b)) return -1;
        if (!_isEsp(a) && _isEsp(b)) return 1;
        return b.rssi.compareTo(a.rssi);
      });

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sw * 0.055,
            vertical: sh * 0.022,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back ──
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                label: const Text(
                  "Back",
                  style: TextStyle(
                    fontFamily: "Inter",
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              SizedBox(height: sh * 0.025),

              // ── Title ──
              Center(
                child: Text(
                  "Bluetooth Devices",
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: sw * 0.065,
                    fontWeight: FontWeight.w700,
                    color: textCyan,
                  ),
                ),
              ),

              SizedBox(height: sh * 0.008),

              // ── Subtitle ──
              Center(
                child: Text(
                  _isScanning
                      ? "Scanning for nearby devices..."
                      : "Scan complete",
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: sw * 0.035,
                    color: Colors.white54,
                  ),
                ),
              ),

              SizedBox(height: sh * 0.03),

              // ── Dual arcs + bluetooth icon ──
              Center(
                child: SizedBox(
                  width: sw * 0.32,
                  height: sw * 0.32,
                  child: AnimatedBuilder(
                    animation: _spinController,
                    builder: (_, __) => Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(sw * 0.32, sw * 0.32),
                          painter: _DualArcPainter(
                            progress: _spinController.value,
                            outerColor: textCyan,
                            isScanning: _isScanning,
                          ),
                        ),
                        Icon(Icons.bluetooth, color: textCyan, size: sw * 0.09),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: sh * 0.035),

              // ── Section label ──
              Text(
                "AVAILABLE DEVICES",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: sw * 0.030,
                  fontWeight: FontWeight.w700,
                  color: textCyan,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: sh * 0.014),

              // ── Device list ──
              Expanded(
                child: sorted.isEmpty
                    ? Center(
                        child: Text(
                          _isScanning
                              ? "Looking for devices..."
                              : "No devices found",
                          style: const TextStyle(
                            fontFamily: "Inter",
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: sh * 0.012),
                        itemBuilder: (context, i) =>
                            _buildDeviceCard(sorted[i], i, sw, sh),
                      ),
              ),

              SizedBox(height: sh * 0.016),

              // ── Scan Again ──
              if (!_isScanning)
                Center(
                  child: SizedBox(
                    width: sw * 0.55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _spinController.repeat();
                        _startScan();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        "SCAN AGAIN",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: const Color(0xFF012532),
                        padding: EdgeInsets.symmetric(vertical: sh * 0.018),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(sw * 0.04),
                        ),
                      ),
                    ),
                  ),
                ),

              SizedBox(height: sh * 0.01),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dual arc painter — NO changes needed for real BLE ─────────────
class _DualArcPainter extends CustomPainter {
  final double progress;
  final Color outerColor;
  final bool isScanning;

  const _DualArcPainter({
    required this.progress,
    required this.outerColor,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isScanning) return;

    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 3.5;
    const gap = 10.0;
    final outerRadius = math.min(size.width, size.height) / 2 - 2;
    final innerRadius = outerRadius - gap - strokeWidth;

    // Outer arc — teal, clockwise
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      progress * 2 * math.pi - math.pi / 2,
      math.pi * 1.1,
      false,
      Paint()
        ..color = outerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Inner arc — gray, counter-clockwise
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      -(progress * 2 * math.pi) - math.pi / 2,
      math.pi * 0.85,
      false,
      Paint()
        ..color = Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DualArcPainter old) =>
      old.progress != progress || old.isScanning != isScanning;
}
