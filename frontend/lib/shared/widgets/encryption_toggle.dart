import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/di/injection.dart';
import '../../core/security/encryption_settings.dart';

const _onTooltipText = 'Encrypted traffic is on. Tap to turn it off.';
const _offTooltipText = 'Encrypted traffic is off. Tap to turn it on.';
const _turnedOnText =
    'Encrypted traffic on: each request and response is sealed with AES-256-GCM; the key is wrapped with the server’s RSA key.';
const _turnedOffText = 'Encrypted traffic off: requests use HTTPS only.';
const _encryptedText = 'Encrypted';

/// Lock button in the nav bar to try payload encryption on and off.
class EncryptionToggle extends StatelessWidget {
  const EncryptionToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = sl<EncryptionSettings>();
    return ValueListenableBuilder<bool>(
      valueListenable: settings,
      builder: (context, on, _) => Tooltip(
        message: on ? _onTooltipText : _offTooltipText,
        child: TextButton.icon(
          onPressed: () async {
            await settings.toggle();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(settings.value ? _turnedOnText : _turnedOffText)),
              );
          },
          style: TextButton.styleFrom(foregroundColor: on ? AppColors.gold : AppColors.text3),
          icon: Icon(on ? Icons.lock : Icons.lock_open, size: 18),
          label: AnimatedSize(
            duration: const Duration(milliseconds: 150),
            child: on
                ? const Text(_encryptedText, style: TextStyle(fontSize: 12))
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
