import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_theme.dart';
import 'disclaimer.dart';

const _aboutLinkText = 'About GoalPlanner';

/// Bottom of every page: the market-risk disclaimer and the copyright line.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key, this.extendedDisclaimer = false});

  final bool extendedDisclaimer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const Divider(height: 1, color: AppColors.border),
        Disclaimer(extended: extendedDisclaimer),
        Center(
          child: TextButton(
            onPressed: () => context.push(Routes.about),
            child: const Text(_aboutLinkText),
          ),
        ),
        Text(
          '© ${DateTime.now().year} GoalPlanner. All rights reserved.',
          textAlign: .center,
          style: const TextStyle(fontSize: 12, color: AppColors.text3),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Scrolls [child]; when the content is shorter than the screen, the footer
/// sits at the bottom instead of right under the content.
class FooterScrollView extends StatelessWidget {
  const FooterScrollView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.extendedDisclaimer = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool extendedDisclaimer;

  @override
  Widget build(BuildContext context) {
    Widget centred(Widget w) => Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
        child: w,
      ),
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(child: centred(child)),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: .bottomCenter,
            child: Padding(
              padding: .symmetric(horizontal: padding.left),
              child: centred(AppFooter(extendedDisclaimer: extendedDisclaimer)),
            ),
          ),
        ),
      ],
    );
  }
}
