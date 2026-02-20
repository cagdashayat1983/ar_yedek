import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // Kamera için şart
import 'package:shared_preferences/shared_preferences.dart'; // Rehber kontrolü için şart
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/categories_screen.dart';

// ✅ main fonksiyonunu 'async' yaptık çünkü kamera ve hafıza başlangıçta yüklenmeli
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cihazdaki kullanılabilir kameraları al
  final List<CameraDescription> cameras = await availableCameras();

  // 2. Kullanıcının rehberi (Onboarding) görüp görmediğini kontrol et
  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  // 3. (Opsiyonel) Giriş yapıp yapmadığını da buradan kontrol edebilirsin
  // final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;

  runApp(MyApp(
    cameras: cameras,
    seenOnboarding: seenOnboarding,
  ));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  final bool seenOnboarding;

  const MyApp({super.key, required this.cameras, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hayatify AR Drawing',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      // ✅ AKIŞ KONTROLÜ:
      // Eğer rehberi görmediyse OnboardingScreen, gördüyse LoginScreen açılır.
      home: seenOnboarding
          ? LoginScreen(
              cameras: cameras) // Login ekranına kameraları paslıyoruz
          : OnboardingScreen(cameras: cameras),
    );
  }
}
