import 'package:flutter/material.dart';

class AnimatedCheck extends StatefulWidget {
  final bool isDone;

  const AnimatedCheck({super.key, required this.isDone});

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with TickerProviderStateMixin {

  late AnimationController _rotationController;
  late AnimationController _checkController;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDone) {
      _rotationController.stop();
      _checkController.forward();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        border: Border( 
            top: BorderSide(color: Colors.white, width: 3),
            left: BorderSide(color: Colors.white, width: 3),
            right: BorderSide(color: Colors.white, width: 3),
            bottom: BorderSide(color: Colors.white, width: 3),
        ),
        shape: BoxShape.circle,
        color: Color(0xFF1DB6A4),
      ),
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [

              /// Rotating loader
              if (!widget.isDone)
                Transform.rotate(
                  angle: _rotationController.value * 6.28,
                  child: const Icon(
                    Icons.sync,
                    color: Colors.white,
                    size: 20,
                  ),
                ),

              /// Checkmark fade in
              FadeTransition(
                opacity: _checkController,
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}