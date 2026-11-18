import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

const _mutualFundInvestmentsAreText = 'Mutual fund investments are subject to market risks.';
const _returnsShownAreIllustrativeText =
    'Returns shown are illustrative assumptions, not guarantees.';
const _thisIsNotInvestmentText = 'This is not investment advice.';

abstract final class Compliance {
  static const marketRisk = _mutualFundInvestmentsAreText;
  static const illustrative = _returnsShownAreIllustrativeText;
  static const notAdvice = _thisIsNotInvestmentText;
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
      padding: const .symmetric(vertical: 16),
      child: Text(
        text,
        textAlign: .center,
        style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.5),
      ),
    );
  }
}
