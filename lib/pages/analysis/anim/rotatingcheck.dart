import 'package:flutter/material.dart';

class AnimatedCheck extends StatefulWidget {
  final bool isDone;
  final AnimationController? externalSpinCtrl;

  const AnimatedCheck({
    super.key,
    required this.isDone,
    this.externalSpinCtrl,
  });

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with TickerProviderStateMixin {

  late AnimationController _localSpinCtrl;
  late AnimationController _checkController;

  AnimationController get _spinCtrl =>
      widget.externalSpinCtrl ?? _localSpinCtrl;

  @override
  void initState() {
    super.initState();

    _localSpinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Only auto-spin if no external controller is provided
    if (widget.externalSpinCtrl == null && !widget.isDone) {
      _localSpinCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDone && !oldWidget.isDone) {
      // Stop local ctrl if we own it; external ctrl is stopped by parent
      if (widget.externalSpinCtrl == null) {
        _localSpinCtrl.stop();
      }
      _checkController.forward();
    }

    // If isDone flipped back to false (e.g. "New Test" reset), restart local spin
    if (!widget.isDone && oldWidget.isDone) {
      _checkController.reset();
      if (widget.externalSpinCtrl == null) {
        _localSpinCtrl.repeat();
      }
    }
  }

  @override
  void dispose() {
    _localSpinCtrl.dispose();
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
        animation: Listenable.merge([_spinCtrl, _checkController]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [

              /// Rotating loader — hidden once done
              if (!widget.isDone)
                Transform.rotate(
                  angle: _spinCtrl.value * 6.28,
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