import 'package:flutter/material.dart';

class FreshnessMeter extends StatelessWidget {
  final int level; // 0, 1, 2

  const FreshnessMeter({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final safeLevel = level.clamp(0, 2);

    final totalWidth = MediaQuery.of(context).size.width - 48; 

    final segmentWidth = totalWidth / 3;
    final indicatorSize = 28.0;

    return SizedBox(
      width: totalWidth,
      height: 47,
      child: Stack(
        children: [

          // Segments
          Row(
            children: [
              _segment(const Color(0xFF8AD4D1)),
              _segment(const Color(0xFF2CB1B8)),
              _segment(const Color(0xFF083C5A)),
            ],
          ),

          /// Indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            left: (segmentWidth * safeLevel) +
                (segmentWidth / 2) -
                (indicatorSize / 2),
            top: (20 - indicatorSize) / 2,
            child: Container(
              width: indicatorSize,
              height: indicatorSize,
              decoration: const BoxDecoration(
                border: Border( 
                  top: BorderSide(color: Colors.white, width: 3),
                  left: BorderSide(color: Colors.white, width: 3),
                  right: BorderSide(color: Colors.white, width: 3),
                  bottom: BorderSide(color: Colors.white, width: 3),
                ),
                color: Color(0xFF2CB1B8),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(Color color) {
    return Expanded(
      child: Container(
        height: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(0),
        ),
      ),
    );
  }
}