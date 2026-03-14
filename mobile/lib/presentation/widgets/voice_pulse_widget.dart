import 'package:flutter/material.dart';
import 'dart:math' as math;

class VoicePulseWidget extends StatefulWidget {
  const VoicePulseWidget({super.key});

  @override
  State<VoicePulseWidget> createState() => _VoicePulseWidgetState();
}

class _VoicePulseWidgetState extends State<VoicePulseWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(); // Make animation run continuously
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            // Simple logic to create bar height variation
            double value = math.sin((_controller.value * 2 * math.pi) + (index * 0.5));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 40 + (value * 30), // Bar will go up and down between 10-70
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
            );
          }),
        );
      },
    );
  }
}