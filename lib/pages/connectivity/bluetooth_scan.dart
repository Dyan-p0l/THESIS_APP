import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thesis_app/services/ble_service.dart';

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  final List<ScanResult> _devices = [];
  bool _isScanning = false;
  int? _pressedIndex;
  bool _isConnecting = false;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanSub;

  static const bg = Color(0xFF021E28);
  static const accent = Color(0xFF56DFB1);
  static const textCyan = Color(0xFF44E6E0);
  static const cardBg = Color(0xFF042535);
  static const cardBorder = Color(0xFF0E3A4A);

  @override
  void initState() {
    super.initState();

    // Temporarily stop auto connect behavior
    BleService().disconnect();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _requestPermissionsAndScan();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _scanSub?.cancel();
    _isScanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _requestPermissionsAndScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first;
    }

    _startScan();
  }

  Future<void> _startScan() async {
    if (_isConnecting) return;

    _scanSub?.cancel();
    _isScanSub?.cancel();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    if (!_spinController.isAnimating) _spinController.repeat();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _devices
          ..clear()
          ..addAll(results);
      });
    });

    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      setState(() => _isScanning = scanning);
      if (!scanning) _spinController.stop();
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String _deviceName(ScanResult r) {
    final name = r.advertisementData.advName.isNotEmpty
        ? r.advertisementData.advName
        : r.device.platformName;
    return name.isNotEmpty ? name : 'Unknown Device';
  }

  String _deviceSubtitle(ScanResult r) => r.device.remoteId.str;

  bool _isTarget(ScanResult r) => BleService.isOurDevice(r);

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

  Future<void> _connectToDevice(ScanResult r) async {
    if (_isConnecting) return;

    final isPressko = BleService.isOurDevice(r);

    if (!isPressko) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This device is not a PRESSKO device"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      await BleService().connectToDevice(r.device);

      if (!mounted) return;
      Navigator.pop(context); // go back to connectivity screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection failed: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Widget _buildDeviceCard(ScanResult r, int index, double sw, double sh) {
    final isTarget = _isTarget(r);
    final name = _deviceName(r);
    final subtitle = _deviceSubtitle(r);
    final label = _signalLabel(r.rssi);
    final sigColor = _signalColor(r.rssi);
    final isPressed = _pressedIndex == index;

    final borderColor = isPressed ? accent : cardBorder;
    final borderWidth = isPressed ? 1.5 : 1.0;
    final bgColor = isPressed ? accent.withValues(alpha: 0.08) : cardBg;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedIndex = index),
      onTapUp: (_) => setState(() => _pressedIndex = null),
      onTapCancel: () => setState(() => _pressedIndex = null),
      onTap: isTarget && !_isConnecting ? () => _connectToDevice(r) : null,
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
                  Row(
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
                      // Chip shown only for the target device
                      if (isTarget) ...[
                        SizedBox(width: sw * 0.02),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: sw * 0.02,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accent, width: 0.8),
                          ),
                          child: Text(
                            "SENSOR",
                            style: TextStyle(
                              fontFamily: "Inter",
                              fontSize: sw * 0.025,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isTarget ? "Tap to connect" : subtitle,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: sw * 0.033,
                      fontWeight: FontWeight.w500,
                      color: isTarget ? accent : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),

            // ── Connecting spinner OR signal bars ──
            if (_isConnecting && isTarget)
              SizedBox(
                width: sw * 0.058,
                height: sw * 0.058,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _signalBars(r.rssi, size: sw * 0.058),
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

    // Target device always floats to top, then sort remaining by RSSI
    final sorted = [..._devices]
      ..sort((a, b) {
        if (_isTarget(a) && !_isTarget(b)) return -1;
        if (!_isTarget(a) && _isTarget(b)) return 1;
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
                  _isConnecting
                      ? "Connecting to device..."
                      : _isScanning
                      ? "Scanning for nearby devices..."
                      : "${_devices.length} device${_devices.length == 1 ? '' : 's'} found",
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
                            isScanning: _isScanning || _isConnecting,
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
              if (!_isScanning && !_isConnecting)
                Center(
                  child: SizedBox(
                    width: sw * 0.55,
                    child: ElevatedButton.icon(
                      onPressed: _startScan,
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

// ── Dual arc painter — unchanged ──────────────────────────────────
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
