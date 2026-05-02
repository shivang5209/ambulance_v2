import 'package:flutter/material.dart';
import '../core/constants/app_theme.dart';
import '../models/user.dart';
import 'login_screen.dart';

class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary,
              AppTheme.primaryVariant,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Header
                Text(
                  'Welcome to',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accident Detection System',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose your role to continue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // User Type Cards
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _UserTypeCard(
                          icon: Icons.directions_car,
                          title: 'Vehicle Driver',
                          subtitle: 'Monitor your vehicle with IoT sensors',
                          color: AppTheme.normalOperation,
                          onTap: () => _navigateToLogin(context, UserRole.driver),
                        ),

                        const SizedBox(height: 20),

                        _UserTypeCard(
                          icon: Icons.family_restroom,
                          title: 'Family Member',
                          subtitle: 'Track driver location and receive alerts',
                          color: const Color(0xFF8B5CF6), // Purple
                          onTap: () => _navigateToLogin(context, UserRole.citizen),
                        ),

                        const SizedBox(height: 20),

                        _UserTypeCard(
                          icon: Icons.local_hospital,
                          title: 'Hospital Staff',
                          subtitle: 'Manage ambulances and hospital resources',
                          color: AppTheme.emergencyResponse,
                          onTap: () => _navigateToLogin(context, UserRole.hospitalStaff),
                        ),

                        const SizedBox(height: 20),

                        _UserTypeCard(
                          icon: Icons.admin_panel_settings,
                          title: 'System Admin',
                          subtitle: 'Monitor system health and IoT devices',
                          color: AppTheme.monitoringActive,
                          onTap: () => _navigateToLogin(context, UserRole.admin),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Footer
                Text(
                  'Real-time monitoring • Emergency response • Life safety',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoginScreen(role: role),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassmorphicDecoration(
        color: Colors.white,
        borderRadius: 20,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                
                const SizedBox(width: 20),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}