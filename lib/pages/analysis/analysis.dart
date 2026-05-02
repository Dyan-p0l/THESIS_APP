import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/ort_service.dart';
import '../../services/tflite_service.dart';
import 'save_reading/savedialog.dart';
import '../../db/dbhelper.dart';
import '../../models/readings.dart';
import '../settings/settings_display.dart';
import '../../services/mode_selection_service.dart';

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
  StreamSubscription<double>? _calibSub;
  StreamSubscription<double>? _ideDiffSub;

  double? _capacitancePf;
  bool _stableNow = false;
  bool _waiting = false;
  bool _sessionValid = false;
  String _statusText = "Preparing assessment...";
  int _stableSampleCount = 0;
  int? _currentReadingId;
  double? _calibrationPf;
  double? _ideDiffPf;

  // ML state
  String? _classificationResult;
  bool _inferring = false;

  // Active model
  ModelEntry? _activeModel;
  String _activeModelLabel = '';

  DisplaySettingsData _displaySettings = const DisplaySettingsData();

  // Failure reason for dialog
  String? _failureReason;

  static const _labelMap = {0: 'fresh', 1: 'moderate', 2: 'spoiled'};
  static const _labelColors = {
    'fresh': Color(0xFF56DFB1),
    'moderate': Color(0xFFFFAA00),
    'spoiled': Color(0xFFFF5252),
  };

  @override
  void initState() {
    super.initState();
    _calibrationPf = bleService.latestCalibrationPf;

    _capSub = bleService.capacitanceStream.listen((value) {
      if (!mounted) return;
      setState(() => _capacitancePf = value);
    });

    _stableSub = bleService.stableStream.listen((value) {
      if (!mounted) return;
      setState(() => _stableNow = value);
    });

    _statusSub = bleService.statusStream.listen((value) {
      if (!mounted) return;
      setState(() => _statusText = value);
    });

    _calibSub = bleService.calibrationStream.listen((value) {
      if (!mounted) return;
      setState(() => _calibrationPf = value);
    });

    _ideDiffSub = bleService.ideDiffStream.listen((value) {
      if (!mounted) return;
      setState(() => _ideDiffPf = value);
    });

    _initAndBegin();
  }

  Future<void> _initAndBegin() async {
    final displaySettings = await DisplaySettingsData.load();
    if (!mounted) return;
    setState(() => _displaySettings = displaySettings);

    final entry = await ModelSelectionService.loadSelectedEntry();
    if (!mounted) return;

    setState(() {
      _activeModel = entry;
      final runtimeLabel = entry.runtime == ModelRuntime.tflite
          ? 'TFLite'
          : 'ONNX';
      _activeModelLabel = '${entry.name} ($runtimeLabel)';
    });

    if (entry.runtime == ModelRuntime.tflite) {
      await TFLiteService.init(assetPath: entry.assetPath);
    } else {
      await OrtService.init(assetPath: entry.assetPath);
    }

    await _beginAssessment();
  }

  // Infer a human-readable failure reason from what the BleService gives us,
  // without requiring any firmware changes.
  String _inferFailureReason(AssessmentResult result) {
    if (result.stableSampleCount == 0) {
      return 'No stable contact was detected.\n\n'
          'The sensor did not receive a stable signal within the allowed time. '
          'Ensure the IDE electrodes are firmly and flatly pressed against the '
          'fish surface and try again.';
    }
    return 'Insufficient stable contact time.\n\n'
        'The sensor detected ${result.stableSampleCount} stable sample(s) but '
        'could not accumulate enough to complete the session. This may indicate '
        'the sensor was lifted mid-measurement or the signal became unstable. '
        'Hold the sensor steady and try again.';
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
      _classificationResult = null;
      _inferring = false;
      _failureReason = null;
    });

    await bleService.sendClassification(BleService.cmdClear);

    try {
      final result = await bleService.startAssessment(
        timeout: const Duration(seconds: 20),
      );

      if (!mounted) return;

      final String? failureReason = result.sessionValid
          ? null
          : _inferFailureReason(result);

      setState(() {
        _waiting = false;
        _sessionValid = result.sessionValid;
        _stableSampleCount = result.stableSampleCount;
        _capacitancePf = result.finalPf;
        _failureReason = failureReason;
        _statusText = result.sessionValid
            ? "Assessment complete"
            : "Assessment invalid / timeout";
      });

      if (!result.sessionValid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showFailureDialog();
        });
        return;
      }

      // Valid session — run ML classification
      setState(() => _inferring = true);

      final int labelIndex;
      final entry = _activeModel;
      if (entry != null && entry.runtime == ModelRuntime.tflite) {
        labelIndex = await TFLiteService.classify(result.finalPf!);
      } else {
        labelIndex = await OrtService.classify(result.finalPf!);
      }

      final category = _labelMap[labelIndex] ?? 'fresh';

      if (!mounted) return;
      setState(() {
        _classificationResult = category;
        _inferring = false;
      });

      await bleService.sendClassification(labelIndex);

      _currentReadingId = await DBhelper.instance.insertReading(
        Reading(
          value: result.finalPf!,
          carriedOutAt: DateTime.now().toIso8601String(),
          isSaved: false,
          category: category,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _waiting = false;
        _sessionValid = false;
        _failureReason =
            'Connection timed out.\n\nNo packets were received from the sensor '
            'within the allowed time. Ensure the device is powered on and '
            'within range, then try again.';
        _statusText = "No sensor packets received in time";
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showFailureDialog();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _waiting = false;
        _sessionValid = false;
        _failureReason = null;
        _statusText = "Error: $e";
      });
    }
  }

  void _showFailureDialog() {
    final reason = _failureReason;
    if (reason == null || !mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.sensors_off_rounded,
                color: Color(0xFFFF5252),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Assessment Failed',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.045,
                  color: const Color(0xFF012532),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          reason,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Color(0xFF5E6B70),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF5E6B70),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Dismiss',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _beginAssessment();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF012532),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _capSub?.cancel();
    _stableSub?.cancel();
    _statusSub?.cancel();
    _calibSub?.cancel();
    bleService.cancelAssessment("Analysis screen closed");
    _ideDiffSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0XFF012532);
    const accent = Color(0XFF40E0D0);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final classColor = _classificationResult != null
        ? _labelColors[_classificationResult!]!
        : const Color(0xFF012532);

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
            if (_displaySettings.showCalibrationBaseline ||
                _displaySettings.showCapacitanceDifference)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.006,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_displaySettings.showCalibrationBaseline)
                      Expanded(
                        child: Text(
                          _calibrationPf == null
                              ? 'Baseline: --'
                              : 'Baseline: ${_calibrationPf!.toStringAsFixed(3)} pF',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: screenWidth * 0.032,
                            color: Colors.white38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_displaySettings.showCalibrationBaseline &&
                        _displaySettings.showCapacitanceDifference)
                      SizedBox(width: screenWidth * 0.03),
                    if (_displaySettings.showCapacitanceDifference)
                      Expanded(
                        child: Text(
                          _ideDiffPf == null
                              ? 'IDE diff/ch: --'
                              : 'IDE diff/ch: ${_ideDiffPf!.toStringAsFixed(3)} pF',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: screenWidth * 0.032,
                            color: Colors.white38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            if (_displaySettings.showStabilityIndicator)
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
                    SizedBox(height: screenHeight * 0.015),
                    _InfoTile(
                      label: "ML Classification",
                      value: _inferring
                          ? "Classifying..."
                          : (_classificationResult?.toUpperCase() ?? "--"),
                      valueColor: _inferring ? Colors.orange : classColor,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    _InfoTile(
                      label: "Active Model",
                      value: _activeModelLabel.isEmpty
                          ? '--'
                          : _activeModelLabel,
                      valueColor: const Color(0xFF42A5F5),
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
                              if (!_sessionValid ||
                                  _capacitancePf == null ||
                                  _currentReadingId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No valid reading to save'),
                                  ),
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
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.05,
                                ),
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
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.05,
                                ),
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
