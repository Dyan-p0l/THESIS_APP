import 'package:flutter/material.dart';
import 'package:thesis_app/pages/connectivity/connectivity.dart';
import 'pages/staticpages/onboarding.dart';
import 'pages/analysis/analysis.dart';
import 'pages/history/history_page.dart';
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
        '/history' : (context) => const HistoryPage(),
      },
    );
  }
}