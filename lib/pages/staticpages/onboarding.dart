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
    // Get screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Scale font sizes based on screen width (you can tweak multipliers)
    final logoWidth = screenWidth * 0.75;      // 50% of screen width
    final titleFontSize = screenWidth * 0.18; // scales with width
    final subtitleFontSize = screenWidth * 0.057; 

    return Scaffold(
      body: Container(
        color: const Color(0XFF00EAD3),
        width: screenWidth,
        height: screenHeight,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: screenHeight * 0.09), // 2% spacing
                Image.asset(
                  'assets/images/onboardingpage/presko_logo_circular.png',
                  width: logoWidth,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: screenHeight * 0.09),
                Text(
                  'PRESSKO',
                  style: TextStyle(
                    fontFamily: 'Rebrand',
                    fontWeight: FontWeight.w800,
                    fontSize: titleFontSize,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  'Where Bio-Sensing\nMeets Intelligence',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: subtitleFontSize,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen2 extends StatelessWidget {
  const OnboardingScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final logoWidth = screenWidth * 0.22;
    final descriptionFontSize = screenWidth * 0.071;
    final fishWidth = screenWidth * 0.87;
    final bottomContainerHeight = screenHeight * 0.50;
    final topVerticalPadding = screenHeight * 0.09;
    final horizontalPadding = screenWidth * 0.06;

    return Container(
      color: const Color(0XFF00EAD3),
      child: Stack(
        children: [

          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: topVerticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      "assets/images/onboardingpage/presko_logo_dark.png",
                      width: logoWidth,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.057),
                  Text(
                    "Transforming fish\nfreshness assessment\nthrough bio-capacitance\nanalysis.",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: descriptionFontSize,
                      color: const Color(0XFF012532),
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
                height: bottomContainerHeight,
                color: const Color(0XFF012532),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.04),
                    child: Image.asset(
                      "assets/images/onboardingpage/fish_anim.gif",
                      width: fishWidth,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final logoWidth = screenWidth * 0.22;
    final deviceGifWidth = screenWidth * 0.88;
    final descriptionFontSize = screenWidth * 0.068;
    final buttonWidth = screenWidth * 0.75;
    final buttonHeight = screenHeight * 0.072;
    final buttonFontSize = screenWidth * 0.055;
    final bottomContainerHeight = screenHeight * 0.52;
    final topVerticalPadding = screenHeight * 0.07;
    final horizontalPadding = screenWidth * 0.06;

    return Container(
      color: const Color(0XFF012532),
      child: Stack(
        children: [

          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: topVerticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      "assets/images/onboardingpage/presko_logo_light.png",
                      width: logoWidth,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Center(
                    child: Image.asset(
                      "assets/images/onboardingpage/device_animation.gif",
                      width: deviceGifWidth,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
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
                height: bottomContainerHeight,
                color: const Color(0XFF00EAD3),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: screenHeight * 0.04),
                        child: Text(
                          "Designed to capture\nnatural surface\nsignals safely and\naccurately.",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: descriptionFontSize,
                            color: const Color(0XFF012532),
                            height: 1.3,
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/homepage');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0XFF012532),
                          foregroundColor: const Color(0XFF56DFB1),
                          minimumSize: Size(buttonWidth, buttonHeight),
                        ),
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: buttonFontSize,
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