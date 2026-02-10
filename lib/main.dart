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
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoginScreen(),
  ));
}

// ==========================================
// 1. EKRAN: LOGIN (SENİN TASARIMIN)
// ==========================================
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO ALANI
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.black, // Varsa buraya Image.asset koyacağız
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.draw, color: Colors.white, size: 60),
              ),
              const SizedBox(height: 20),
              const Text("HAYATIFY",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              const Text("Hizli Tasarim AR",
                  style: TextStyle(color: Colors.grey, fontSize: 16)),

              const SizedBox(height: 50),

              // Inputlar
              TextField(
                  decoration: InputDecoration(
                      hintText: "E-posta",
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 15),
              TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                      hintText: "Şifre",
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),

              const SizedBox(height: 30),

              // Buton
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Kategori Ekranına Git
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CategoryScreen()));
                  },
                  child: const Text("Giriş Yap",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. EKRAN: KATEGORİLER (ASSET KLASÖRLERİN)
// ==========================================
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({Key? key}) : super(key: key);

  // Senin klasör isimlerin
  final List<String> categories = const ["animals", "anime", "cars", "flowers"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ne Çizmek İstersin?",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.1,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            String catName = categories[index];
            // İlk harfi büyütme (görsel için)
            String displayName =
                catName[0].toUpperCase() + catName.substring(1);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AssetSelectionScreen(
                            categoryFolder: catName,
                            categoryTitle: displayName)));
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
                        offset: Offset(0, 4))
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Kategori İkonu (Asset resmi varsa buraya Image.asset koyabiliriz)
                    Icon(Icons.folder_special,
                        size: 50, color: Colors.orange[800]),
                    const SizedBox(height: 10),
                    Text(displayName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// 3. EKRAN: RESİM LİSTESİ (ASSETS'TEN GELENLER)
// ==========================================
class AssetSelectionScreen extends StatelessWidget {
  final String categoryFolder; // örn: "animals"
  final String categoryTitle; // örn: "Animals"

  const AssetSelectionScreen(
      {Key? key, required this.categoryFolder, required this.categoryTitle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // BURASI ÖNEMLİ: Asset klasöründe kaç resim olduğunu bilemeyiz,
    // o yüzden şimdilik 10 tane varsayıyoruz. Senin dosyaların 1.png, 2.png gibi sıralıysa bu çalışır.
    // Eğer isimler farklıysa bir liste (List<String>) yapmamız gerekecek.
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: 6, // Şimdilik her klasörde 6 resim var varsayıyoruz
        itemBuilder: (context, index) {
          // Asset Yolu: assets/animals/1.png gibi...
          // Eğer resimlerin jpg ise .jpg yapmalısın.
          String imagePath = "assets/$categoryFolder/${index + 1}.png";

          return GestureDetector(
            onTap: () {
              // AR Ekranına Resmi Gönderiyoruz
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ARCameraScreen(selectedImagePath: imagePath)));
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
                image: DecorationImage(
                  // Burada asset resmini yüklüyoruz. Eğer resim yoksa hata vermemesi için errorBuilder kullanıyoruz.
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  // Resim yüklenemezse (dosya yoksa) gösterilecek placeholder
                  Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.grey),
                          Text("Resim ${index + 1}",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ));
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 4. EKRAN: AR KAMERA (KENDİ TASARIMIN + SAĞLAM MOTOR)
// ==========================================
class ARCameraScreen extends StatefulWidget {
  final String selectedImagePath;
  const ARCameraScreen({Key? key, required this.selectedImagePath})
      : super(key: key);

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
  // SAĞLAM AR DEĞİŞKENLERİ (ChatGPT Düzeltmesi)
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];

  @override
  void dispose() {
    super.dispose();
    arSessionManager.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. AR KAMERA ZEMİNİ
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // 2. ÜST BAR (Geri Dön ve Seçilen Resim Bilgisi)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context)),
                ),
                SizedBox(width: 15),
                Text("Çizim Modu",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black)
                        ])),
              ],
            ),
          ),

          // 3. ALT BİLGİ (Kullanıcıya Ne Yapacağını Söyle)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.only(bottom: 40),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20)),
              child: Text("Modele dokunarak yerleştir",
                  style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  // --- MOTOR KISMI (DOKUNMA ---
  void onARViewCreated(
      ARSessionManager sessionManager,
      ARObjectManager objectManager,
      ARAnchorManager anchorManager,
      ARLocationManager locationManager) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    arSessionManager.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      handleTaps: true,
    );
    arObjectManager.onInitialize();

    // DÜZELTİLMİŞ FONKSİYON İSMİ
    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapHandler;
  }

  Future<void> onPlaneOrPointTapHandler(
      List<ARHitTestResult?> hitTestResults) async {
    if (hitTestResults.isEmpty) return;

    // Null check yapılmış güvenli kod
    ARHitTestResult? hitTestResult = hitTestResults.firstWhere(
      (hit) => hit != null && hit.type == ARHitTestResultType.plane,
      orElse: () => null,
    );

    if (hitTestResult == null) return;

    var newAnchor = ARPlaneAnchor(transformation: hitTestResult.worldTransform);
    bool? didAddAnchor = await arAnchorManager.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      anchors.add(newAnchor);

      // BURADA SENİN SEÇTİĞİN RESMİ KOYACAĞIZ (Şimdilik 3D Ördek, ama UI düzelsin sonra 2D'ye çevireceğiz)
      // "widget.selectedImagePath" değişkeni elimizde, onu kullanacağız.
      var newNode = ARNode(
        type: NodeType.webGLB,
        uri:
            "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Duck/glTF-Binary/Duck.glb",
        scale: vector.Vector3(0.1, 0.1, 0.1),
        position: vector.Vector3(0.0, 0.0, 0.0),
        rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
      );

      bool? didAddNode =
          await arObjectManager.addNode(newNode, planeAnchor: newAnchor);
      if (didAddNode == true) {
        nodes.add(newNode);
      }
    }
  }
}
