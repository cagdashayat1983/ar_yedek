import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cihazdaki kullanılabilir kameraları al
  final List<CameraDescription> cameras = await availableCameras();

  // 2. Kullanıcının durumunu kontrol et
  final prefs = await SharedPreferences.getInstance();

  // 🔴 DİKKAT: HAFIZAYI TAMAMEN SIFIRLAYAN KOD BURADA!
  // Testini yapıp Onboarding'i gördükten sonra bu satırı SİLMEYİ veya başına // koymayı UNUTMA!
  await prefs.clear();

  final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;

  runApp(MyApp(
    cameras: cameras,
    seenOnboarding: seenOnboarding,
    isLoggedIn: isLoggedIn,
  ));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  final bool seenOnboarding;
  final bool isLoggedIn;

  const MyApp({
    super.key,
    required this.cameras,
    required this.seenOnboarding,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ KUSURSUZ YÖNLENDİRME (ROUTING) MANTIĞI:
    Widget initialScreen;

    if (!seenOnboarding) {
      // Hiç açmamışsa Rehber
      initialScreen = OnboardingScreen(cameras: cameras);
    } else if (!isLoggedIn) {
      // Rehberi geçmiş ama giriş yapmamışsa Login
      initialScreen = LoginScreen(cameras: cameras);
    } else {
      // İkisini de geçmişse Direkt Ana Sayfa
      initialScreen = HomeScreen(cameras: cameras); // BURASI DEĞİŞTİ
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hayatify AR Drawing',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      home: initialScreen,
    );
  }
}
