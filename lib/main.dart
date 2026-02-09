import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/login_screen.dart'; // Senin giriş ekranın

// Global değişken (İhtiyaç olursa diye tutuyoruz)
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kameraları arka planda bulmaya çalış, bulamazsa da sorun değil
  // Çünkü DrawingScreen artık kendi başının çaresine bakabiliyor!
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Main Kamera Hatası: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kılıf Tasarım',

      // Temayı koyu yapıyoruz, çizim ekranıyla uyumlu olsun
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),

      // UYGULAMA BURADAN BAŞLAR:
      home: const LoginScreen(),
    );
  }
}
