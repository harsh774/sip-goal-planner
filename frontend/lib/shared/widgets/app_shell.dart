import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/domain/currency.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import 'app_footer.dart';

const _goalText = 'Goal';
const _plannerText = 'Planner';
const _profileAndPasswordText = 'Profile and password';
const _logOutText = 'Log out';
const _accountMenuText = 'Account menu';

/// Page frame from the design: black header with the account menu, centred
/// content up to 1120 px, and the footer pinned to the bottom of short pages.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, this.extendedDisclaimer = false, this.bottomBar});

  final Widget child;
  final bool extendedDisclaimer;

  /// Pinned under the scrolling content, e.g. the plan preview on phones.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _Header(),
      bottomNavigationBar: bottomBar,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < Breakpoints.compact;
          return FooterScrollView(
            padding: .fromLTRB(16, compact ? 24 : 40, 16, 32),
            extendedDisclaimer: extendedDisclaimer,
            child: child,
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header();

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.header,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const .only(left: 16),
      child: const Row(children: [AppLogo(), Spacer(), _AccountMenu()]),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        text: _goalText,
        children: [
          TextSpan(
            text: _plannerText,
            style: TextStyle(fontWeight: .w600, color: AppColors.gold),
          ),
        ],
      ),
      style: TextStyle(fontSize: 14, color: AppColors.text),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    if (user == null) return const SizedBox.shrink();

    return MenuAnchor(
      alignmentOffset: const Offset(-180, 0),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.layer),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      ),
      menuChildren: [
        Padding(
          padding: const .fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(user.fullName, style: const TextStyle(fontWeight: .w600)),
              Text(user.email, style: const TextStyle(color: AppColors.text2, fontSize: 12)),
            ],
          ),
        ),
        const Divider(height: 1),
        SubmenuButton(
          leadingIcon: const Icon(Icons.payments_outlined, size: 18),
          menuChildren: [
            for (final c in Currency.values)
              MenuItemButton(
                trailingIcon: c == user.defaultCurrency ? const Icon(Icons.check, size: 16) : null,
                onPressed: () => context.read<AuthBloc>().add(AuthDefaultCurrencyChanged(c)),
                child: Text('${c.symbol.trim()} ${c.code}'),
              ),
          ],
          child: Text('Default currency for new goals: ${user.defaultCurrency.code}'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.person_outline, size: 18),
          onPressed: () => context.push(Routes.profile),
          child: const Text(_profileAndPasswordText),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout, size: 18),
          onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
          child: const Text(_logOutText),
        ),
      ],
      builder: (context, controller, _) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Semantics(
          button: true,
          label: _accountMenuText,
          child: Container(
            height: 48,
            padding: const .symmetric(horizontal: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.goldTint,
                  child: Text(
                    user.initials,
                    style: const TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: .w600),
                  ),
                ),
                const SizedBox(width: 8),
                LayoutBuilder(
                  builder: (context, _) => MediaQuery.sizeOf(context).width < Breakpoints.compact
                      ? const SizedBox.shrink()
                      : Text(user.firstName, style: const TextStyle(fontSize: 14)),
                ),
                const Icon(Icons.expand_more, size: 18, color: AppColors.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
