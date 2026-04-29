import 'package:shared_preferences/shared_preferences.dart';

// ─── Model Runtime ────────────────────────────────────────────────────────────
// Tells AnalysisScreen which inference engine to use.
enum ModelRuntime { onnx, tflite }

// ─── Model Entry ─────────────────────────────────────────────────────────────
// A single entry mirrors one row in ModelBenchmark.
// Add more entries here if you add new models in the future.
class ModelEntry {
  final int rank;
  final String name;          // e.g. 'ANN', 'KNN'
  final ModelRuntime runtime;
  final String assetPath;     // path inside assets/

  const ModelEntry({
    required this.rank,
    required this.name,
    required this.runtime,
    required this.assetPath,
  });
}

// ─── Registry ────────────────────────────────────────────────────────────────
// Single source of truth for every available model.
// Keep this list in sync with ModelBenchmark data in model_performance_screen.dart.
const List<ModelEntry> kModelRegistry = [
  // TFLite models
  ModelEntry(
    rank: 1,
    name: 'ANN',
    runtime: ModelRuntime.tflite,
    assetPath: 'assets/ml_models/ann_model.tflite',
  ),
  // ONNX models
  ModelEntry(
    rank: 2,
    name: 'SVM',
    runtime: ModelRuntime.onnx,
    assetPath: 'assets/ml_models/svm_model.onnx',
  ),
  ModelEntry(
    rank: 3,
    name: 'Random Forest',
    runtime: ModelRuntime.onnx,
    assetPath: 'assets/ml_models/random_forest_model.onnx',
  ),
  ModelEntry(
    rank: 4,
    name: 'AdaBoost',
    runtime: ModelRuntime.onnx,
    assetPath: 'assets/ml_models/adaboost_model.onnx',
  ),
  ModelEntry(
    rank: 5,
    name: 'CatBoost',
    runtime: ModelRuntime.onnx,
    assetPath: 'assets/ml_models/catboost_model.onnx',
  ),
  ModelEntry(
    rank: 6,
    name: 'Decision Tree',
    runtime: ModelRuntime.onnx,
    assetPath: 'assets/ml_models/decision_tree_model.onnx',
  ),
  ModelEntry(
    rank: 7,
    name: 'XGBoost',
    runtime: ModelRuntime.onnx,
    assetPath: 'assets/ml_models/xgboost_model.onnx',
  ),
  ModelEntry(
    rank: 8,
    name: 'KNN',
    runtime: ModelRuntime.onnx,
    assetPath: 'assets/ml_models/knn_model.onnx',
  ),
];

// ─── ModelSelectionService ────────────────────────────────────────────────────
// Persists the user's chosen model rank with SharedPreferences.
// Usage:
//   await ModelSelectionService.saveSelection(rank: 3);
//   final entry = await ModelSelectionService.loadSelection();
class ModelSelectionService {
  static const _kKey = 'selected_model_rank';
  static const int _kDefaultRank = 1; // ANN is default

  /// Persist the user's chosen rank.
  static Future<void> saveSelection({required int rank}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKey, rank);
  }

  /// Load the persisted rank (falls back to default if nothing saved yet).
  static Future<int> loadSelectedRank() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kKey) ?? _kDefaultRank;
  }

  /// Convenience: load the full [ModelEntry] for the saved rank.
  /// Falls back to rank-1 entry if no match found.
  static Future<ModelEntry> loadSelectedEntry() async {
    final rank = await loadSelectedRank();
    return entryForRank(rank);
  }

  /// Look up a [ModelEntry] by rank. Falls back to rank-1 if not found.
  static ModelEntry entryForRank(int rank) {
    return kModelRegistry.firstWhere(
      (e) => e.rank == rank,
      orElse: () => kModelRegistry.first,
    );
  }
}