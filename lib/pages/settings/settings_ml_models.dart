import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Model data class parsed from CSV
class ModelBenchmark {
  final int rank;
  final String model;
  final double accuracy;
  final double f1Weighted;
  final double f1Macro;
  final double f1Fresh;
  final double f1Moderate;
  final double f1Spoiled;
  final double balancedAccuracy;
  final double latencyMs;
  final double totalBatchMs;

  const ModelBenchmark({
    required this.rank,
    required this.model,
    required this.accuracy,
    required this.f1Weighted,
    required this.f1Macro,
    required this.f1Fresh,
    required this.f1Moderate,
    required this.f1Spoiled,
    required this.balancedAccuracy,
    required this.latencyMs,
    required this.totalBatchMs,
  });

  String get overallPerformance {
    if (rank <= 2) return 'Excellent';
    if (rank <= 5) return 'Very Good';
    return 'Good';
  }

  Color get performanceColor {
    if (rank <= 2) return const Color(0xFF4DD0E1);      // cyan - Excellent
    if (rank <= 5) return const Color(0xFF81C784);      // green - Very Good
    return const Color(0xFFFFB74D);                     // amber - Good
  }

  String get onnxAssetPath {
    final nameMap = {
      'ANN': 'ann_model.onnx',
      'SVM': 'svm_model.onnx',
      'Random Forest': 'random_forest_model.onnx',
      'AdaBoost': 'adaboost_model.onnx',
      'CatBoost': 'catboost_model.onnx',
      'Decision Tree': 'decision_tree_model.onnx',
      'XGBoost': 'xgboost_model.onnx',
      'KNN': 'knn_model.onnx',
    };
    return 'assets/ml_models/${nameMap[model] ?? '${model.toLowerCase()}_model.onnx'}';
  }

  static List<ModelBenchmark> fromCsv(String csv) {
    final lines = csv.trim().split('\n');
    final results = <ModelBenchmark>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length < 10) continue;
      results.add(ModelBenchmark(
        rank: int.parse(cols[0].trim()),
        model: cols[1].trim(),
        accuracy: double.parse(cols[2].trim()),
        f1Weighted: double.parse(cols[3].trim()),
        f1Macro: double.parse(cols[4].trim()),
        f1Fresh: double.parse(cols[5].trim()),
        f1Moderate: double.parse(cols[6].trim()),
        f1Spoiled: double.parse(cols[7].trim()),
        balancedAccuracy: double.parse(cols[8].trim()),
        latencyMs: double.parse(cols[9].trim()),
        totalBatchMs: double.parse(cols[10].trim()),
      ));
    }
    return results;
  }
}

class ModelPerformanceScreen extends StatefulWidget {
  const ModelPerformanceScreen({super.key});

  @override
  State<ModelPerformanceScreen> createState() => _ModelPerformanceScreenState();
}

class _ModelPerformanceScreenState extends State<ModelPerformanceScreen>
    with TickerProviderStateMixin {
  List<ModelBenchmark> _models = [];
  int _selectedRank = 1; // default: ANN (rank 1)
  bool _isLoading = true;
  bool _isSaving = false;

  late AnimationController _saveController;
  late Animation<double> _saveScale;

  @override
  void initState() {
    super.initState();
    _saveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _saveScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _saveController, curve: Curves.easeInOut),
    );
    _loadBenchmarkData();
  }

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  Future<void> _loadBenchmarkData() async {
    try {
      final csv = await rootBundle.loadString('assets/data/benchmark_summary.csv');
      setState(() {
        _models = ModelBenchmark.fromCsv(csv);
        _isLoading = false;
      });
    } catch (e) {
      // Fallback: inline hardcoded data matching the CSV
      setState(() {
        _models = ModelBenchmark.fromCsv(
          'Rank,Model,Accuracy (%),F1 Weighted,F1 Macro,F1 (fresh),F1 (moderate),F1 (spoiled),Balanced Accuracy,Latency/sample (ms),Total batch (ms)\n'
          '1,ANN,95.4315,0.9544,0.9658,1.0,0.9543,0.9432,0.9668,0.0212,1.31\n'
          '2,SVM,95.4315,0.9543,0.9658,1.0,0.9546,0.9427,0.9662,0.099,3.46\n'
          '3,Random Forest,95.2623,0.9527,0.9645,1.0,0.9529,0.9407,0.9651,0.027,3.47\n'
          '4,AdaBoost,95.2623,0.9526,0.9645,1.0,0.953,0.9404,0.9648,0.4304,3.87\n'
          '5,CatBoost,95.2623,0.9526,0.9645,1.0,0.953,0.9404,0.9648,0.0174,1.46\n'
          '6,Decision Tree,95.0931,0.951,0.9634,1.0,0.9506,0.9395,0.9649,0.014,0.63\n'
          '7,XGBoost,95.0931,0.9509,0.961,0.9915,0.9513,0.9404,0.9636,0.0281,3.74\n'
          '8,KNN,94.9239,0.9493,0.962,1.0,0.9495,0.9364,0.9625,7.5749,77.25\n',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    _saveController.forward().then((_) => _saveController.reverse());
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _isSaving = false);
    // TODO: Persist selected model, initialize OrtService with selected model's asset path
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Model saved: ${_models.firstWhere((m) => m.rank == _selectedRank).model}',
            style: const TextStyle(
              fontFamily: 'Courier New',
              color: Color(0xFF0D1B2A),
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFFFFC94A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021E28),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFC94A),
                      ),
                    )
                  : _buildModelList(),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, color: Color.fromARGB(255, 248, 248, 248), size: 22),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hexagonal icon
                Icon(FontAwesomeIcons.hexagonNodes, color: Color(0XFFFFCB62), size: 34),
                SizedBox(width: 10),
                Text(
                  'Model and\nPerformance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          // Spacer to balance back button
          const SizedBox(width: 72),
        ],
      ),
    );
  }

  Widget _buildModelList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 16, 12),
          child: Text(
            'Select Machine Learning Model to use:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _models.length,
            itemBuilder: (context, index) {
              final model = _models[index];
              return _ModelCard(
                model: model,
                isSelected: _selectedRank == model.rank,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedRank = model.rank);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: ScaleTransition(
        scale: _saveScale,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC94A),
              disabledBackgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF0D1B2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF0D1B2A),
                    ),
                  )
                : const Text(
                    'SAVE CHANGES',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Model Card ──────────────────────────────────────────────────────────────

class _ModelCard extends StatelessWidget {
  final ModelBenchmark model;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: const Color.fromARGB(193, 2, 60, 81),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFFC94A).withOpacity(0.5)
                    : Colors.white.withOpacity(0.06),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFC94A).withOpacity(0.08),
                        blurRadius: 12,
                        spreadRadius: 0,
                      )
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Model icon
                _ModelIcon(model: model),
                const SizedBox(width: 14),
                // Model info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(model.model),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _subtitle(model.model),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Stats row
                      Row(
                        children: [
                          _StatChip(
                            label: 'Accuracy:',
                            value: '${model.accuracy.toStringAsFixed(2)}%',
                            valueColor: const Color(0xFF4DD0E1),
                          ),
                          const SizedBox(width: 12),
                          _StatChip(
                            label: 'Speed:',
                            value: '${model.latencyMs} ms',
                            valueColor: Colors.white.withOpacity(0.85),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overall Performance:',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                model.overallPerformance,
                                style: TextStyle(
                                  color: model.performanceColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4DD0E1)
                          : Colors.white.withOpacity(0.3),
                      width: isSelected ? 2 : 1.5,
                    ),
                    color: isSelected
                        ? const Color(0xFF4DD0E1).withOpacity(0.15)
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4DD0E1),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(String model) {
    const map = {
      'Random Forest': 'Random Forest',
      'Decision Tree': 'TREE',
      'XGBoost': 'XGBOOST',
      'AdaBoost': 'AdaBoost',
      'CatBoost': 'CATBOOST',
    };
    return map[model] ?? model;
  }

  String _subtitle(String model) {
    const map = {
      'ANN': 'Artificial Neural Network',
      'SVM': 'Support Vector Machines',
      'Random Forest': 'Random Forest',
      'AdaBoost': 'Adaptive Boosting',
      'CatBoost': 'Categorical Boosting',
      'Decision Tree': 'Decision Tree',
      'XGBoost': 'Extreme Gradient Boosting',
      'KNN': 'K-Nearest Neighbors',
    };
    return map[model] ?? model;
  }
}

// ─── Model Icon ───────────────────────────────────────────────────────────────

class _ModelIcon extends StatelessWidget {
  final ModelBenchmark model;
  const _ModelIcon({required this.model});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = _iconFor(model.model);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }

  (IconData, Color) _iconFor(String model) {
    return switch (model) {
      'ANN' => (Icons.memory, const Color(0xFFEF5350)),
      'SVM' => (Icons.shape_line, const Color(0xFFFFC94A)),
      'Random Forest' => (Icons.park, const Color(0xFF66BB6A)),
      'AdaBoost' => (Icons.rocket_launch, const Color(0xFFFFA726)),
      'CatBoost' => (Icons.bar_chart, const Color(0xFFEF5350)),
      'Decision Tree' => (Icons.device_hub, const Color(0xFFFF7043)),
      'XGBoost' => (Icons.bolt, const Color(0xFF42A5F5)),
      'KNN' => (Icons.hub, const Color(0xFF26C6DA)),
      _ => (Icons.psychology, const Color(0xFF9E9E9E)),
    };
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Hex Icon (header decoration) ────────────────────────────────────────────

class _HexIcon extends StatelessWidget {
  const _HexIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(32, 32),
      painter: _HexPainter(),
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(Icons.psychology_alt, color: Color(0xFFFFC94A), size: 16),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC94A).withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFFFFC94A).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = _hexPath(size);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  Path _hexPath(Size size) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 1;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * 3.14159265 / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  double cos(double rad) => _cos(rad);
  double sin(double rad) => _sin(rad);

  // Simple trig approximation using dart:math would be cleaner,
  // but keeping self-contained:
  double _cos(double x) {
    // Use series: 1 - x^2/2! + x^4/4! - ...
    double r = x % (2 * 3.14159265358979);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 8; i++) {
      term *= -r * r / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _sin(double x) {
    double r = x % (2 * 3.14159265358979);
    double result = r;
    double term = r;
    for (int i = 1; i <= 8; i++) {
      term *= -r * r / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}