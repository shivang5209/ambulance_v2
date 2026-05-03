import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_colors.dart';
import '../widgets/ops_ui.dart';
import 'admin_role_shell_screen.dart';
import 'driver_role_shell_screen.dart';
import 'family_home_screen.dart';
import 'hospital_home_screen.dart';

Widget buildHomeForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const AdminRoleShellScreen();
    case UserRole.driver:
      return const DriverRoleShellScreen();
    case UserRole.hospitalStaff:
      return const HospitalHomeScreen();
    case UserRole.dispatcher:
      return const FamilyHomeScreen(title: 'Dispatcher');
    case UserRole.citizen:
      return const FamilyHomeScreen();
  }
}

class RoleShellTab {
  final String label;
  final IconData icon;
  final Widget child;

  const RoleShellTab({
    required this.label,
    required this.icon,
    required this.child,
  });
}

class RoleShellScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<RoleShellTab> tabs;
  final List<Widget> actions;

  const RoleShellScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tabs,
    this.actions = const <Widget>[],
  });

  @override
  State<RoleShellScaffold> createState() => _RoleShellScaffoldState();
}

class _RoleShellScaffoldState extends State<RoleShellScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentTab = widget.tabs[_selectedIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: OpsPalette.background(context),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: OpsPalette.pageGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: _OpsShellHeader(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  currentTabLabel: currentTab.label,
                  actions: widget.actions,
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedIndex),
                    child: currentTab.child,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface.withValues(alpha: 0.92)
                        : AppColors.lightSurface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: OpsPalette.border(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _selectedIndex,
                    destinations: [
                      for (final tab in widget.tabs)
                        NavigationDestination(
                          icon: Icon(tab.icon),
                          label: tab.label,
                        ),
                    ],
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpsShellHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String currentTabLabel;
  final List<Widget> actions;

  const _OpsShellHeader({
    required this.title,
    required this.subtitle,
    required this.currentTabLabel,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = OpsPalette.textSecondary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: OpsPalette.border(context)),
      ),
      child: Row(
        children: [
          _HeaderCircleButton(
            icon: Icons.menu_rounded,
            onTap: () {},
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$currentTabLabel · $subtitle',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (actions.isEmpty) ...[
            _HeaderCircleButton(
              icon: Icons.notifications_none_rounded,
              onTap: () {},
              badge: true,
            ),
            const SizedBox(width: 10),
            _HeaderCircleButton(
              icon: Icons.health_and_safety_outlined,
              onTap: () {},
            ),
          ] else
            ...actions,
        ],
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  const _HeaderCircleButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: OpsPalette.elevatedSurface(context),
            foregroundColor: OpsPalette.textPrimary(context),
          ),
          icon: Icon(icon, size: 22),
        ),
        if (badge)
          Positioned(
            top: 6,
            right: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class ShellPage extends StatelessWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OpsSpacing.page,
          10,
          OpsSpacing.page,
          28,
        ),
        child: child,
      ),
    );
  }
}
