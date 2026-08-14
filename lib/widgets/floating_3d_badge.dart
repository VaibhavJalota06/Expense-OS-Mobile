import 'dart:math' as math;
import 'package:flutter/material.dart';

class Floating3DBadge extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? glowColor;
  final Color? iconColor;
  final double floatOffset;
  final Duration duration;

  const Floating3DBadge({
    super.key,
    required this.icon,
    this.size = 64,
    this.iconSize = 28,
    this.glowColor,
    this.iconColor,
    this.floatOffset = 10.0,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<Floating3DBadge> createState() => _Floating3DBadgeState();
}

class _Floating3DBadgeState extends State<Floating3DBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ?? Colors.white;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final floatVal = math.sin(_animation.value * math.pi) * widget.floatOffset;
        final tiltAngle = math.sin(_animation.value * math.pi) * 0.08;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..translate(0.0, -floatVal)
            ..rotateX(tiltAngle)
            ..rotateZ(tiltAngle * 0.5),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFF16221D),
          borderRadius: BorderRadius.circular(widget.size * 0.32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF202E27),
              Color(0xFF121B17),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
