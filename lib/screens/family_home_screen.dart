import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive_helper.dart';
import '../widgets/responsive_grid.dart';
import 'role_selection_screen.dart';

class FamilyHomeScreen extends StatefulWidget {
  final String title;
  const FamilyHomeScreen({super.key, this.title = 'Family Tracking'});

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription<Position>? _locationSubscription;

  // Driver data
  final String _vehicleNumber = "ABC-1234";
  double _currentLat = 0.0;
  double _currentLng = 0.0;
  bool _locationLoaded = false;
  double _currentSpeed = 45.2;
  double _lastGForce = 0.98;
  final bool _isDriverSafe = true;
  String _lastUpdate = "Waiting for GPS...";
  
  // Alert history
  List<AlertData> _alerts = [];
  
  // Location history
  List<LocationPoint> _locationHistory = [];
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _generateMockData();
    _initLocationStream();
  }

  Future<void> _initLocationStream() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      // Get an immediate fix first
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
          _locationLoaded = true;
          _lastUpdate = 'Just now';
          _locationHistory.insert(0, LocationPoint(
            lat: position.latitude,
            lng: position.longitude,
            timestamp: DateTime.now(),
          ));
        });
      }

      // Then subscribe to live updates
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // update every 5 metres moved
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentSpeed = (pos.speed * 3.6); // m/s → km/h
          _locationLoaded = true;
          _lastUpdate = 'Just now';
          _locationHistory.insert(0, LocationPoint(
            lat: pos.latitude,
            lng: pos.longitude,
            timestamp: DateTime.now(),
          ));
          if (_locationHistory.length > 20) _locationHistory.removeLast();
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _generateMockData() {
    final random = math.Random();
    
    // Generate alert history
    _alerts = List.generate(5, (index) {
      return AlertData(
        type: AlertType.values[random.nextInt(AlertType.values.length)],
        message: _getRandomAlertMessage(random),
        timestamp: DateTime.now().subtract(Duration(hours: random.nextInt(48))),
        severity: random.nextInt(3),
        location: 'Zone ${String.fromCharCode(65 + random.nextInt(5))}-${random.nextInt(10) + 1}',
      );
    });
    
    // Generate location history
    _locationHistory = List.generate(10, (index) {
      return LocationPoint(
        lat: _currentLat + (random.nextDouble() - 0.5) * 0.1,
        lng: _currentLng + (random.nextDouble() - 0.5) * 0.1,
        timestamp: DateTime.now().subtract(Duration(minutes: index * 5)),
      );
    });
  }


  String _getRandomAlertMessage(math.Random random) {
    final messages = [
      'High speed detected',
      'Sharp turn detected',
      'Sudden braking',
      'Long drive alert',
      'Rest recommended',
    ];
    return messages[random.nextInt(messages.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Alerts',
            onPressed: _showAlertsDialog,
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
            // Driver Status Card
            _buildDriverStatusCard(),
            
            const SizedBox(height: 24),
            
            // Live Location Map
            _buildLocationMapCard(),
            
            const SizedBox(height: 24),
            
            // Quick Stats
            _buildQuickStats(),
            
            const SizedBox(height: 24),
            
            // Recent Alerts
            _buildRecentAlerts(),
            
            const SizedBox(height: 24),
            
            // Emergency Actions
            _buildEmergencyActions(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showLocationOnMap();
        },
        icon: const Icon(Icons.map),
        label: const Text('View on Map'),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  Widget _buildDriverStatusCard() {
    final statusColor = _isDriverSafe ? AppTheme.success : AppTheme.error;
    final user = context.watch<AuthProvider>().currentUser;
    final displayName = (user?.firstName != null && user!.firstName!.isNotEmpty)
        ? '${user.firstName!} ${user.lastName ?? ''}'.trim()
        : user?.username.isNotEmpty == true
            ? user!.username
            : user?.email?.split('@').first ?? 'Driver';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withValues(
                  alpha: 0.3 + 0.4 * _pulseController.value),
              width: 2,
            ),
            boxShadow: AppTheme.neumorphicShadow(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isDriverSafe ? 'Driver is Safe' : 'Alert: Check Driver',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _lastUpdate,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Driver info row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: statusColor.withValues(alpha: 0.12),
                      child: Icon(Icons.person, size: 30, color: statusColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vehicle: $_vehicleNumber',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _callDriver,
                      icon: Icon(Icons.phone, color: statusColor),
                      iconSize: 26,
                      style: IconButton.styleFrom(
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationMapCard() {
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
          // Header
          Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'LIVE LOCATION',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      letterSpacing: 1.5,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _locationLoaded ? AppTheme.success : AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _locationLoaded ? 'Live' : 'Locating...',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _locationLoaded ? AppTheme.success : AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Map placeholder with grid pattern
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: ResponsiveHelper.value(context, mobile: 160.0, desktop: 300.0),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE8F4FD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  // Grid lines to suggest a map
                  CustomPaint(
                    size: const Size(double.infinity, 160),
                    painter: _MapGridPainter(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.blueGrey.withValues(alpha: 0.1),
                    ),
                  ),
                  Center(
                    child: _locationLoaded
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_pin,
                                    color: AppTheme.error, size: 32),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Getting GPS location...',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Coordinates row
          Row(
            children: [
              _buildCoordChip('Lat', _locationLoaded ? _currentLat.toStringAsFixed(6) : '--'),
              const SizedBox(width: 10),
              _buildCoordChip('Lng', _locationLoaded ? _currentLng.toStringAsFixed(6) : '--'),
            ],
          ),

          const SizedBox(height: 16),

          // Open Maps button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showLocationOnMap,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open in Google Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return ResponsiveGrid(
      mobileColumns: 2,
      tabletColumns: 3,
      desktopColumns: 4,
      spacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          'Current Speed',
          '${_currentSpeed.toStringAsFixed(1)} km/h',
          Icons.speed,
          AppTheme.monitoringActive,
        ),
        _buildStatCard(
          'G-Force',
          '${_lastGForce.toStringAsFixed(2)}G',
          Icons.analytics,
          AppTheme.normalOperation,
        ),
        _buildStatCard(
          'Distance Today',
          '45.2 km',
          Icons.route,
          AppTheme.accent,
        ),
        _buildStatCard(
          'Drive Time',
          '1h 23m',
          Icons.timer,
          const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts() {
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
              Text(
                'Recent Alerts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _showAlertsDialog,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_alerts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: AppTheme.success,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No alerts - Driver is safe!',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(_alerts.length, 3),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildAlertItem(alert);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(AlertData alert) {
    final color = alert.severity == 2 ? AppTheme.error : 
                  alert.severity == 1 ? AppTheme.accent : 
                  AppTheme.normalOperation;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            alert.type.icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${alert.location} • ${_formatTimestamp(alert.timestamp)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyActions() {
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
            'Emergency Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _callDriver,
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _callEmergency,
                  icon: const Icon(Icons.emergency),
                  label: const Text('Emergency'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareLocation,
              icon: const Icon(Icons.share_location),
              label: const Text('Share Location'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showLocationOnMap() {
    // Open Google Maps with current location
    final url = 'https://www.google.com/maps/search/?api=1&query=$_currentLat,$_currentLng';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open in Google Maps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver Location:'),
            const SizedBox(height: 8),
            Text(
              'Lat: ${_currentLat.toStringAsFixed(6)}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            Text(
              'Lng: ${_currentLng.toStringAsFixed(6)}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            Text(
              'Copy this URL to open in Google Maps:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SelectableText(
              url,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // In a real app, use url_launcher package
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copy the URL and paste in browser to open Google Maps'),
                ),
              );
            },
            child: const Text('Copy URL'),
          ),
        ],
      ),
    );
  }

  void _callDriver() {
    final user = context.read<AuthProvider>().currentUser;
    final name = (user?.firstName != null && user!.firstName!.isNotEmpty)
        ? '${user.firstName!} ${user.lastName ?? ''}'.trim()
        : user?.username.isNotEmpty == true
            ? user!.username
            : user?.email?.split('@').first ?? 'Driver';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Driver'),
        content: Text('Calling $name...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _callEmergency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: const Text('This will alert emergency services and send driver location. Continue?'),
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
                  content: Text('Emergency services alerted!'),
                  backgroundColor: AppTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Alert Emergency'),
          ),
        ],
      ),
    );
  }

  void _shareLocation() {
    final message = 'Driver location: https://www.google.com/maps/search/?api=1&query=$_currentLat,$_currentLng';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Location'),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location link copied!'),
                ),
              );
            },
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  void _showAlertsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Alerts'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: _alerts.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final alert = _alerts[index];
              return ListTile(
                leading: Icon(
                  alert.type.icon,
                  color: alert.severity == 2 ? AppTheme.error : AppTheme.accent,
                ),
                title: Text(alert.message),
                subtitle: Text('${alert.location} • ${_formatTimestamp(alert.timestamp)}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Data classes
class AlertData {
  final AlertType type;
  final String message;
  final DateTime timestamp;
  final int severity; // 0: low, 1: medium, 2: high
  final String location;

  AlertData({
    required this.type,
    required this.message,
    required this.timestamp,
    required this.severity,
    required this.location,
  });
}

class LocationPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;

  LocationPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });
}

enum AlertType {
  speed('Speed', Icons.speed),
  turn('Turn', Icons.turn_right),
  brake('Brake', Icons.warning),
  rest('Rest', Icons.hotel),
  other('Other', Icons.info);

  const AlertType(this.displayName, this.icon);

  final String displayName;
  final IconData icon;
}

class _MapGridPainter extends CustomPainter {
  final Color color;
  _MapGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter oldDelegate) => false;
}
