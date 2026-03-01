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

  final pages = [OnboardingScreen1(), OnboardingScreen2(), OnboardingScreen3()];

  final List<Color> indicatorColor = [
    Color(0XFF012532),
    Color(0XFF56DFB1),
    Color(0XFF012532)
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
      color: Color(0XFF00EAD3), 
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Image.asset(
              'assets/images/onboardingpage/presko_logo_circular.png',
              width: 338,
              height: 338,
            ),
            const SizedBox(height: 10),
            const Text(
              'PRESKO', 
              style: TextStyle(
                fontFamily: 'Rebrand',
                fontWeight: FontWeight.w800,
                fontSize: 75,
                color: Colors.white
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Where Bio-Sensing\nMeets Intelligence', 
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: Colors.black
              ),
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
      color: const Color(0XFF00EAD3), 
      child: Stack(
        children: [

          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      "assets/images/onboardingpage/presko_logo_dark.png",
                      width: 90,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    "Transforming fish\nfreshness assessment\nthrough bio-capacitance\nanalysis.",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: Color(0XFF012532),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                color: const Color(0XFF012532),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Image.asset(
                      "assets/images/onboardingpage/fish_anim.gif",
                      width: 280,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
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

class OnboardingScreen3 extends StatelessWidget {
  const OnboardingScreen3({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0XFF012532), 
      child: Stack(
        children: [

          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      "assets/images/onboardingpage/presko_logo_light.png",
                      width: 90,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Image.asset(
                    "assets/images/onboardingpage/device_animation.gif",
                    width: 350,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  )
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                color: const Color(0XFF00EAD3),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: const Text(
                          "Designed to capture\nnatural surface\nsignals safely and\naccurately.",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                            color: Color(0XFF012532),
                            height: 1.3,
                          ),  
                        ),
                      ),
                      const SizedBox(height: 80),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/homepage');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0XFF012532),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, 60); 
    path.quadraticBezierTo(
      size.width * 0.25, 0, 
      size.width * 0.5, 60,
    );
    path.quadraticBezierTo(
      size.width * 0.75, 120,
      size.width, 60,
    );
    path.lineTo(size.width, size.height); 
    path.lineTo(0, size.height); 
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}