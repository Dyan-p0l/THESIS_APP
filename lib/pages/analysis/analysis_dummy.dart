import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/ort_service.dart';
import '../../services/tflite_service.dart';
import 'save_reading/savedialog.dart';
import '../../db/dbhelper.dart';
import '../../models/readings.dart';
import '../../services/mode_selection_service.dart';
import 'anim/loadinganim.dart';     
import 'anim/rotatingcheck.dart';     
import 'anim/freshnessmeter.dart';

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
  bool _phase2Played = false;

  String? _classificationResult;
  bool _inferring = false;

  ModelEntry? _activeModel;
  String _activeModelLabel = '';

  // ── Animation controllers (mirrors ResultScreen) ──────────────────────────
  late AnimationController _ctrl1;
  late AnimationController _ctrl2;
  late AnimationController _ctrl3;

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

  // Maps classification string to FreshnessMeter level index
  static const _levelMap = {'fresh': 0, 'moderate': 1, 'spoiled': 2};

  @override
  void initState() {
    super.initState();
    _calibrationPf = bleService.latestCalibrationPf;

    // ── Set up animation controllers ─────────────────────────────────────────
    _ctrl1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _ctrl2 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _ctrl3 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _fade1 = Tween(begin: 0.0, end: 1.0).animate(_ctrl1);
    _fade2 = Tween(begin: 0.0, end: 1.0).animate(_ctrl2);
    _fade3 = Tween(begin: 0.0, end: 1.0).animate(_ctrl3);

    _slide1 =
        Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_ctrl1);
    _slide2 =
        Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_ctrl2);
    _slide3 =
        Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_ctrl3);

    // ── BLE streams ──────────────────────────────────────────────────────────
    _capSub = bleService.capacitanceStream.listen((value) {
      if (!mounted) return;
      setState(() => _capacitancePf = value);
    });
    _stableSub = bleService.stableStream.listen((value) {
      if (!mounted) return;
      setState(() => _stableNow = value);

      if (value && !_phase1Played && _classificationResult == null) {
        _phase2Played = true;
        _ctrl2.forward();
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
    final entry = await ModelSelectionService.loadSelectedEntry();
    if (!mounted) return;

    setState(() {
      _activeModel = entry;
      final runtimeLabel =
          entry.runtime == ModelRuntime.tflite ? 'TFLite' : 'ONNX';
      _activeModelLabel = '${entry.name} ($runtimeLabel)';
    });

    if (entry.runtime == ModelRuntime.tflite) {
      await TFLiteService.init(assetPath: entry.assetPath);
    } else {
      await OrtService.init(assetPath: entry.assetPath);
    }

    await _beginAssessment();
  }

  // ── Resets animations then starts a new assessment ────────────────────────
  Future<void> _beginAssessment() async {
    // Reset all three controllers so the animation replays on "New Test"
    _ctrl1.reset();
    _ctrl2.reset();
    _ctrl3.reset();

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
      _phase1Played = false;
    });

    await bleService.sendClassification(BleService.cmdClear);

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

        // ── Kick off the step-by-step reveal animation ──────────────────────
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

  Future<void> _playResultAnimation() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _ctrl3.forward();
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
    super.dispose();
  }

  // ── Builds an animated step row (mirrors ResultScreen.buildStep) ───────────
  Widget _buildStep(
      String text, AnimationController ctrl, Animation<double> fade,
      Animation<Offset> slide) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Row(
          children: [
            AnimatedCheck(isDone: ctrl.isCompleted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F3A3D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0XFF012532);
    const accent = Color(0XFF40E0D0);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bool showingResult = _phase2Played && !_waiting;

    final int meterLevel =
        _levelMap[_classificationResult ?? 'fresh'] ?? 0;

    final classColor = _classificationResult != null
        ? _labelColors[_classificationResult!]!
        : const Color(0xFF012532);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
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

            // ── Capacitance value ────────────────────────────────────────────
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

            // ── Baseline / IDE diff ──────────────────────────────────────────
            Text( 
              _waiting
                  ? (_calibrationPf == null
                      ? 'Baseline: --'
                      : 'Baseline: ${_calibrationPf!.toStringAsFixed(3)} pF')
                  : (_ideDiffPf == null
                      ? 'IDE diff per channel: --'
                      : 'IDE diff per channel: ${_ideDiffPf!.toStringAsFixed(3)} pF'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: screenWidth * 0.032,
                color: Colors.white38,
              ),
            ),

            // ── Stable indicator ─────────────────────────────────────────────
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

            // ── White card panel ─────────────────────────────────────────────
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
                    // ── Hint row ───────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            color: const Color(0xFF868686),
                            size: screenWidth * 0.065),
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
                    SizedBox(height: screenHeight * 0.018),

                    // ── MAIN AREA: loading GIF  OR  animated result ────────
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: showingResult
                            ? _buildAnimatedResult(meterLevel, classColor, screenHeight)
                            : _buildLoadingArea(screenHeight),
                      ),
                    ),

                    // ── Buttons ───────────────────────────────────────────
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
                                borderRadius:
                                    BorderRadius.circular(screenWidth * 0.05),
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
                                borderRadius:
                                    BorderRadius.circular(screenWidth * 0.05),
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

  // ── Loading area: GIF + status text ───────────────────────────────────────
  Widget _buildLoadingArea(double screenHeight) {
    return Column(
      key: const ValueKey('loading'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const LoadingAnim(),
        SizedBox(height: screenHeight * 0.015),
        Text(
          _inferring ? "Classifying..." : _statusText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF5E6B70),
          ),
        ),
        // Show error hint when not waiting and session is invalid
        if (!_waiting && !_inferring && !_sessionValid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  // ── Result area: step-by-step reveal animation ────────────────────────────
  Widget _buildAnimatedResult(int meterLevel, Color classColor, double screenHeight) {
    return SingleChildScrollView(
      key: const ValueKey('result'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step 1 — Evaluation label
            _buildStep(
              "FRESHNESS EVALUATION",
              _ctrl1,
              _fade1,
              _slide1,
            ),
            SizedBox(height: screenHeight * 0.022),

            // Step 2 — Classification label
            _buildStep(
              "CLASSIFICATION:",
              _ctrl2,
              _fade2,
              _slide2,
            ),
            SizedBox(height: screenHeight * 0.025),

            // Step 3 — Meter + result label + active model
            FadeTransition(
              opacity: _fade3,
              child: SlideTransition(
                position: _slide3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FreshnessMeter(level: meterLevel),
                    SizedBox(height: screenHeight * 0.012),
                    Text(
                      (_classificationResult ?? '').toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: classColor,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      _activeModelLabel.isEmpty
                          ? ''
                          : 'Model: $_activeModelLabel',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF42A5F5),
                      ),
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