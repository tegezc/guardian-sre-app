import 'package:flutter/material.dart';

class GuardianOrb extends StatefulWidget {
  final String state; // Allowed values: 'idle', 'listening', 'speaking'

  const GuardianOrb({Key? key, required this.state}) : super(key: key);

  @override
  State<GuardianOrb> createState() => _GuardianOrbState();
}

class _GuardianOrbState extends State<GuardianOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Setup animation driver
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Setup enlarge-shrink effect (scale 1.0 to 1.3)
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(GuardianOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing heartbeat speed based on AI status
    if (widget.state == 'idle') {
      _controller.stop();
      _controller.value = 0.0; // Reset to normal size
    } else if (widget.state == 'speaking') {
      _controller.duration = const Duration(milliseconds: 400); // Fast beat when speaking
      _controller.repeat(reverse: true);
    } else {
      _controller.duration = const Duration(seconds: 1); // Relaxed beat when listening
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determining aura (Glow) color based on status
    Color glowColor;
    if (widget.state == 'listening') {
      glowColor = Colors.cyanAccent;
    } else if (widget.state == 'speaking') {
      glowColor = Colors.purpleAccent;
    } else {
      glowColor = Colors.grey.withOpacity(0.3);
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.state == 'idle' ? 1.0 : _pulseAnimation.value,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E1E),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(0.6),
                  blurRadius: widget.state == 'idle' ? 10 : 40 * _pulseAnimation.value,
                  spreadRadius: widget.state == 'idle' ? 2 : 15 * _pulseAnimation.value,
                ),
                BoxShadow(
                  color: glowColor.withOpacity(0.3),
                  blurRadius: widget.state == 'idle' ? 20 : 80 * _pulseAnimation.value,
                  spreadRadius: widget.state == 'idle' ? 5 : 30 * _pulseAnimation.value,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.state == 'idle' ? Icons.mic_off : Icons.graphic_eq,
                color: widget.state == 'idle' ? Colors.grey : glowColor,
                size: 60,
              ),
            ),
          ),
        );
      },
    );
  }
}