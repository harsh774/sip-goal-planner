import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Primary call to action: rounded, raised, gold gradient with a light
/// sweeping across it every few seconds.
class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool loading;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> with SingleTickerProviderStateMixin {
  late final _shine = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat();
  bool _hover = false;

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final radius = BorderRadius.circular(AppRadius.button);
    final label = DefaultTextStyle.merge(
      style: const TextStyle(color: AppColors.onGold, fontSize: 15, fontWeight: .w600),
      child: IconTheme.merge(
        data: const IconThemeData(color: AppColors.onGold, size: 20),
        child: widget.loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onGold),
              )
            : Row(
                mainAxisSize: .min,
                children: [
                  if (widget.icon != null) ...[Icon(widget.icon), const SizedBox(width: 8)],
                  widget.child,
                ],
              ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
          transform: Matrix4.translationValues(0, _hover && enabled ? -1 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFB8901F), AppColors.goldHover, Color(0xFFC9A132)],
                    begin: .topLeft,
                    end: .bottomRight,
                  )
                : null,
            color: enabled ? null : AppColors.border,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: _hover ? 0.45 : 0.3),
                      blurRadius: _hover ? 18 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Material(
              type: .transparency,
              child: InkWell(
                onTap: enabled ? widget.onPressed : null,
                child: Stack(
                  alignment: .center,
                  children: [
                    if (enabled)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _shine,
                          builder: (context, _) => CustomPaint(painter: _Shine(_shine.value)),
                        ),
                      ),
                    Padding(padding: const .symmetric(horizontal: 24, vertical: 14), child: label),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Shine extends CustomPainter {
  _Shine(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Sweep for the first 40% of each cycle, then rest.
    final progress = (t / 0.4).clamp(0.0, 1.0);
    if (progress >= 1) return;
    final width = size.height * 1.2;
    final x = -width + (size.width + width * 2) * progress;
    final rect = Rect.fromLTWH(x - width / 2, 0, width, size.height);
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.skew(-0.4, 0);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Shine old) => old.t != t;
}
