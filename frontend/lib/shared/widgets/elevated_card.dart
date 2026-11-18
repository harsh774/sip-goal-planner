import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Rounded, raised surface for cards. When [onTap] is set it lifts and its
/// border warms to gold on hover.
class ElevatedCard extends StatefulWidget {
  const ElevatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const .all(24),
    this.highlight = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// A gold-tinted surface for headline cards.
  final bool highlight;

  @override
  State<ElevatedCard> createState() => _ElevatedCardState();
}

class _ElevatedCardState extends State<ElevatedCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lifted = _hover && widget.onTap != null;
    final radius = BorderRadius.circular(16);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: .topLeft,
            end: .bottomRight,
            colors: widget.highlight
                ? const [AppColors.goldTint, AppColors.layer]
                : const [AppColors.layer2, AppColors.layer],
          ),
          border: Border.all(
            color: lifted || widget.highlight
                ? AppColors.gold.withValues(alpha: lifted ? 0.7 : 0.35)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: lifted ? 28 : 16,
              offset: Offset(0, lifted ? 12 : 6),
            ),
            if (lifted) BoxShadow(color: AppColors.gold.withValues(alpha: 0.12), blurRadius: 24),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            type: .transparency,
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
