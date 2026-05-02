import 'package:flutter/material.dart';

import '../models/user.dart';
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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              '${currentTab.label} · ${widget.subtitle}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: widget.actions,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: currentTab.child,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: child,
      ),
    );
  }
}
