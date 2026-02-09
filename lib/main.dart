import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Uygulama açılır açılmaz izinleri patlatıyoruz
    await [
      Permission.camera,
      Permission.microphone,
      Permission.photos,
    ].request();

    // Kameraları listele
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Kamera başlatma hatası: $e");
  }

  runApp(const HizliTasarimApp());
}

class HizliTasarimApp extends StatelessWidget {
  const HizliTasarimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text("Hizli Tasarim AR")),
        body: Center(
          child: cameras.isEmpty
              ? const Text("Kamera bulunamadı. Lütfen izinleri kontrol edin.")
              : Text(
                  "${cameras.length} kamera hazır! AR çizimine başlayabilirsin."),
        ),
      ),
    );
  }
}
