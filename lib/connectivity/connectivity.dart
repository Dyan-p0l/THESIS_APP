import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/ble_service.dart';

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
    if (rssiDbm >= -60) return Colors.green;
    if (rssiDbm >= -70) return Colors.lightGreen;
    if (rssiDbm >= -85) return Colors.orange;
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
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
                      const SizedBox(height: 10),
                      const Text(
                        "Connectivity Status",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textCyan,
                        ),
                      ),
                      const SizedBox(height: 28),

                      _ConnectionRow(connected: connected, accent: accent),

                      const SizedBox(height: 34),

                      _SignalGauge(
                        progress: progress,
                        rssiDbm: rssiDbm,
                        label: label,
                        ringColor: signalColor,
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: connected
                              ? () {
                                  Navigator.pushNamed(context, '/analysis');
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: const Color(0XFF012532),
                            disabledBackgroundColor: Colors.grey.shade700,
                            disabledForegroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "START\nASSESSMENT",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: "Inter",
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      TextButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/history');
                        },
                        icon: const Icon(Icons.history, color: Colors.white),
                        label: const Text(
                          "VIEW HISTORY",
                          style: TextStyle(
                            fontFamily: "Inter",
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: connected ? accent : Colors.redAccent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            connected ? Icons.check : Icons.close,
            color: const Color(0xFF021E28),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          connected ? "ESP32 Connected" : "ESP32 Disconnected",
          style: const TextStyle(
            fontFamily: "Inter",
            fontSize: 14,
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
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(240, 240),
            painter: _RingPainter(
              progress: progress,
              ringColor: ringColor,
              baseColor: Colors.white.withOpacity(0.20),
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
                    style: const TextStyle(
                      fontFamily: "Inter",
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      "dBm",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 18,
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
    final radius = math.min(size.width, size.height) / 2 - 14;

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
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
