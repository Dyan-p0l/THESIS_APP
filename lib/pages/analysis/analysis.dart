import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import 'save_reading/savedialog.dart';
import '../../db/dbhelper.dart';
import '../../models/readings.dart';
import 'dart:math';

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

  String _randomCategory() {
    final categories = ['fresh', 'moderate', 'spoiled'];
    final random = Random();
    return categories[random.nextInt(categories.length)];
  }

  double? _capacitancePf;
  bool _stableNow = false;
  bool _waiting = false;
  bool _sessionValid = false;
  String _statusText = "Preparing assessment...";
  int _stableSampleCount = 0;
  int? _currentReadingId;

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
      _currentReadingId = null;
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


      if (result.sessionValid && result.finalPf != null) {
        _currentReadingId = await DBhelper.instance.insertReading(
          Reading(
            value: result.finalPf!,
            carriedOutAt: DateTime.now().toIso8601String(),
            isSaved: false,
            category: _randomCategory(),
          ),
        );
      }

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

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: screenHeight * 0.015),
            Text(
              'Capacitance Reading',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.07,
                color: accent,
              ),
            ),
            SizedBox(height: screenHeight * 0.012),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _capacitancePf == null
                      ? '--'
                      : _capacitancePf!.toStringAsFixed(3),
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.22,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Padding(
                  padding: EdgeInsets.only(bottom: screenHeight * 0.018),
                  child: Text(
                    'pF',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.075,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.015),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: screenWidth * 0.035,
                  color: _stableNow ? Colors.green : Colors.grey,
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  _stableNow
                      ? "Stable sample detected"
                      : "Waiting for stable sample",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: screenWidth * 0.035,
                    color: _stableNow ? Colors.green : Colors.white70,
                  ),
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.022),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.05,
                  screenHeight * 0.035,
                  screenWidth * 0.05,
                  screenHeight * 0.03,
                ),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF868686),
                          size: screenWidth * 0.065,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          'Please ensure proper\ncontact with fish surface.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: screenWidth * 0.038,
                            color: const Color(0xFF868686),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.035),

                    _InfoTile(label: "Session status", value: _statusText),
                    SizedBox(height: screenHeight * 0.015),
                    _InfoTile(
                      label: "Stable samples received",
                      value: "$_stableSampleCount",
                    ),
                    SizedBox(height: screenHeight * 0.015),
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
                          width: screenWidth * 0.38,
                          height: screenHeight * 0.08,
                          child: TextButton(
                            onPressed: () {
                              if (!_sessionValid || _capacitancePf == null || _currentReadingId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No valid reading to save')),
                                );
                                return;
                              }

                              showSaveDialog(
                                context,
                                readingId: _currentReadingId!,
                                value: _capacitancePf!,
                                carriedOutAt: DateTime.now().toIso8601String(),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0XFF40E0D0),
                              backgroundColor: const Color(0XFF012532),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(screenWidth * 0.05),
                              ),
                            ),
                            child: Text(
                              "Save Result",
                              style: TextStyle(fontSize: screenWidth * 0.045),
                            ),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.06),
                        SizedBox(
                          width: screenWidth * 0.38,
                          height: screenHeight * 0.08,
                          child: TextButton(
                            onPressed: _waiting ? null : _beginAssessment,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0XFF012532),
                              backgroundColor: const Color(0XFF40E0D0),
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(screenWidth * 0.05),
                              ),
                            ),
                            child: Text(
                              _waiting ? "Waiting..." : "New Test",
                              style: TextStyle(fontSize: screenWidth * 0.045),
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
