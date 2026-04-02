import 'package:flutter/material.dart';
import 'freshnessmeter.dart';
import 'rotatingcheck.dart';


class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {

  final List<String> classification = ['Fresh', 'Moderate', 'Spoiled'];
  final List<String> imgpath = [
    'assets/images/analysis/results/fresh.png',
    'assets/images/analysis/results/moderate.png',
    'assets/images/analysis/results/spoiled.png'
  ];

  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  late Animation<double> _fade1;
  late Animation<double> _fade2;
  late Animation<double> _fade3;

  late Animation<Offset> _slide1;
  late Animation<Offset> _slide2;
  late Animation<Offset> _slide3;

  @override
  void initState() {
    super.initState();

    _controller1 =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _controller2 =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _controller3 =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _fade1 = Tween(begin: 0.0, end: 1.0).animate(_controller1);
    _fade2 = Tween(begin: 0.0, end: 1.0).animate(_controller2);
    _fade3 = Tween(begin: 0.0, end: 1.0).animate(_controller3);

    _slide1 = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_controller1);
    _slide2 = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_controller2);
    _slide3 = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_controller3);

    startSequence();
  }

  Future<void> startSequence() async {
    await Future.delayed(const Duration(milliseconds: 600));
    await _controller1.forward();
    setState(() {});
    
    await Future.delayed(const Duration(milliseconds: 600));
    await _controller2.forward();
    setState(() {});
    
    await Future.delayed(const Duration(milliseconds: 600));
    await _controller3.forward();
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  Widget buildStep(String text, AnimationController controller) {
    return Row(
      children: [
        AnimatedCheck(isDone: controller.isCompleted),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F3A3D),
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {

    int resultIndex = 1; 

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            /// STEP 1
            FadeTransition(
              opacity: _fade1,
              child: SlideTransition(
                position: _slide1,
                child: buildStep("FRESHNESS EVALUATION", _controller1),
              ),
            ),

            const SizedBox(height: 20),

            /// STEP 2
            FadeTransition(
              opacity: _fade2,
              child: SlideTransition(
                position: _slide2,
                child: buildStep("CLASSIFICATION:", _controller2),
              ),
            ),

            const SizedBox(height: 30),

            /// STEP 3 (Fish + Result)
            FadeTransition(
              opacity: _fade3,
              child: SlideTransition(
                position: _slide3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      imgpath[resultIndex],
                      height: 150,
                    ),
                    const SizedBox(height: 25),

                    FreshnessMeter(level: resultIndex),
                    
                    const SizedBox(height: 6),

                    Text(
                      classification[resultIndex].toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1DB6A4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}