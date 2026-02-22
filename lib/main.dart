import 'package:flutter/material.dart';
import 'staticpages/onboarding.dart';
import 'homepage.dart';
import 'analysis/analysis.dart';

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
      ),
      home: const OnboardingScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/homepage': (context) => const Homepage(),
        '/analysis': (context) => const AnalysisScreen(),
      },
    );
  }
}