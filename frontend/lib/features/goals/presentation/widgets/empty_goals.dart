import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/goal_type.dart';
import 'goal_type_icon.dart';

const _youHaventAddedAnyText = 'You haven’t added any goals yet';
const _createYourFirstGoalText = 'Create your first goal';
const _orStartFromText = 'Or start from:';
const _noGoalsMatchTheseText = 'No goals match these filters.';
const _clearFiltersText = 'Clear filters';
const _addSomethingYouReText =
    'Add something you’re saving for — like a home, a car or retirement. We’ll work out how much to invest each month to get there.';

class EmptyGoals extends StatelessWidget {
  const EmptyGoals({super.key, required this.onCreate});

  /// Called with the route to open: a blank form or one started from a template.
  final ValueChanged<String> onCreate;

  static const _templates = [
    GoalType.home,
    GoalType.education,
    GoalType.retirement,
    GoalType.emergencyFund,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.layer,
      padding: const .all(32),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.gold, size: 40),
          const SizedBox(height: 16),
          const Text(_youHaventAddedAnyText, style: TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          const Text(_addSomethingYouReText, style: TextStyle(color: AppColors.text2, height: 1.4)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => onCreate(Routes.newGoal),
            child: const Text(_createYourFirstGoalText),
          ),
          const SizedBox(height: 24),
          const Text(_orStartFromText, style: TextStyle(color: AppColors.text2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _templates)
                ActionChip(
                  avatar: Icon(t.icon, size: 16, color: AppColors.gold),
                  label: Text(t.label),
                  onPressed: () => onCreate('${Routes.newGoal}?type=${t.code}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class NoMatchingGoals extends StatelessWidget {
  const NoMatchingGoals({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.layer,
      padding: const .all(24),
      child: Row(
        children: [
          const Expanded(
            child: Text(_noGoalsMatchTheseText, style: TextStyle(color: AppColors.text2)),
          ),
          TextButton(onPressed: onClear, child: const Text(_clearFiltersText)),
        ],
      ),
    );
  }
}
