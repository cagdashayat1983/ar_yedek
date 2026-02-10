import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeScreen(), // Başlangıç noktası artık Ana Menü
  ));
}

// ==========================================
// 1. BÖLÜM: ANA MENÜ (KATEGORİ SEÇİM EKRANI)
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<String> categories = const ["Animals", "Anime", "Cars", "Flowers"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hizli Tasarim",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Hoşgeldin Sam,",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            const Text(
              "Ne Çizmek İstersin?",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      // Kategoriye tıklanınca AR Ekranına git
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ARDrawingScreen(
                            selectedCategory: categories[index],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open,
                              size: 50, color: Colors.orange[800]),
                          const SizedBox(height: 15),
                          Text(
                            categories[index],
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. BÖLÜM: AR KAMERA EKRANI (MOTOR)
// ==========================================
class ARDrawingScreen extends StatefulWidget {
  final String selectedCategory;
  const ARDrawingScreen({super.key, required this.selectedCategory});

  @override
  State<ARDrawingScreen> createState() => _ARDrawingScreenState();
}

class _ARDrawingScreenState extends State<ARDrawingScreen> {
  // AR Yöneticileri (Dynamic kullanarak hataları önlüyoruz)
  dynamic arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  bool isReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // KATMAN 1: AR KAMERA GÖRÜNTÜSÜ
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // KATMAN 2: SENİN TASARIMIN (UI Overlay)
          Column(
            children: [
              // Üst Bar (Geri Dön Butonu ve Başlık)
              Container(
                padding: const EdgeInsets.only(
                    top: 50, left: 20, right: 20, bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context), // Geri dön
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      widget.selectedCategory, // "Animals" vb. yazar
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // Sağ tarafa temizle butonu
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: onRemoveEverything,
                    ),
                  ],
                ),
              ),

              const Spacer(), // Ortayı boş bırak (Kamera görünsün)

              // Alt Bilgi Paneli
              if (isReady)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                  ),
                  child: Text(
                    "Şablon yerleştirmek için zemine dokun.\n(Kategori: ${widget.selectedCategory})",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),

          // Yükleniyor Göstergesi
          if (!isReady)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 20),
                    Text("AR Kamerası Başlatılıyor...",
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- AR KURULUMU ---
  void onARViewCreated(
      ARSessionManager sessionManager,
      ARObjectManager objectManager,
      ARAnchorManager anchorManager,
      ARLocationManager locationManager) {
    this.arSessionManager = sessionManager;
    this.arObjectManager = objectManager;
    this.arAnchorManager = anchorManager;

    // Turuncu noktaları ve beyaz zeminleri GİZLİYORUZ (Clean Look)
    this.arSessionManager.onInitialize(
          showFeaturePoints: false,
          showPlanes: false,
          handleTaps: true,
        );
    this.arObjectManager.onInitialize();

    setState(() {
      isReady = true;
    });

    // Tıklama olayını bağlıyoruz
    try {
      arSessionManager.onPlaneTap = onPlaneTapHandler;
    } catch (e) {
      debugPrint("Hata: Setter atlanıyor");
    }
  }

  Future<void> onPlaneTapHandler(List<dynamic> hitTestResults) async {
    // Buraya şablon ekleme kodu gelecek. Şimdilik log basıyoruz.
    debugPrint("Ekrana dokunuldu! Kategori: ${widget.selectedCategory}");
  }

  Future<void> onRemoveEverything() async {
    // Temizleme fonksiyonu (Daha sonra dolduracağız)
  }
}
