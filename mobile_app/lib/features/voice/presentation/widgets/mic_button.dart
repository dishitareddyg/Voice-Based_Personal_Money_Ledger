import 'dart:math' as math;

import 'package:flutter/material.dart';

class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.listening,
    required this.onTap,
    this.soundLevel = 0,
    this.enabled = true,
    this.size = 118,
  });

  final bool listening;
  final VoidCallback onTap;
  final double soundLevel;
  final bool enabled;
  final double size;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.listening) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.listening && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = widget.soundLevel.clamp(0.0, 8.0) / 8.0;

    return SizedBox(
      width: widget.size + 56,
      height: widget.size + 56,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.listening) ...[
                for (var i = 0; i < 3; i++)
                  _ring(
                    progress: (_controller.value + i / 3) % 1,
                    color: scheme.primary,
                    baseSize: widget.size,
                  ),
              ],
              Transform.scale(
                scale: widget.listening ? 1 + level * 0.08 : 1,
                child: child,
              ),
            ],
          );
        },
        child: Semantics(
          button: true,
          label: widget.listening ? 'Stop listening' : 'Start voice input',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.enabled ? widget.onTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.listening
                        ? [scheme.tertiary, scheme.primary]
                        : [scheme.primary, scheme.primary.withValues(alpha: .82)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary
                          .withValues(alpha: widget.listening ? .45 : .28),
                      blurRadius: widget.listening ? 34 : 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: scheme.onPrimary,
                  size: widget.size * 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring({
    required double progress,
    required Color color,
    required double baseSize,
  }) {
    final size = baseSize + progress * 56;
    return Opacity(
      opacity: (1 - progress) * .35,
      child: Container(
        width: size,
        height: math.max(size, 1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
      ),
    );
  }
}
