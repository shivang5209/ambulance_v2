import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/app_theme.dart';
import 'role_selection_screen.dart';

class HospitalHomeScreen extends StatefulWidget {
  const HospitalHomeScreen({super.key});

  @override
  State<HospitalHomeScreen> createState() => _HospitalHomeScreenState();
}

class _HospitalHomeScreenState extends State<HospitalHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  
  // Mock hospital data
  final int _availableBeds = 12;
  final int _totalBeds = 50;
  final int _activeAmbulances = 8;
  final int _totalAmbulances = 15;
  List<AmbulanceData> _ambulances = [];
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _generateMockAmbulanceData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _generateMockAmbulanceData() {
    final random = math.Random();
    _ambulances = List.generate(8, (index) {
      return AmbulanceData(
        id: 'AMB-${(index + 1).toString().padLeft(3, '0')}',
        driverName: ['John Doe', 'Jane Smith', 'Mike Johnson', 'Sarah Wilson'][random.nextInt(4)],
        status: AmbulanceStatus.values[random.nextInt(AmbulanceStatus.values.length)],
        location: 'Sector ${random.nextInt(50) + 1}',
        eta: '${random.nextInt(20) + 5} min',
        patientCount: random.nextInt(3),
        lastUpdate: DateTime.now().subtract(Duration(minutes: random.nextInt(30))),
      );
    });
    
    // Update every 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _generateMockAmbulanceData();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Hospital Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _generateMockAmbulanceData();
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'switch_role') {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'switch_role',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    SizedBox(width: 12),
                    Text('Switch Role'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hospital Status Overview
            _buildHospitalStatusCard(),
            
            const SizedBox(height: 24),
            
            // Quick Stats
            _buildQuickStats(),
            
            const SizedBox(height: 24),
            
            // Live Ambulance Tracking
            _buildAmbulanceTracking(),
            
            const SizedBox(height: 24),
            
            // Bed Management
            _buildBedManagement(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showEmergencyAlert(context);
        },
        icon: const Icon(Icons.emergency),
        label: const Text('Emergency Alert'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  Widget _buildHospitalStatusCard() {
    final bedOccupancy = ((_totalBeds - _availableBeds) / _totalBeds * 100);
    final ambulanceUtilization = (_activeAmbulances / _totalAmbulances * 100);
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.emergencyResponse
                  .withValues(alpha: 0.3 + 0.4 * _pulseController.value),
              width: 2,
            ),
            boxShadow: AppTheme.neumorphicShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status pill
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Hospital Online',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Live Status',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildStatusMetric(
                      'Available Beds',
                      '$_availableBeds',
                      '${bedOccupancy.toStringAsFixed(0)}% occupied',
                      Icons.bed,
                      AppTheme.monitoringActive,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.1),
                  ),
                  Expanded(
                    child: _buildStatusMetric(
                      'Active Ambulances',
                      '$_activeAmbulances',
                      '${ambulanceUtilization.toStringAsFixed(0)}% in use',
                      Icons.local_shipping,
                      AppTheme.emergencyResponse,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusMetric(String label, String value, String subtitle,
      IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        letterSpacing: 0.3,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Emergency Cases', '23', '+5 today', Icons.emergency, AppTheme.error)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Patients Admitted', '156', '+12 today', Icons.person_add, AppTheme.success)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard('Avg Response', '8 min', '-2 min vs yesterday', Icons.timer, AppTheme.monitoringActive)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Staff on Duty', '45', '12 doctors, 33 nurses', Icons.people, AppTheme.normalOperation)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAmbulanceTracking() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'Live Ambulance Tracking',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_ambulances.length} Active',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: math.min(_ambulances.length, 4), // Show first 4
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ambulance = _ambulances[index];
              return _buildAmbulanceItem(ambulance);
            },
          ),
          
          if (_ambulances.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: () {
                  // Show all ambulances
                },
                child: Text('View All ${_ambulances.length} Ambulances'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmbulanceItem(AmbulanceData ambulance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ambulance.status.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ambulance.status.color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ambulance.status.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_shipping,
              color: ambulance.status.color,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ambulance.id,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: ambulance.status.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ambulance.status.displayName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Driver: ${ambulance.driverName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        ambulance.location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 3),
                    Text(
                      ambulance.eta,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBedManagement() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bed Management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Bed occupancy chart
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bed Occupancy',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_totalBeds - _availableBeds) / _totalBeds,
                      backgroundColor: AppTheme.success.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        (_availableBeds / _totalBeds) < 0.2 ? AppTheme.error : AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_totalBeds - _availableBeds} occupied • $_availableBeds available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    '${((_totalBeds - _availableBeds) / _totalBeds * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: (_availableBeds / _totalBeds) < 0.2 ? AppTheme.error : AppTheme.accent,
                    ),
                  ),
                  Text(
                    'Occupied',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Department breakdown
          _buildDepartmentBeds('Emergency', 8, 12, AppTheme.error),
          const SizedBox(height: 8),
          _buildDepartmentBeds('ICU', 15, 20, AppTheme.accent),
          const SizedBox(height: 8),
          _buildDepartmentBeds('General', 15, 18, AppTheme.normalOperation),
        ],
      ),
    );
  }

  Widget _buildDepartmentBeds(String department, int occupied, int total, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            department,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          '$occupied/$total',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showEmergencyAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: const Text('Send emergency alert to all available ambulances?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency alert sent to all ambulances'),
                  backgroundColor: AppTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }
}

// Mock data classes
class AmbulanceData {
  final String id;
  final String driverName;
  final AmbulanceStatus status;
  final String location;
  final String eta;
  final int patientCount;
  final DateTime lastUpdate;

  AmbulanceData({
    required this.id,
    required this.driverName,
    required this.status,
    required this.location,
    required this.eta,
    required this.patientCount,
    required this.lastUpdate,
  });
}

enum AmbulanceStatus {
  available('Available', AppTheme.success),
  enRoute('En Route', AppTheme.monitoringActive),
  atScene('At Scene', AppTheme.accent),
  returning('Returning', AppTheme.emergencyResponse);

  const AmbulanceStatus(this.displayName, this.color);

  final String displayName;
  final Color color;
}