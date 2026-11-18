import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'elevated_card.dart';

const _tips = [
  'Starting 5 years earlier can nearly double what you end up with.',
  'A yearly step-up lets you start smaller and still reach the goal.',
  'Inflation quietly shrinks money; every plan shows today’s value too.',
  'Returns earn returns: that’s compounding at work.',
  'Small, regular amounts beat waiting for a big one.',
];

/// Slowly drifting columns of money glyphs, faint gold, fading at the edges.
class MoneyMatrix extends StatefulWidget {
  const MoneyMatrix({super.key});

  @override
  State<MoneyMatrix> createState() => _MoneyMatrixState();
}

class _MoneyMatrixState extends State<MoneyMatrix> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 24))
    ..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: ShaderMask(
        shaderCallback: (rect) => const RadialGradient(
          radius: 0.9,
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
        blendMode: .dstIn,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (_, _) => CustomPaint(painter: _MatrixPainter(_clock.value), size: .infinite),
        ),
      ),
    ),
  );
}

class _MatrixPainter extends CustomPainter {
  _MatrixPainter(this.t);

  final double t;
  static const _glyphs = ['₹', '\$', '€', '%', '↑', '0', '1', '2', '5', '7', '9', '+'];
  static const _cell = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / _cell).ceil();
    final rows = (size.height / _cell).ceil() + 2;
    for (var c = 0; c < cols; c++) {
      final rnd = math.Random(c * 7919);
      final speed = 0.5 + rnd.nextDouble();
      final shift = (t * speed * rows + rnd.nextDouble() * rows) % rows;
      for (var r = 0; r < rows; r++) {
        final y = ((r - shift) % rows) * _cell - _cell;
        final glyph = _glyphs[(c * 31 + r * 17) % _glyphs.length];
        final glow = (math.sin((t * 2 * math.pi * speed) + r * 0.6 + c) + 1) / 2;
        final painter = TextPainter(
          text: TextSpan(
            text: glyph,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.gold.withValues(alpha: 0.05 + glow * 0.18),
            ),
          ),
          textDirection: .ltr,
        )..layout();
        painter.paint(canvas, Offset(c * _cell + 6, y));
      }
    }
  }

  @override
  bool shouldRepaint(_MatrixPainter old) => old.t != t;
}

/// A light band sweeping across its child, for placeholders.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _sweep,
    builder: (_, child) => ShaderMask(
      blendMode: .srcATop,
      shaderCallback: (rect) {
        final x = -1.5 + 3.5 * _sweep.value;
        return LinearGradient(
          begin: Alignment(x - 0.6, -0.3),
          end: Alignment(x + 0.6, 0.3),
          colors: const [AppColors.layer2, Color(0xFF3A3523), AppColors.layer2],
        ).createShader(rect);
      },
      child: child,
    ),
    child: widget.child,
  );
}

/// A rounded placeholder block.
class Bone extends StatelessWidget {
  const Bone({super.key, this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: AppColors.layer2, borderRadius: .circular(radius)),
  );
}

/// Placeholder in the exact shape of a goal card.
class GoalCardSkeleton extends StatelessWidget {
  const GoalCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const ElevatedCard(
    child: Shimmer(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Bone(width: 40, height: 40, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Bone(width: 140, height: 16),
                    SizedBox(height: 8),
                    Bone(width: 100, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Bone(width: 90, height: 10),
          SizedBox(height: 8),
          Bone(width: 150, height: 28),
          SizedBox(height: 16),
          Bone(height: 6, radius: 4),
          SizedBox(height: 10),
          Row(children: [Bone(width: 60, height: 10), Spacer(), Bone(width: 80, height: 10)]),
        ],
      ),
    ),
  );
}

/// Placeholder for a wide card such as a summary or chart.
class PanelSkeleton extends StatelessWidget {
  const PanelSkeleton({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) => ElevatedCard(
    child: Shimmer(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Bone(width: 160, height: 14),
          const SizedBox(height: 16),
          Bone(height: height - 54),
        ],
      ),
    ),
  );
}

/// One planning tip at a time, cross-fading every few seconds while data loads.
class RotatingTip extends StatefulWidget {
  const RotatingTip({super.key});

  @override
  State<RotatingTip> createState() => _RotatingTipState();
}

class _RotatingTipState extends State<RotatingTip> {
  int _index = DateTime.now().second % _tips.length;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 2600),
      (_) => setState(() => _index = (_index + 1) % _tips.length),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 400),
    child: Row(
      key: ValueKey(_index),
      children: [
        const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_tips[_index], style: const TextStyle(color: AppColors.text2, fontSize: 13)),
        ),
      ],
    ),
  );
}
