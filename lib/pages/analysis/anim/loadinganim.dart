import 'package:flutter/material.dart';

class LoadingAnim extends StatelessWidget {
  const LoadingAnim({super.key});

  @override
  Widget build(BuildContext context) {
    return 
    Center(
        child: Image.asset(
          'assets/images/onboardingpage/device_animation.gif',
          width: 300,
          height: 300,
        )
    );
  }
}