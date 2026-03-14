import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final BleService bleService = BleService();

  bool _waitingFinal = false;
  String _hintText = "Tap Start Assessment to measure.";

  @override
  void initState() {
    super.initState();
    bleService.startAutoConnect();
  }

  Future<void> _startAssessment(bool connected) async {
    if (!connected) return;

    setState(() {
      _waitingFinal = true;
      _hintText = "Measuring... keep sensor steady for stable contact.";
    });

    try {
      // ✅ Sends START (0x01) to ESP32 then waits for FINAL (flags bit5)
      final result = await bleService.startAssessment(
        timeout: const Duration(seconds: 25),
      );

      if (!mounted) return;

      setState(() {
        _waitingFinal = false;
        _hintText = result.stable
            ? "Assessment complete."
            : "Assessment failed (unstable/timeout). Reposition and try again.";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.stable
                ? "FINAL OK: ${result.finalPf.toStringAsFixed(2)} pF"
                : "FINAL FAILED: Unstable/timeout (retry).",
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _waitingFinal = false;
        _hintText = "Timeout. Tap Start Assessment to try again.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Timeout: No FINAL packet received.")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _waitingFinal = false;
        _hintText = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF021E28);
    const tealBtn = Colors.teal;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Connectivity Status'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: StreamBuilder<bool>(
            stream: bleService.connectionStream,
            builder: (context, connSnap) {
              final connected = connSnap.data ?? false;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // CONNECTION STATUS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        color: connected ? Colors.green : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        connected ? "Connected" : "Disconnected",
                        style: TextStyle(
                          color: connected ? Colors.green : Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // STABILITY FLAG (only meaningful during assessment)
                  StreamBuilder<bool>(
                    stream: bleService.stableStream,
                    builder: (context, stableSnap) {
                      final stable = stableSnap.data ?? false;

                      // When not measuring, keep it neutral
                      final showStable = _waitingFinal;
                      final iconColor = showStable
                          ? (stable ? Colors.green : Colors.grey)
                          : Colors.grey;

                      final label = showStable
                          ? (stable ? "Stable Contact" : "Not Stable")
                          : "Tap Start Assessment to measure";

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: iconColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(color: iconColor, fontSize: 14),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 50),

                  // CAPACITANCE DISPLAY
                  StreamBuilder<double>(
                    stream: bleService.capacitanceStream,
                    builder: (context, snapshot) {
                      final text = snapshot.hasData
                          ? "${snapshot.data!.toStringAsFixed(2)} pF"
                          : "-- pF";

                      return Text(
                        text,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Tap Start Assessment to measure",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // START / LOADING BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!connected || _waitingFinal)
                          ? null
                          : () => _startAssessment(connected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealBtn, // ✅ teal background
                        disabledBackgroundColor: tealBtn.withOpacity(0.35),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _waitingFinal
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Start Assessment",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    _hintText,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "Device LEDs:\nRed = Power ON, Green = Stable Contact",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
