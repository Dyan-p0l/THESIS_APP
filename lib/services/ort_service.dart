import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'dart:typed_data';

class OrtService {
  static OrtSession? _session;
  static Future<void>? _initFuture; // Guard against concurrent init calls

  static Future<void> init({
    String assetPath = 'assets/ml_models/knn_model.onnx',
  }) async {
    // If already initializing, wait for that to finish instead of starting again
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    if (_session != null) return;

    _initFuture = _doInit(assetPath);
    await _initFuture;
  }

  static Future<void> _doInit(String assetPath) async {
    try {
      OrtEnv.instance.init();
      // Give the native environment a microtask cycle to settle
      await Future.microtask(() {});

      final bytes = await rootBundle.load(assetPath);
      final modelBytes = bytes.buffer.asUint8List();
      final options = OrtSessionOptions();
      _session = OrtSession.fromBuffer(modelBytes, options);
    } finally {
      _initFuture = null;
    }
  }

  static Future<int> classify(double capacitancePf) async {
    // Instead of assert, ensure init is complete defensively
    if (_session == null) {
      await init();
    }

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList([capacitancePf]),
      [1, 1],
    );

    final runOptions = OrtRunOptions();

    final outputs = await _session!.runAsync(
      runOptions,
      {'float_input': inputTensor},
    );

    inputTensor.release();
    runOptions.release();

    int label = 0;
    final raw = outputs?.first?.value;
    if (raw is List && raw.isNotEmpty) {
      label = (raw.first as num).toInt();
    }

    for (final o in outputs ?? []) {
      o?.release();
    }

    return label.clamp(0, 2);
  }

  static void dispose() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }
}