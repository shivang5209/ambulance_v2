import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_theme.dart';
import '../services/secure_storage_service.dart';
import 'initial_login_screen.dart';

// ─── Onboarding data ─────────────────────────────────────────────────────────

class _OnboardPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color iconBg;
  final Color accentColor;
  // Set imagePath to e.g. 'assets/images/onboard_1.png' once images are ready
  final String? imagePath;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.iconBg,
    required this.accentColor,
    this.imagePath,
  });
}

const _pages = [
  _OnboardPage(
    title: 'Power On Your Device',
    subtitle: 'Step 1 of 5',
    description:
        'Plug your Smart Ambulance unit into a USB power source in your car. '
        'The OLED screen will light up — you\'re good to go!',
    icon: Icons.power_settings_new_rounded,
    iconBg: Color(0xFF1E40AF),
    accentColor: Color(0xFF3B82F6),
    imagePath: 'assets/images/onboard_1.png',
  ),
  _OnboardPage(
    title: 'Connect to Device Hotspot',
    subtitle: 'Step 2 of 5',
    description: 'Go to your phone\'s WiFi settings and connect to the hotspot '
        'printed on your device label:\n\n'
        '📶  Network: SMART-AMBULANCE-XXXX\n'
        '🔑  Password: printed on label\n\n'
        'Also find the Device Token on the label — you\'ll need it in the next step.',
    icon: Icons.wifi_rounded,
    iconBg: Color(0xFF065F46),
    accentColor: Color(0xFF10B981),
    imagePath: 'assets/images/onboard_2.png',
  ),
  _OnboardPage(
    title: 'Enter Your Hotspot Details',
    subtitle: 'Step 3 of 5',
    description: 'Tell the device your mobile hotspot name and password. '
        'It saves this securely on the chip — no one else can read it. '
        'Your device will then auto-connect every time it powers on.',
    icon: Icons.lock_rounded,
    iconBg: Color(0xFF92400E),
    accentColor: Color(0xFFF59E0B),
    imagePath: 'assets/images/onboard_3.png',
  ),
  _OnboardPage(
    title: 'Device is Setting Up',
    subtitle: 'Step 4 of 5',
    description:
        'The device restarts and connects to your hotspot automatically. '
        'Check the OLED screen — it will show your hotspot\'s IP address. '
        'Keep your hotspot ON!',
    icon: Icons.sync_rounded,
    iconBg: Color(0xFF4C1D95),
    accentColor: Color(0xFF8B5CF6),
    imagePath: 'assets/images/onboard_4.png',
  ),
  _OnboardPage(
    title: 'Connect & Monitor',
    subtitle: 'Step 5 of 5 — Done!',
    description: 'Open the app, tap "Connect by IP", and enter the IP address '
        'shown on the device\'s OLED screen. '
        'Your device ID is pre-filled. Tap Connect — you\'re live!',
    icon: Icons.sensors_rounded,
    iconBg: Color(0xFF065F46),
    accentColor: Color(0xFF22C55E),
    imagePath: 'assets/images/onboard_5.png',
  ),
];

// ─── Onboarding Screen ────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 3: WiFi setup form
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceTokenController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSendingWifi = false;
  String? _wifiError;

  final _secureStorage = SecureStorageService();

  @override
  void dispose() {
    _pageController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _deviceTokenController.dispose();
    super.dispose();
  }

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prev() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const InitialLoginScreen()),
    );
  }

  // Called on Step 3 (index 2) — send WiFi credentials to ESP32
  Future<void> _sendWifiToDevice() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;
    final deviceToken = _deviceTokenController.text.trim();

    if (ssid.isEmpty) {
      setState(() => _wifiError = 'Please enter your hotspot name');
      return;
    }
    if (deviceToken.isEmpty) {
      setState(
          () => _wifiError = 'Please enter the Device Token from the label');
      return;
    }

    setState(() {
      _isSendingWifi = true;
      _wifiError = null;
    });

    try {
      // ESP32 AP mode IP is always 192.168.4.1
      // setup_token authenticates this provisioning request (Fix 2)
      final response = await http
          .post(
            Uri.parse('http://192.168.4.1/wifi'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ssid': ssid,
              'password': password,
              'setup_token': deviceToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // ESP32 returns a bearer token for subsequent /sensors requests (Fix 3)
        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          final bearerToken = responseData['bearer_token'] as String?;
          if (bearerToken != null && bearerToken.isNotEmpty) {
            await _secureStorage.saveDeviceBearerToken(bearerToken);
          }
        } catch (_) {
          // Response may not be JSON on older firmware — bearer token optional
        }

        if (mounted) {
          setState(() => _isSendingWifi = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WiFi saved! Device is restarting...'),
              backgroundColor: AppTheme.success,
              duration: Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          _next();
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _isSendingWifi = false;
          _wifiError = 'Invalid Device Token. Check the label and try again.';
        });
      } else {
        setState(() {
          _isSendingWifi = false;
          _wifiError = 'Device error: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isSendingWifi = false;
        _wifiError =
            'Could not reach device.\nMake sure you are connected to\nSMART-AMBULANCE-XXXX';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // ── Skip button (top right)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Page carousel
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) {
                    if (i != 2) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                    setState(() => _currentPage = i);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) =>
                      _buildPage(context, _pages[index], index),
                ),
              ),

              // ── Dot indicators
              _buildDots(),
              const SizedBox(height: 14),

              // ── Navigation buttons
              _buildNavButtons(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _OnboardPage page, int index) {
    final isFormStep = index == 2;
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final shortScreen = media.size.height < 740 || keyboardOpen;
    final illustrationSize = isFormStep
        ? (shortScreen ? 96.0 : 120.0)
        : (shortScreen ? 132.0 : 170.0);
    final titleSize = shortScreen ? 20.0 : 22.0;
    final bodySize = shortScreen ? 14.0 : 15.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: isFormStep ? 4 : 8),

        // ── Illustration
        _buildIllustration(page, size: illustrationSize),
        SizedBox(height: isFormStep ? 14 : 20),

        // ── Step label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: page.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: page.accentColor.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            page.subtitle,
            style: TextStyle(
              color: page.accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),

        const SizedBox(height: 12),

        // ── Title
        Text(
          page.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2),

        const SizedBox(height: 12),

        // ── Description or WiFi form (step 3)
        if (isFormStep)
          _buildWiFiForm(page)
        else
          Text(
            page.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: bodySize,
              height: shortScreen ? 1.45 : 1.6,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

        SizedBox(height: isFormStep ? 8 : 12),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const ClampingScrollPhysics(),
      child: content,
    );
  }

  Widget _buildIllustration(_OnboardPage page, {double size = 180}) {
    // Try to load the asset image; if not present fall back to icon
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: page.iconBg.withValues(alpha: 0.25),
        border: Border.all(
          color: page.accentColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: page.imagePath != null
            ? Image.asset(
                page.imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _iconFallback(page),
              )
            : _iconFallback(page),
      ),
    ).animate().scale(
          begin: const Offset(0.8, 0.8),
          duration: 500.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _iconFallback(_OnboardPage page) {
    return Center(
      child: Icon(
        page.icon,
        size: 80,
        color: page.accentColor,
      ),
    );
  }

  Widget _buildWiFiForm(_OnboardPage page) {
    return Column(
      children: [
        Text(
          'Enter your mobile hotspot details and the Device Token printed on the device label.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Device Token field
        TextField(
          controller: _deviceTokenController,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'Device Token (from label)',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            hintText: 'e.g. a3f9-k2m1',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            prefixIcon: Icon(Icons.qr_code_rounded, color: page.accentColor),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: page.accentColor),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        const SizedBox(height: 12),

        // SSID field
        TextField(
          controller: _ssidController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Hotspot Name (SSID)',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            hintText: 'e.g. My Phone Hotspot',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            prefixIcon: Icon(Icons.wifi, color: page.accentColor),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: page.accentColor),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        const SizedBox(height: 12),

        // Password field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Hotspot Password',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.lock, color: page.accentColor),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: page.accentColor),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
          ),
        ),

        if (_wifiError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _wifiError!,
                    style: const TextStyle(
                        color: AppTheme.error, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSendingWifi ? null : _sendWifiToDevice,
            icon: _isSendingWifi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_isSendingWifi ? 'Sending...' : 'Send to Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: page.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? _pages[_currentPage].accentColor
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildNavButtons() {
    final isLast = _currentPage == _pages.length - 1;
    final isStep3 = _currentPage == 2; // WiFi setup step

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          // Back button
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _prev,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: 12),

          // Next / Done button (hidden on step 3 since button is inside the form)
          if (!isStep3)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _next,
                icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded),
                label: Text(isLast ? 'Get Started' : 'Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pages[_currentPage].accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
