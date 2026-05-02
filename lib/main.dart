import 'package:flutter/material.dart';
import 'package:thesis_app/pages/connectivity/connectivity.dart';
import 'package:thesis_app/pages/staticpages/onboarding.dart';
import 'package:thesis_app/pages/analysis/analysis_dummy.dart';
import 'package:thesis_app/pages/history/history_page.dart';
import 'package:thesis_app/pages/savedsamplereading/saved_samples.dart';
import 'package:thesis_app/pages/savedsamplereading/sample_readings.dart';
import 'package:thesis_app/pages/savedsamplereading/viewgraph.dart';
import 'package:thesis_app/services/ble_service.dart';
import 'package:thesis_app/pages/settings/settings.dart';
import 'package:thesis_app/pages/settings/settings_ml_models.dart';
import 'package:thesis_app/pages/settings/settings_data_retention.dart';
import 'package:thesis_app/pages/settings/settings_connectivity.dart';
import 'package:thesis_app/pages/settings/settings_calibration.dart';
import 'package:thesis_app/pages/settings/settings_display.dart';
import 'package:thesis_app/pages/connectivity/bluetooth_scan.dart';
import 'package:thesis_app/services/csv_import_service.dart'; // ← ADD THIS

Future<void> main() async {
  // ← async + Future<void>
  WidgetsFlutterBinding.ensureInitialized();
  await CsvImportService.importReadings(skipIfExists: true);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final BleService _bleService = BleService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bleService.startAutoConnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bleService.startAutoConnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'Inter',
      ),
      home: const OnboardingScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/homepage': (context) => const ConnectivityScreen(),
        '/analysis': (context) => const AnalysisScreenDummy(),
        '/history': (context) => const HistoryPage(),
        '/settings': (context) => const SettingsPage(),
        '/settings_ml_models': (context) => const ModelPerformanceScreen(),
        '/settings_data_retention': (context) =>
            const SettingsDataRetentionPage(),
        '/settings_connectivity': (context) =>
            const SettingsConnectivityScreen(),
        '/settings_calibration': (context) => const SettingsCalibrationScreen(),
        '/settings_display': (context) => const SettingsDisplayScreen(),
        '/bluetooth_scan': (context) => const BluetoothScanScreen(),
        '/saved_samples': (context) => const SavedSamplesScreen(),
        '/sample_readings': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return SampleReadingsScreen(
            sampleId: args['sampleId'] as int,
            sampleLabel: args['sampleLabel'] as String,
          );
        },
        '/sample_graph': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ViewGraphScreen(
            sampleId: args['sampleId'] as int,
            sampleLabel: args['sampleLabel'] as String,
          );
        },
      },
    );
  }
}
