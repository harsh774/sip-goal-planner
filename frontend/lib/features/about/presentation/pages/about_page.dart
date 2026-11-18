import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/domain/currency.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/sip_insights.dart';
import '../widgets/about_goal_planner.dart';

const _backText = 'Back';

/// What GoalPlanner is and why a SIP plan matters. Open to everyone.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.select((AuthBloc b) => b.state.user?.defaultCurrency) ?? Currency.inr;
    return AppShell(
      showAboutLink: false,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Align(
            alignment: .centerLeft,
            child: TextButton.icon(
              onPressed: () => context.canPop() ? context.pop() : context.go(Routes.goals),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text(_backText),
            ),
          ),
          const SizedBox(height: 8),
          const AboutGoalPlanner(),
          const SizedBox(height: 40),
          SipImpactSection(currency: currency),
        ],
      ),
    );
  }
}
