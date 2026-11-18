import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/elevated_card.dart';
import '../../domain/entities/goal_type.dart';
import 'goal_type_icon.dart';

const _youHaventAddedAnyText = 'You haven’t added any goals yet';
const _createYourFirstGoalText = 'Create your first goal';
const _orStartFromText = 'Or start from:';
const _noGoalsMatchTheseText = 'No goals match these filters.';
const _tryOtherFiltersText = 'Try another goal type, currency or timeline.';
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

/// Empty filtered list. Clearing is done from the filter bar's own button.
class NoMatchingGoals extends StatelessWidget {
  const NoMatchingGoals({super.key});

  @override
  Widget build(BuildContext context) {
    return const ElevatedCard(
      child: Row(
        children: [
          Icon(Icons.filter_alt_off_outlined, color: AppColors.gold),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(_noGoalsMatchTheseText, style: TextStyle(fontWeight: .w600)),
                Text(_tryOtherFiltersText, style: TextStyle(color: AppColors.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
