import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

abstract final class Compliance {
  static const marketRisk = 'Mutual fund investments are subject to market risks.';
  static const illustrative = 'Returns shown are illustrative assumptions, not guarantees.';
  static const notAdvice = 'This is not investment advice.';
}

class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key, this.extended = false});

  /// Results pages add the assumptions and "not advice" lines.
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final text = extended
        ? '${Compliance.illustrative} They assume the same return every year; real returns go '
              'up and down. ${Compliance.marketRisk} ${Compliance.notAdvice}'
        : Compliance.marketRisk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.5),
      ),
    );
  }
}
