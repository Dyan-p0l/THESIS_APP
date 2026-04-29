import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class TFLiteService {
  static Interpreter? _interpreter;
  static Future<void>? _initFuture;

  static Future<void> init({
    String assetPath = 'assets/ml_models/ann_model.tflite',
  }) async {
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    if (_interpreter != null) return;

    _initFuture = _doInit(assetPath);
    await _initFuture;
  }

  static Future<void> _doInit(String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final modelBytes = bytes.buffer.asUint8List();
      _interpreter = Interpreter.fromBuffer(modelBytes);
    } finally {
      _initFuture = null;
    }
  }

  static Future<int> classify(double capacitancePf) async {
    if (_interpreter == null) await init();

    final input = [[capacitancePf]]; // shape [1, 1]

    // Inspect the output tensor shape at runtime so this works
    // regardless of whether the model returns [1,1] or [1,3].
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final numClasses = outputShape.length > 1 ? outputShape[1] : 1;

    if (numClasses > 1) {
      // Model returns class probabilities, e.g. [1, 3] — take argmax.
      final output = [List.filled(numClasses, 0.0)]; // shape [1, numClasses]
      _interpreter!.run(input, output);

      final probs = output[0];
      int bestIndex = 0;
      double bestValue = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestValue) {
          bestValue = probs[i];
          bestIndex = i;
        }
      }
      return bestIndex.clamp(0, 2);
    } else {
      // Model returns a single label directly, e.g. [1, 1].
      final output = [[0.0]];
      _interpreter!.run(input, output);
      return output[0][0].round().clamp(0, 2);
    }
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}