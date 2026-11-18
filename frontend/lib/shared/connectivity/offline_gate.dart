import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme/app_theme.dart';
import '../widgets/gold_button.dart';
import '../widgets/loading_visuals.dart';
import 'connectivity_cubit.dart';

const _oopsText = 'Oops! No internet';
const _offlineText =
    'Seems like you’re offline. Check your Wi-Fi or mobile data — we’ll pick up right where you left off.';
const _tryAgainText = 'Try again';

/// Covers the app with an offline page while there is no network. The page
/// underneath stays mounted, so nothing typed is lost; it lifts on reconnect.
class OfflineGate extends StatelessWidget {
  const OfflineGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityCubit>().state;
    return Stack(
      children: [
        child,
        if (!online) const Positioned.fill(child: OfflinePage()),
      ],
    );
  }
}

class OfflinePage extends StatelessWidget {
  const OfflinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Stack(
        children: [
          const Positioned.fill(child: MoneyMatrix()),
          Center(
            child: SingleChildScrollView(
              padding: const .all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: .circle,
                        color: AppColors.goldTint,
                        border: .all(color: AppColors.gold.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(color: AppColors.gold.withValues(alpha: 0.25), blurRadius: 40),
                        ],
                      ),
                      child: const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.gold),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      _oopsText,
                      textAlign: .center,
                      style: TextStyle(fontSize: 28, fontWeight: .w600),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      _offlineText,
                      textAlign: .center,
                      style: TextStyle(color: AppColors.text2, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    GoldButton(
                      onPressed: () => context.read<ConnectivityCubit>().check(),
                      icon: Icons.refresh,
                      child: const Text(_tryAgainText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
