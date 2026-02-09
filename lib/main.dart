import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

// Kameralara her yerden erişebilmek için global bir liste
List<CameraDescription> cameras = [];

void main() async {
  // 1. Flutter motorunun hazır olduğundan emin ol
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. iOS Gizlilik İzinlerini Sırayla İste (Codemagic ve Podfile ayarlarıyla eşleşir)
    // Bu kısım o beklediğin izin kutucuklarını ekrana getirir
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.photos,
    ].request();

    // İzinlerin durumunu konsola yazdır (Debug için)
    statuses.forEach((permission, status) {
      print('${permission.toString()}: $status');
    });

    // 3. Mevcut kameraları listele
    cameras = await availableCameras();
    print("Sistemde bulunan kamera sayısı: ${cameras.length}");
  } catch (e) {
    print("Başlatma sırasında bir hata oluştu: $e");
  }

  runApp(const HizliTasarimApp());
}

class HizliTasarimApp extends StatelessWidget {
  const HizliTasarimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hizli Tasarim AR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ARHomePage(),
    );
  }
}

class ARHomePage extends StatefulWidget {
  const ARHomePage({super.key});

  @override
  State<ARHomePage> createState() => _ARHomePageState();
}

class _ARHomePageState extends State<ARHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hizli Tasarim AR"),
        centerTitle: true,
      ),
      body: Center(
        child: cameras.isEmpty
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_rear_outlined, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    "Kamera algılanamadı!\nLütfen izinleri ve bağlantıyı kontrol edin.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text("${cameras.length} adet kamera hazır."),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Buradan AR Çizim ekranına yönlendirme yapabilirsin
                      print("AR Deneyimi Başlatılıyor...");
                    },
                    child: const Text("AR Çizimi Başlat"),
                  ),
                ],
              ),
      ),
    );
  }
}
