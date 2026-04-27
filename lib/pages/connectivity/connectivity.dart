import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../connectivity/bluetooth_scan.dart';

class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({super.key});

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  final BleService bleService = BleService();

  @override
  void initState() {
    super.initState();
    bleService.startAutoConnect();
  }

  String _signalLabel(int rssiDbm) {
    if (rssiDbm >= -60) return "EXCELLENT";
    if (rssiDbm >= -70) return "GOOD";
    if (rssiDbm >= -85) return "FAIR";
    return "POOR";
  }

  Color _signalColor(int rssiDbm) {
    if (rssiDbm >= -60) return Color(0xFF56DFB1);
    if (rssiDbm >= -70) return Color.fromARGB(255, 26, 227, 140);
    if (rssiDbm >= -85) return const Color.fromARGB(255, 255, 170, 0);
    return Colors.red;
  }

  double _ringProgress(int rssiDbm) {
    const int minDbm = -100;
    const int maxDbm = -40;
    final clamped = rssiDbm.clamp(minDbm, maxDbm);
    return (clamped - minDbm) / (maxDbm - minDbm);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF021E28);
    const accent = Color(0xFF56DFB1);
    const textCyan = Color(0xFF44E6E0);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.055,
            vertical: screenHeight * 0.022,
          ),
          child: StreamBuilder<bool>(
            stream: bleService.connectionStream,
            initialData: bleService.isConnected,
            builder: (context, connSnap) {
              final connected = connSnap.data ?? false;

              return StreamBuilder<int>(
                stream: bleService.rssiStream,
                initialData: -100,
                builder: (context, rssiSnap) {
                  final rssiDbm = rssiSnap.data ?? -100;
                  final label = _signalLabel(rssiDbm);
                  final signalColor = _signalColor(rssiDbm);
                  final progress = _ringProgress(rssiDbm);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Top bar: Bluetooth (left) + Settings (right) ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bluetooth button
                          Container(
                            width: screenWidth * 0.11,
                            height: screenWidth * 0.11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                // TODO: open Bluetooth settings / scan dialog
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BluetoothScanScreen(),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.bluetooth,
                                color: Colors.white,
                                size: screenWidth * 0.055,
                              ),
                            ),
                          ),

                          // Settings button
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/settings');
                            },
                            icon: Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: screenWidth * 0.065,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.018),

                      Text(
                        "Connectivity Status",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.w700,
                          color: textCyan,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.035),

                      _ConnectionRow(connected: connected, accent: accent),

                      SizedBox(height: screenHeight * 0.12),

                      _SignalGauge(
                        progress: progress,
                        rssiDbm: rssiDbm,
                        label: label,
                        ringColor: signalColor,
                      ),

                      const Spacer(),

                      SizedBox(
                        width: screenWidth * 0.70,
                        child: ElevatedButton(
                          onPressed: connected
                              ? () {
                                  Navigator.pushNamed(context, '/analysis');
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF56DFB1),
                            foregroundColor: const Color(0XFF012532),
                            disabledBackgroundColor: Colors.grey.shade700,
                            disabledForegroundColor: Colors.white70,
                            padding: EdgeInsets.symmetric(
                              vertical: screenHeight * 0.02,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.04,
                              ),
                            ),
                          ),
                          child: Text(
                            "START ASSESSMENT",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: "Inter",
                              fontSize: screenWidth * 0.043,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.018),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/history');
                            },
                            icon: Icon(
                              Icons.history,
                              color: Colors.white,
                              size: screenWidth * 0.055,
                            ),
                            label: Text(
                              "VIEW HISTORY",
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: screenWidth * 0.036,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          SizedBox(width: screenWidth * 0.06),

                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/saved_samples');
                            },
                            icon: Icon(
                              Icons.folder_open_rounded,
                              color: Colors.white,
                              size: screenWidth * 0.055,
                            ),
                            label: Text(
                              "VIEW SAMPLES",
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: screenWidth * 0.036,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.012),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  final bool connected;
  final Color accent;

  const _ConnectionRow({required this.connected, required this.accent});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth * 0.07;
    final fontSize = screenWidth * 0.036;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: connected ? accent : Colors.redAccent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            connected ? Icons.check : Icons.close,
            color: const Color(0xFF021E28),
            size: iconSize * 0.62,
          ),
        ),
        SizedBox(width: screenWidth * 0.025),
        Text(
          connected ? "ESP32 Connected" : "ESP32 Disconnected",
          style: TextStyle(
            fontFamily: "Inter",
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SignalGauge extends StatelessWidget {
  final double progress;
  final int rssiDbm;
  final String label;
  final Color ringColor;

  const _SignalGauge({
    required this.progress,
    required this.rssiDbm,
    required this.label,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width > 0
        ? MediaQuery.of(context).size.width
        : 360.0;

    final gaugeSize = screenWidth * 0.78;
    final dbmFontSize = gaugeSize * 0.168;
    final unitFontSize = gaugeSize * 0.052;
    final labelFontSize = gaugeSize * 0.058;
    final unitBottomPad = gaugeSize * 0.032;

    return SizedBox(
      width: gaugeSize,
      height: gaugeSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(gaugeSize, gaugeSize),
            painter: _RingPainter(
              progress: progress,
              ringColor: ringColor,
              baseColor: Colors.white.withValues(alpha: 0.20),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$rssiDbm",
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: dbmFontSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: gaugeSize * 0.019),
                  Padding(
                    padding: EdgeInsets.only(bottom: unitBottomPad),
                    child: Text(
                      "dBm",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: unitFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: gaugeSize * 0.026),
              Text(
                label,
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w800,
                  color: ringColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color baseColor;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.061;
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2 - 4;

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);

    final startAngle = -math.pi / 2 + 0.35;
    final sweepAngle = (2 * math.pi - 0.7) * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.baseColor != baseColor;
  }
}
