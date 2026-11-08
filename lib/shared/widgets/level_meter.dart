import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LevelMeter extends StatelessWidget {
  const LevelMeter({
    super.key,
    required this.amplitude,
    required this.samples,
    required this.isActive,
  });

  final double amplitude;
  final List<double> samples;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.recording
        : Theme.of(context).colorScheme.outline;
    return Semantics(
      label: isActive
          ? 'Microphone level meter, ${(amplitude * 100).round()} percent'
          : 'Microphone level meter inactive',
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
        ),
        child: CustomPaint(
          painter: _LevelMeterPainter(
            color: color,
            samples: samples,
            amplitude: amplitude,
            isActive: isActive,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LevelMeterPainter extends CustomPainter {
  const _LevelMeterPainter({
    required this.color,
    required this.samples,
    required this.amplitude,
    required this.isActive,
  });

  final Color color;
  final List<double> samples;
  final double amplitude;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    const barCount = 32;
    final gap = 4.0;
    final barWidth = math.max(
      2.0,
      (size.width - gap * (barCount - 1)) / barCount,
    );
    final centerY = size.height / 2;

    for (var index = 0; index < barCount; index++) {
      final progress = barCount == 1 ? 1.0 : index / (barCount - 1);
      final sampleIndex = samples.isEmpty
          ? -1
          : (samples.length * progress).floor().clamp(0, samples.length - 1);
      final raw = sampleIndex < 0 ? amplitude : samples[sampleIndex];
      final height = isActive
          ? math.max(5.0, size.height * (0.18 + raw.clamp(0.0, 1.0) * 0.82))
          : 5.0;
      paint
        ..color = color.withValues(
          alpha: isActive ? 0.28 + progress * 0.72 : 0.2,
        )
        ..strokeWidth = barWidth;
      canvas.drawLine(
        Offset(index * (barWidth + gap) + barWidth / 2, centerY - height / 2),
        Offset(index * (barWidth + gap) + barWidth / 2, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LevelMeterPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.isActive != isActive ||
        oldDelegate.samples != samples;
  }
}
