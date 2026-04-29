import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' show max;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Import the service you created in model_selection_service.dart
import '../../services/mode_selection_service.dart';

// ─── Responsive font helper ───────────────────────────────────────────────────
class _F {
  static double s(BuildContext ctx, double factor) =>
      MediaQuery.of(ctx).size.width * factor;

  static double title(BuildContext ctx)      => s(ctx, 0.046);
  static double body(BuildContext ctx)       => s(ctx, 0.037);
  static double cardName(BuildContext ctx)   => s(ctx, 0.044);
  static double cardSub(BuildContext ctx)    => s(ctx, 0.031);
  static double chipLabel(BuildContext ctx)  => s(ctx, 0.026);
  static double chipValue(BuildContext ctx)  => s(ctx, 0.028);
  static double backBtn(BuildContext ctx)    => s(ctx, 0.041);
  static double saveBtn(BuildContext ctx)    => s(ctx, 0.038);
  static double headerIcon(BuildContext ctx) => s(ctx, 0.087);
}

// ─── Model data ───────────────────────────────────────────────────────────────

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
    if (rank <= 2) return const Color(0xFF4DD0E1);
    if (rank <= 5) return const Color(0xFF81C784);
    return const Color(0xFFFFB74D);
  }

  /// Runtime badge: shows which inference engine this model uses.
  ModelRuntime get runtime => ModelSelectionService.entryForRank(rank).runtime;

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

// ─── Screen ───────────────────────────────────────────────────────────────────

class ModelPerformanceScreen extends StatefulWidget {
  const ModelPerformanceScreen({super.key});

  @override
  State<ModelPerformanceScreen> createState() => _ModelPerformanceScreenState();
}

class _ModelPerformanceScreenState extends State<ModelPerformanceScreen>
    with TickerProviderStateMixin {
  List<ModelBenchmark> _models = [];
  int _selectedRank = 1;
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
    _loadSavedSelection(); // ← NEW: restore previously saved rank
  }

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  // ── NEW: restore the persisted selection on open ────────────────────────────
  Future<void> _loadSavedSelection() async {
    final rank = await ModelSelectionService.loadSelectedRank();
    if (mounted) setState(() => _selectedRank = rank);
  }

  Future<void> _loadBenchmarkData() async {
    try {
      final csv = await rootBundle.loadString('assets/data/benchmark_summary.csv');
      setState(() {
        _models = ModelBenchmark.fromCsv(csv);
        _isLoading = false;
      });
    } catch (e) {
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

  // ── UPDATED: now also persists to SharedPreferences ────────────────────────
  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    _saveController.forward().then((_) => _saveController.reverse());
    setState(() => _isSaving = true);

    // Persist selection
    await ModelSelectionService.saveSelection(rank: _selectedRank);

    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _isSaving = false);

    if (mounted) {
      final selected = _models.firstWhere((m) => m.rank == _selectedRank);
      final entry = ModelSelectionService.entryForRank(_selectedRank);
      final runtimeLabel =
          entry.runtime == ModelRuntime.tflite ? 'TFLite' : 'ONNX';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Model saved: ${selected.model} ($runtimeLabel)',
            style: TextStyle(
              fontFamily: 'Courier New',
              color: const Color(0xFF0D1B2A),
              fontWeight: FontWeight.w600,
              fontSize: _F.body(context),
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
                      child: CircularProgressIndicator(color: Color(0xFFFFC94A)),
                    )
                  : _buildModelList(context),
            ),
            _buildSaveButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.fromLTRB(sw * 0.02, sw * 0.031, sw * 0.041, sw * 0.02),
      child: Row(
        children: [
          _BackButtonWidget(
            onTap: () => Navigator.of(context).maybePop(),
            fontSize: _F.backBtn(context),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.hexagonNodes,
                  color: const Color(0xFFFFCB62),
                  size: _F.headerIcon(context),
                ),
                SizedBox(width: sw * 0.026),
                Flexible(
                  child: Text(
                    'Model and\nPerformance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _F.title(context),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Opacity(
            opacity: 0,
            child: _BackButtonWidget(onTap: () {}, fontSize: _F.backBtn(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(sw * 0.051, sw * 0.01, sw * 0.041, sw * 0.031),
          child: Text(
            'Select Machine Learning Model to use:',
            style: TextStyle(
              color: Colors.white,
              fontSize: _F.body(context),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              max(sw * 0.041, MediaQuery.of(context).padding.left),
              0,
              max(sw * 0.041, MediaQuery.of(context).padding.right),
              sw * 0.02,
            ),
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

  Widget _buildSaveButton(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.fromLTRB(sw * 0.041, sw * 0.02, sw * 0.041, sw * 0.051),
      child: ScaleTransition(
        scale: _saveScale,
        child: SizedBox(
          width: double.infinity,
          height: sw * 0.138,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC94A),
              disabledBackgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF0D1B2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(sw * 0.077),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? SizedBox(
                    width: sw * 0.056,
                    height: sw * 0.056,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF0D1B2A),
                    ),
                  )
                : Text(
                    'SAVE CHANGES',
                    style: TextStyle(
                      fontSize: _F.saveBtn(context),
                      fontWeight: FontWeight.w800,
                      letterSpacing: sw * 0.0036,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Back Button ─────────────────────────────────────────────────────────────

class _BackButtonWidget extends StatelessWidget {
  final VoidCallback onTap;
  final double fontSize;

  const _BackButtonWidget({required this.onTap, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.031,
            vertical: MediaQuery.of(context).size.width * 0.02,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left,
                color: const Color.fromARGB(255, 248, 248, 248),
                size: fontSize * 1.35,
              ),
              Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Model Card ───────────────────────────────────────────────────────────────

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
    final sw = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.only(bottom: sw * 0.026),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(sw * 0.041),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 340;
              final iconSize = sw * (isNarrow ? 0.082 : 0.103);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(193, 2, 60, 81),
                  borderRadius: BorderRadius.circular(sw * 0.041),
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
                          )
                        ]
                      : null,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: sw * 0.041,
                  vertical: sw * 0.036,
                ),
                child: Row(
                  children: [
                    _ModelIcon(model: model, size: iconSize),
                    SizedBox(width: sw * 0.036),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _displayName(model.model),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _F.cardName(context),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              // ── Runtime badge ─────────────────────────────
                              _RuntimeBadge(runtime: model.runtime),
                            ],
                          ),
                          SizedBox(height: sw * 0.003),
                          Text(
                            _subtitle(model.model),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: _F.cardSub(context),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: sw * 0.02),
                          Wrap(
                            spacing: sw * 0.026,
                            runSpacing: sw * 0.01,
                            children: [
                              _StatChip(
                                label: 'Accuracy:',
                                value: '${model.accuracy.toStringAsFixed(2)}%',
                                valueColor: const Color(0xFF4DD0E1),
                                labelSize: _F.chipLabel(context),
                                valueSize: _F.chipValue(context),
                              ),
                              _StatChip(
                                label: 'Speed:',
                                value: '${model.latencyMs} ms',
                                valueColor: Colors.white.withOpacity(0.85),
                                labelSize: _F.chipLabel(context),
                                valueSize: _F.chipValue(context),
                              ),
                              _StatChip(
                                label: 'Overall Performance:',
                                value: model.overallPerformance,
                                valueColor: model.performanceColor,
                                labelSize: _F.chipLabel(context),
                                valueSize: _F.chipValue(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: sw * 0.031),
                    // Radio indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: sw * 0.062,
                      height: sw * 0.062,
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
                                width: sw * 0.026,
                                height: sw * 0.026,
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
              );
            },
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

// ─── Runtime Badge ────────────────────────────────────────────────────────────
// Small pill that shows TFLite vs ONNX so the user knows which engine runs each model.

class _RuntimeBadge extends StatelessWidget {
  final ModelRuntime runtime;
  const _RuntimeBadge({required this.runtime});

  @override
  Widget build(BuildContext context) {
    final isTflite = runtime == ModelRuntime.tflite;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (isTflite ? const Color(0xFFFF7043) : const Color(0xFF42A5F5))
            .withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isTflite ? const Color(0xFFFF7043) : const Color(0xFF42A5F5))
              .withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        isTflite ? 'TFLite' : 'ONNX',
        style: TextStyle(
          color: isTflite ? const Color(0xFFFF7043) : const Color(0xFF42A5F5),
          fontSize: _F.chipLabel(context),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Model Icon ───────────────────────────────────────────────────────────────

class _ModelIcon extends StatelessWidget {
  final ModelBenchmark model;
  final double size;

  const _ModelIcon({required this.model, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = _iconFor(model.model);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Icon(icon, color: color, size: size * 0.65),
    );
  }

  (IconData, Color) _iconFor(String model) {
    return switch (model) {
      'ANN'           => (Icons.memory,        const Color(0xFFEF5350)),
      'SVM'           => (Icons.shape_line,     const Color(0xFFFFC94A)),
      'Random Forest' => (Icons.park,           const Color(0xFF66BB6A)),
      'AdaBoost'      => (Icons.rocket_launch,  const Color(0xFFFFA726)),
      'CatBoost'      => (Icons.bar_chart,      const Color(0xFFEF5350)),
      'Decision Tree' => (Icons.device_hub,     const Color(0xFFFF7043)),
      'XGBoost'       => (Icons.bolt,           const Color(0xFF42A5F5)),
      'KNN'           => (Icons.hub,            const Color(0xFF26C6DA)),
      _               => (Icons.psychology,     const Color(0xFF9E9E9E)),
    };
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final double labelSize;
  final double valueSize;

  const _StatChip({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelSize,
    required this.valueSize,
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
            fontSize: labelSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: valueSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}