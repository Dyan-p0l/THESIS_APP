import 'package:flutter/material.dart';

/// Lightweight widget — only provides the fish image for a given classification.
/// All step animations, meter, and label are rendered by AnalysisScreenDummy.
class FishResultImage extends StatelessWidget {
  final String classification; // 'fresh' | 'moderate' | 'spoiled'
  final double height;

  const FishResultImage({
    super.key,
    required this.classification,
    this.height = 120,
  });

  static const _imgMap = {
    'fresh':    'assets/images/analysis/results/fresh.png',
    'moderate': 'assets/images/analysis/results/moderate.png',
    'spoiled':  'assets/images/analysis/results/spoiled.png',
  };

  @override
  Widget build(BuildContext context) {
    final path = _imgMap[classification] ?? _imgMap['fresh']!;
    return Image.asset(path, height: height);
  }
}