import 'package:flutter/material.dart';
import 'package:thesis_app/pages/connectivity/connectivity.dart';
import 'package:thesis_app/pages/staticpages/onboarding.dart';
import 'package:thesis_app/pages/analysis/analysis.dart';
import 'package:thesis_app/pages/history/history_page.dart';
import 'package:thesis_app/pages/savedsamplereading/saved_samples.dart';
import 'package:thesis_app/pages/savedsamplereading/sample_readings.dart';
import 'package:thesis_app/pages/savedsamplereading/viewgraph.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'Inter',
      ),
      home: const OnboardingScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/homepage': (context) => const ConnectivityScreen(),
        '/analysis': (context) => const AnalysisScreen(),
        '/history': (context) => const HistoryPage(),
        '/saved_samples': (context) => const SavedSamplesScreen(),
        '/sample_readings': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return SampleReadingsScreen(
            sampleId:    args['sampleId']    as int,
            sampleLabel: args['sampleLabel'] as String,
          );
        },
        '/sample_graph': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ViewGraphScreen(
            sampleId:    args['sampleId']    as int,
            sampleLabel: args['sampleLabel'] as String,
          );
        },
      },
    );
  }
}
