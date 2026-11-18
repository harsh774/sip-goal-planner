import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/error/failure.dart';

const _stillWorkingText = 'Still working.';
const _yourConnectionSeemsSlowText =
    'Your connection seems slow — this can take a few more seconds. No need to refresh.';
const _tryAgainText = 'Try again';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, required this.label, this.isSlow = false, this.skeleton});

  final String label;
  final bool isSlow;

  /// Placeholder shaped like the content being loaded.
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (isSlow) const SlowConnectionNotice(),
        if (isSlow) const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          label: label,
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: AppColors.text2)),
            ],
          ),
        ),
        if (skeleton != null) ...[const SizedBox(height: 24), skeleton!],
      ],
    );
  }
}

class SlowConnectionNotice extends StatelessWidget {
  const SlowConnectionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const NoticeBanner(
      icon: Icons.wifi_tethering_error,
      color: AppColors.gold,
      background: AppColors.goldTint,
      title: _stillWorkingText,
      body: _yourConnectionSeemsSlowText,
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.failure,
    required this.onRetry,
    this.hint,
  });

  final String title;
  final Failure failure;
  final VoidCallback onRetry;

  /// Reassurance shown under the error, e.g. "Your goal is saved."
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        NoticeBanner(
          icon: Icons.error_outline,
          color: AppColors.danger,
          background: AppColors.dangerBg,
          title: title,
          body: [failure.message, ?hint].join(' '),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text(_tryAgainText),
        ),
      ],
    );
  }
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: background,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title ',
                    style: const TextStyle(fontWeight: .w600),
                  ),
                  TextSpan(text: body),
                ],
              ),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) =>
      Container(height: height, color: AppColors.layer, margin: const .only(bottom: 16));
}
