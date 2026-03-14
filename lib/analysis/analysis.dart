import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final BleService bleService = BleService();

  StreamSubscription<double>? _capSub;
  StreamSubscription<bool>? _stableSub;
  StreamSubscription<String>? _statusSub;

  double? _capacitancePf;
  bool _stableNow = false;
  bool _waiting = false;
  bool _sessionValid = false;
  String _statusText = "Preparing assessment...";
  int _stableSampleCount = 0;

  @override
  void initState() {
    super.initState();

    _capSub = bleService.capacitanceStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _capacitancePf = value;
      });
    });

    _stableSub = bleService.stableStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _stableNow = value;
      });
    });

    _statusSub = bleService.statusStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _statusText = value;
      });
    });

    _beginAssessment();
  }

  Future<void> _beginAssessment() async {
    if (!bleService.isConnected) {
      setState(() {
        _waiting = false;
        _statusText = "ESP32 not connected";
      });
      return;
    }

    setState(() {
      _capacitancePf = null;
      _stableNow = false;
      _waiting = true;
      _sessionValid = false;
      _stableSampleCount = 0;
      _statusText = "Ready. Press the device button to start measuring.";
    });

    try {
      final result = await bleService.startAssessment(
        timeout: const Duration(seconds: 20),
      );

      if (!mounted) return;
      setState(() {
        _waiting = false;
        _sessionValid = result.sessionValid;
        _stableSampleCount = result.stableSampleCount;
        _capacitancePf = result.finalPf;
        _statusText = result.sessionValid
            ? "Assessment complete"
            : "Assessment invalid / timeout";
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _waiting = false;
        _sessionValid = false;
        _statusText = "No sensor packets received in time";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _waiting = false;
        _sessionValid = false;
        _statusText = "Error: $e";
      });
    }
  }

  @override
  void dispose() {
    _capSub?.cancel();
    _stableSub?.cancel();
    _statusSub?.cancel();
    bleService.cancelAssessment("Analysis screen closed");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0XFF012532);
    const accent = Color(0XFF40E0D0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Capacitance Reading',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: accent,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _capacitancePf == null
                      ? '--'
                      : _capacitancePf!.toStringAsFixed(3),
                  style: const TextStyle(
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.bold,
                    fontSize: 88,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'pF',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 14,
                  color: _stableNow ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _stableNow
                      ? "Stable sample detected"
                      : "Waiting for stable sample",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _stableNow ? Colors.green : Colors.white70,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF868686),
                          size: 26,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap Start Assessment on the previous page, then press the device button. '
                            'This screen only prints capacitance values. No machine learning is used here yet.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF868686),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    _InfoTile(label: "Session status", value: _statusText),
                    const SizedBox(height: 12),
                    _InfoTile(
                      label: "Stable samples received",
                      value: "$_stableSampleCount",
                    ),
                    const SizedBox(height: 12),
                    _InfoTile(
                      label: "Result validity",
                      value: _waiting
                          ? "Waiting..."
                          : (_sessionValid ? "VALID" : "INVALID"),
                      valueColor: _waiting
                          ? Colors.orange
                          : (_sessionValid ? Colors.green : Colors.red),
                    ),

                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 64,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Save logic not added yet."),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0XFF40E0D0),
                              backgroundColor: const Color(0XFF012532),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              "Save Result",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 150,
                          height: 64,
                          child: TextButton(
                            onPressed: _waiting ? null : _beginAssessment,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0XFF012532),
                              backgroundColor: const Color(0XFF40E0D0),
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              _waiting ? "Waiting..." : "New Test",
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF5E6B70),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: valueColor ?? const Color(0xFF012532),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
