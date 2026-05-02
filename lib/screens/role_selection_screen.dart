import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'role_home_shell.dart';
import '../widgets/max_width_container.dart';
import '../widgets/responsive_grid.dart';
import '../utils/responsive_helper.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;
  bool _isLoading = false;

  final List<_RoleOption> _roles = const [
    _RoleOption(
      role: UserRole.citizen,
      title: 'Family / Citizen',
      subtitle: 'Track ambulance & family members',
      icon: Icons.family_restroom,
      color: Color(0xFF3B82F6),
    ),
    _RoleOption(
      role: UserRole.driver,
      title: 'Ambulance Driver',
      subtitle: 'Manage vehicle and respond to calls',
      icon: Icons.local_shipping,
      color: Color(0xFF10B981),
    ),
    _RoleOption(
      role: UserRole.hospitalStaff,
      title: 'Hospital Staff',
      subtitle: 'Monitor incoming patients',
      icon: Icons.local_hospital,
      color: Color(0xFFF59E0B),
    ),
    _RoleOption(
      role: UserRole.dispatcher,
      title: 'Dispatcher',
      subtitle: 'Coordinate emergency responses',
      icon: Icons.headset_mic,
      color: Color(0xFF8B5CF6),
    ),
    _RoleOption(
      role: UserRole.admin,
      title: 'System Admin',
      subtitle: 'Full system access and management',
      icon: Icons.admin_panel_settings,
      color: Color(0xFFEF4444),
    ),
  ];

  Future<void> _confirm() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your role to continue')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success =
        await authProvider.completeGoogleSignIn(role: _selectedRole!);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _navigateToHome(authProvider.currentUser!.role);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(authProvider.errorMessage ?? 'Something went wrong')),
      );
    }
  }

  void _navigateToHome(UserRole role) {
    final home = buildHomeForRole(role);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => home),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: MaxWidthContainer(
            maxWidth: 1000,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Who are you?',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: ResponsiveHelper.value(context,
                          mobile: 32.0, desktop: 40.0),
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your role to set up your account.',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ResponsiveGrid(
                    mobileColumns: 1,
                    tabletColumns: 2,
                    desktopColumns: 3,
                    spacing: 16,
                    childAspectRatio: 1.5,
                    children: _roles.map((option) {
                      final isSelected = _selectedRole == option.role;
                      return _RoleTile(
                        option: option,
                        isSelected: isSelected,
                        onTap: () =>
                            setState(() => _selectedRole = option.role),
                        key: ValueKey(option.role),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: SizedBox(
                      width: ResponsiveHelper.value(context,
                          mobile: double.infinity, desktop: 300.0),
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Continue',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final _RoleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? option.color.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? option.color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon, color: option.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? option.color
                      : Colors.grey.withValues(alpha: 0.4),
                  width: 2,
                ),
                color: isSelected ? option.color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOption {
  final UserRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _RoleOption({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
