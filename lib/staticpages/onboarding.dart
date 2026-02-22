import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final LiquidController _controller = LiquidController();
  int _currentPage = 0;

  final pages = [
    OnboardingScreen1(),
    OnboardingScreen2(),
    OnboardingScreen3(),
  ];

  final List<Color> indicatorColor = [
    Color(0XFF56DFB1),
    Color(0XFF012532),
    Color(0XFF56DFB1)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          LiquidSwipe(
            pages: pages, 
            enableLoop: false,
            fullTransitionValue: 600,
            waveType: WaveType.liquidReveal,
            enableSideReveal: false,
            liquidController: _controller,
            onPageChangeCallback: (index) {
              setState(() => _currentPage = index);
            },
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: _currentPage == index ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? indicatorColor[_currentPage]
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(255, 1, 27, 37), 
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.all(40), 
              child:
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40),
                  Text(
                    'Assess Fish Freshness non-invasively using',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0XFF1ABEF7),
                    ),
                    textAlign: TextAlign.left,
                  ),
                  Text(
                    'AI-powered',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0XFF40E0D0),
                    ),
                    textAlign: TextAlign.left,
                  ),
                  Text(
                    'Bio-Capacitance',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0XFF8CFFF4),
                    ),
                    textAlign: TextAlign.left,
                  ),
                  Text(
                    'Sensing',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0XFFFFFFFF),
                    ),
                    textAlign: TextAlign.left,
                  )
                ],
              ),  
            ),
            const SizedBox(height: 10),
            Image.asset(
              'assets/images/onboardingpage/fish_anim.gif',
              width: 300,
              height: 300,
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen2 extends StatelessWidget {
  const OnboardingScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(255, 116, 246, 202),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.all(40), 
              child:
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40),
                  Text(
                    'Assess Fish Freshness non-invasively using',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0XFF000000),
                    ),
                    textAlign: TextAlign.left,
                  ),
                  Text(
                    'AI-powered',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0XFF034C65),
                    ),
                    textAlign: TextAlign.left,
                  ),
                  Text(
                    'Bio-Capacitance',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0XFF08809B),
                    ),
                    textAlign: TextAlign.left,
                  ),
                  Text(
                    'Sensing',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0XFF077F8E),
                    ),
                    textAlign: TextAlign.left,
                  )
                ],
              ),  
            ),
            const SizedBox(height: 10),
            Image.asset(
              'assets/images/onboardingpage/device_animation.gif',
              width: 500,
              height: 500,
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen3 extends StatelessWidget {
  const OnboardingScreen3({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(255, 116, 246, 202), // Page 2 background
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                '',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  color: Color(0XFF02032D),
                  fontSize: 26,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/summary');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0XFF02032D),
                foregroundColor: const Color(0XFF56DFB1),
                minimumSize: const Size(296, 58),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
