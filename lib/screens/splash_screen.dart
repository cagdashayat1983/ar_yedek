import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Paket yolları
import 'package:flutter_application_1/services/subscription_service.dart';
import 'package:flutter_application_1/screens/onboarding_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 🌟 Logo animasyonunu hazırla
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 🚀 HIZLANDIRMA: Perdeyi hemen kaldırıyoruz ki senin logon anında belirsin!
    FlutterNativeSplash.remove();
    _controller.forward();

    try {
      // ⏳ Ağır işler arkada sessizce yapılıyor (Kullanıcı logonla meşgulken)
      await SubscriptionService.init();
      final List<CameraDescription> cameras = await availableCameras();
      final prefs = await SharedPreferences.getInstance();

      // Hafıza kontrolü
      final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
      final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      // Animasyonun keyfini sürmek için 1 saniye daha bekle
      await Future.delayed(const Duration(milliseconds: 1000));

      // 🎯 Nereye gideceğine SplashScreen karar veriyor
      Widget target;
      if (!seenOnboarding) {
        target = OnboardingScreen(cameras: cameras);
      } else if (!isLoggedIn) {
        target = LoginScreen(cameras: cameras);
      } else {
        target = HomeScreen(cameras: cameras);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) => target,
            transitionsBuilder: (context, anim, secAnim, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      debugPrint("Yükleme Hatası: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Lacivert premium arka plan
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.draw_rounded,
                  size: 90, color: Colors.cyanAccent),
              const SizedBox(height: 25),
              Text(
                "HAYATIFY",
                style: GoogleFonts.poppins(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "AR DRAWING",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.cyanAccent.withOpacity(0.8),
                  letterSpacing: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
