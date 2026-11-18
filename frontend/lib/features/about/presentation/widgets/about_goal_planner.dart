import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

const _aboutGoalText = 'About Goal';
const _plannerText = 'Planner';
const _setAGoalText = 'Set a goal';
const _nameItChooseAText = 'Name it, choose a target amount, a date and a currency.';
const _seeTheMonthlySipText = 'See the monthly SIP';
const _weWorkOutWhatText = 'We work out what to invest each month, flat or rising every year.';
const _understandThePlanText = 'Understand the plan';
const _yearByYearGrowthText =
    'Year-by-year growth, the effect of inflation, and every step of the maths.';
const _goalplannerTurnsTheThingsText =
    'GoalPlanner turns the things you’re saving for into a clear monthly SIP. Each goal keeps its own currency and assumptions, so you can plan a home in India and a degree abroad side by side. It is a planning tool, not investment advice: returns are assumptions, and real markets go up and down.';

class AboutGoalPlanner extends StatelessWidget {
  const AboutGoalPlanner({super.key});

  static const _points = [
    (Icons.flag_outlined, _setAGoalText, _nameItChooseAText),
    (Icons.calculate_outlined, _seeTheMonthlySipText, _weWorkOutWhatText),
    (Icons.insights_outlined, _understandThePlanText, _yearByYearGrowthText),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.layer,
        borderRadius: .circular(12),
        border: .all(color: AppColors.border),
      ),
      padding: const .all(24),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text.rich(
            TextSpan(
              text: _aboutGoalText,
              children: [
                TextSpan(
                  text: _plannerText,
                  style: TextStyle(color: AppColors.gold),
                ),
              ],
            ),
            style: TextStyle(fontSize: 22, fontWeight: .w600),
          ),
          const SizedBox(height: 8),
          const Text(
            _goalplannerTurnsTheThingsText,
            style: TextStyle(color: AppColors.text2, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              for (final (icon, title, body) in _points)
                SizedBox(
                  width: 300,
                  child: Row(
                    crossAxisAlignment: .start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.goldTint,
                        child: Icon(icon, size: 18, color: AppColors.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: .w600)),
                            Text(body, style: const TextStyle(color: AppColors.text2, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
