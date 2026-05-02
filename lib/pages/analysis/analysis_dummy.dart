import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/ort_service.dart';
import '../../services/tflite_service.dart';
import 'save_reading/savedialog.dart';
import '../../db/dbhelper.dart';
import '../../models/readings.dart';
import '../../services/mode_selection_service.dart';
import 'anim/rotatingcheck.dart';
import 'anim/freshnessmeter.dart';
import '../settings/settings_display.dart';
import 'anim/result.dart';

class AnalysisScreenDummy extends StatefulWidget {
  const AnalysisScreenDummy({super.key});

  @override
  State<AnalysisScreenDummy> createState() => _AnalysisScreenDummyState();
}

class _AnalysisScreenDummyState extends State<AnalysisScreenDummy>
    with TickerProviderStateMixin {
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

  bool _phase1Played = false;

  String? _classificationResult;
  bool _inferring = false;

  DisplaySettingsData _displaySettings = const DisplaySettingsData();

  ModelEntry? _activeModel;
  String _activeModelLabel = '';

  String? _pendingResult;

  bool _assessmentAborted = false;

  // Explicit done-state bools so AnimatedCheck.didUpdateWidget fires correctly
  bool _step1Done = false;
  bool _step2Done = false;

  // Failure reason for dialog
  String? _failureReason;

  // Animation controllers
  late AnimationController _ctrl1;
  late AnimationController _ctrl2;
  late AnimationController _ctrl3;
  late AnimationController _spinCtrl;
  late AnimationController _spinCtrl2;

  late Animation<double> _fade1;
  late Animation<double> _fade2;
  late Animation<double> _fade3;

  late Animation<Offset> _slide1;
  late Animation<Offset> _slide2;
  late Animation<Offset> _slide3;

  static const _labelMap = {0: 'fresh', 1: 'moderate', 2: 'spoiled'};
  static const _labelColors = {
    'fresh': Color(0xFF56DFB1),
    'moderate': Color(0xFFFFAA00),
    'spoiled': Color(0xFFFF5252),
  };
  static const _levelMap = {'fresh': 0, 'moderate': 1, 'spoiled': 2};

  @override
  void initState() {
    super.initState();
    _calibrationPf = bleService.latestCalibrationPf;

    _ctrl1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _ctrl2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ctrl3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _spinCtrl2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade1 = Tween(begin: 0.0, end: 1.0).animate(_ctrl1);
    _fade2 = Tween(begin: 0.0, end: 1.0).animate(_ctrl2);
    _fade3 = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl3, curve: Curves.easeOut));

    _slide1 = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_ctrl1);
    _slide2 = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_ctrl2);
    _slide3 = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_ctrl3);

    // BLE streams
    _capSub = bleService.capacitanceStream.listen((value) {
      if (!mounted) return;
      setState(() => _capacitancePf = value);
    });
    _stableSub = bleService.stableStream.listen((value) {
      if (!mounted) return;
      setState(() => _stableNow = value);

      if (_assessmentAborted) return;

      if (value && !_phase1Played && _classificationResult == null) {
        _phase1Played = true;
        _ctrl1.forward();
        _spinCtrl.repeat();
      }
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

  String _inferFailureReason(AssessmentResult result) {
    if (result.stableSampleCount == 0) {
      return 'No stable contact detected.\n\n'
          'Ensure the IDE sensor is firmly and flatly pressed on the fish surface, then try again.';
    }
    return 'Insufficient stable contact time.\n\n'
        'Only ${result.stableSampleCount} stable sample(s) were recorded. '
        'Keep the sensor steady throughout the measurement and try again.';
  }

  void _resetAnimationControllers() {
    _ctrl1.stop();
    _ctrl2.stop();
    _ctrl3.stop();
    _spinCtrl.stop();
    _spinCtrl2.stop();
    _ctrl1.reset();
    _ctrl2.reset();
    _ctrl3.reset();
    _spinCtrl.reset();
    _spinCtrl2.reset();
  }

  Future<void> _beginAssessment() async {
    _resetAnimationControllers();

    _phase1Played = false;
    _assessmentAborted = false;

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
      _step1Done = false;
      _step2Done = false;
      _failureReason = null;
      _pendingResult = null;
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
        // Stop any spinning animation that may have started during contact
        _spinCtrl.stop();
        _spinCtrl2.stop();
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
        _pendingResult = category;
        _inferring = false;
      });

      // Pause before Step 2 so Step 1 feels settled
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      _spinCtrl2.repeat();

      // Step 2 slides in — Step 1 (_spinCtrl) still spinning throughout
      await _ctrl2.forward();

      // Step 1 check mark
      _spinCtrl.stop();
      if (mounted) setState(() => _step1Done = true);

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      _spinCtrl2.stop();
      // Step 2 check mark
      if (mounted) setState(() => _step2Done = true);

      setState(() {
        _classificationResult = _pendingResult;
      });

      _playResultAnimation();

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
      _resetAnimationControllers();
      setState(() {
        _waiting = false;
        _sessionValid = false;
        _phase1Played = false;
        _step1Done = false;
        _step2Done = false;
        _classificationResult = null;
        _pendingResult = null;
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
      _assessmentAborted = true;
      _resetAnimationControllers();
      setState(() {
        _waiting = false;
        _sessionValid = false;
        _phase1Played = false;
        _step1Done = false;
        _step2Done = false;
        _inferring = false;
        _pendingResult = null;
        _classificationResult = null;
        _failureReason = null;
        _statusText = e is StateError && e.message.contains("Disconnected")
            ? "Device detached — session invalid. Tap 'New Test' to try again."
            : "Error: $e";
      });
      // No dialog for unexpected errors — status text is sufficient
    }
  }

  Future<void> _playResultAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _ctrl3.forward();
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
    _ideDiffSub?.cancel();
    bleService.cancelAssessment("Analysis screen closed");
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    _spinCtrl.dispose();
    _spinCtrl2.dispose();
    super.dispose();
  }

  Widget _buildStep(
    String text,
    AnimationController ctrl,
    Animation<double> fade,
    Animation<Offset> slide, {
    required bool isDone,
    AnimationController? spinCtrl,
    bool showConnector = false,
  }) {
    const double connectorLeftPad = 17;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fade only (no slide) so the connector line grows in place
        if (showConnector)
          Padding(
            padding: const EdgeInsets.only(left: connectorLeftPad),
            child: FadeTransition(
              opacity: fade,
              child: Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF012532),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: Row(
              children: [
                AnimatedCheck(isDone: isDone, externalSpinCtrl: spinCtrl),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F3A3D),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0XFF012532);
    const accent = Color(0XFF40E0D0);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bool showingResult = _phase1Played;

    final int meterLevel = _levelMap[_classificationResult ?? 'fresh'] ?? 0;

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
                            fontSize: screenWidth * 0.027,
                            color: const Color(0xFF868686),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: showingResult
                            ? _buildAnimatedResult(
                                meterLevel,
                                classColor,
                                screenHeight,
                              )
                            : _buildLoadingArea(screenHeight),
                      ),
                    ),
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

  Widget _buildLoadingArea(double screenHeight) {
    return SizedBox.expand(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/onboardingpage/device_animation.gif',
            width: screenHeight * 0.32,
            height: screenHeight * 0.32,
          ),
          SizedBox(height: screenHeight * 0.012),
          Text(
            _statusText,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF868686),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedResult(
    int meterLevel,
    Color classColor,
    double screenHeight,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('result'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStep(
                      "FRESHNESS EVALUATION",
                      _ctrl1,
                      _fade1,
                      _slide1,
                      isDone: _step1Done,
                      spinCtrl: _spinCtrl,
                    ),
                    _buildStep(
                      "CLASSIFICATION:",
                      _ctrl2,
                      _fade2,
                      _slide2,
                      isDone: _step2Done,
                      spinCtrl: _spinCtrl2,
                      showConnector: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.018),
              AnimatedBuilder(
                animation: _ctrl3,
                builder: (context, child) => Opacity(
                  opacity: _fade3.value,
                  child: Transform.scale(
                    scale: 0.85 + (0.15 * _ctrl3.value),
                    child: child,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FishResultImage(
                      classification: _classificationResult ?? 'fresh',
                      height: screenHeight * 0.16,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Transform.scale(
                      scale: 0.7,
                      child: FreshnessMeter(level: meterLevel),
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text(
                      (_classificationResult ?? '').toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: classColor,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.006),
                    Text(
                      _activeModelLabel.isEmpty
                          ? ''
                          : 'Model: $_activeModelLabel',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF42A5F5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
