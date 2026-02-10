import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart'; // Isim hatasi olmamasi icin
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HizliTasarimScreen(),
  ));
}

class HizliTasarimScreen extends StatefulWidget {
  const HizliTasarimScreen({super.key});

  @override
  State<HizliTasarimScreen> createState() => _HizliTasarimScreenState();
}

class _HizliTasarimScreenState extends State<HizliTasarimScreen> {
  // --- AR YÖNETİCİLERİ (Motor Kısmı) ---
  dynamic
      arSessionManager; // Dynamic kullanarak setter hatalarını baypas ediyoruz
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  // --- UI DURUMLARI (Tasarım Kısmı) ---
  String selectedCategory = "Animals"; // Varsayılan kategori
  bool isARReady = false; // AR motoru hazır mı?

  // Kategori Listesi (Senin klasör yapına uygun)
  final List<String> categories = ["Animals", "Anime", "Cars", "Flowers"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // KATMAN 1: AR KAMERA GÖRÜNTÜSÜ (Zemin)
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // KATMAN 2: SENİN TASARIMIN (UI Overlay)
          Column(
            children: [
              // Üst Bar (Şeffaf & Şık)
              Container(
                padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Hizli Tasarim AR",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Avenir", // Varsa fontun
                      ),
                    ),
                    // Temizle Butonu
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: onRemoveEverything,
                    ),
                  ],
                ),
              ),

              const Spacer(), // Arayı boş bırak

              // Alt Panel: Kategori Seçimi ve Şablonlar
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Kategori Başlıkları (Yatay Liste)
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = cat == selectedCategory;
                          return GestureDetector(
                            onTap: () => setState(() => selectedCategory = cat),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 10),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.amber
                                      : Colors.white54,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),

                    // Şablon Listesi (Seçilen Kategoriye Göre)
                    Expanded(
                      child: Center(
                        child: Text(
                          "$selectedCategory Şablonları Yükleniyor...",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        // Buraya asset'leri bağlayacağız (Bir sonraki adım)
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // KATMAN 3: Yükleniyor Göstergesi (AR Hazır Olana Kadar)
          if (!isARReady)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 20),
                    Text("AR Motoru Başlatılıyor...",
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- AR MOTOR FONKSİYONLARI ---
  void onARViewCreated(
      ARSessionManager sessionManager,
      ARObjectManager objectManager,
      ARAnchorManager anchorManager,
      ARLocationManager locationManager) {
    this.arSessionManager = sessionManager;
    this.arObjectManager = objectManager;
    this.arAnchorManager = anchorManager;

    // TURUNCU NOKTALARI GİZLİYORUZ (Clean Look)
    this.arSessionManager.onInitialize(
          showFeaturePoints: false, // Artık nokta yok
          showPlanes: false, // Zemin çizgisi yok (Temiz görüntü)
          handleTaps: true,
        );
    this.arObjectManager.onInitialize();

    // UI'ya motorun hazır olduğunu bildir
    setState(() {
      isARReady = true;
    });

    // Tap Dinleyicisi (Şablon yerleştirmek için)
    try {
      arSessionManager.onPlaneTap = onPlaneTapHandler;
    } catch (e) {
      debugPrint("Hata: Setter atlanıyor");
    }
  }

  Future<void> onPlaneTapHandler(List<dynamic> hitTestResults) async {
    // Şimdilik boş bırakıyoruz, çünkü önce assetleri bağlayacağız.
    // Tıklandığında seçili şablonu buraya indireceğiz.
    debugPrint("Ekrana dokunuldu!");
  }

  Future<void> onRemoveEverything() async {
    // Temizleme fonksiyonu
    debugPrint("Sahne temizleniyor");
  }
}
