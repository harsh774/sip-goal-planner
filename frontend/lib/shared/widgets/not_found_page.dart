import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_theme.dart';
import 'app_shell.dart';
import 'gold_button.dart';

const _fourOhFourText = '404';
const _pageNotFoundText = 'Page not found';
const _weCouldntFindText = 'We couldn’t find';
const _goToMyGoalsText = 'Go to My goals';

/// Shown for any URL the router doesn't know.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Padding(
        padding: const .symmetric(vertical: 48),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFFB8901F), AppColors.goldHover],
              ).createShader(rect),
              child: const Text(
                _fourOhFourText,
                style: TextStyle(fontSize: 120, fontWeight: .w700, color: Colors.white, height: 1),
              ),
            ),
            const SizedBox(height: 16),
            const Text(_pageNotFoundText, style: TextStyle(fontSize: 28, fontWeight: .w600)),
            const SizedBox(height: 8),
            Text(
              '$_weCouldntFindText “$location”.',
              textAlign: .center,
              style: const TextStyle(color: AppColors.text2),
            ),
            const SizedBox(height: 28),
            GoldButton(
              onPressed: () => context.go(Routes.goals),
              icon: Icons.home_outlined,
              child: const Text(_goToMyGoalsText),
            ),
          ],
        ),
      ),
    );
  }
}
