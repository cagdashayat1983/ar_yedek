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

// ---------------------------------------------------------
// 1. EKRAN: LOGIN
// ---------------------------------------------------------
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("HAYATIFY",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            TextField(
                decoration: InputDecoration(
                    hintText: "Kullanıcı Adı", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CategoryScreen()));
                },
                child: const Text("Giriş Yap",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 2. EKRAN: KATEGORİLER
// ---------------------------------------------------------
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({Key? key}) : super(key: key);
  final List<String> categories = const ["Animals", "Anime", "Cars", "Flowers"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              const Text("Kategoriler", style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 1),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Icon(Icons.folder, color: Colors.orange),
            title: Text(categories[index]),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AssetSelectionScreen(
                          categoryName: categories[index])));
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. EKRAN: RESİM SEÇİMİ
// ---------------------------------------------------------
class AssetSelectionScreen extends StatelessWidget {
  final String categoryName;
  const AssetSelectionScreen({Key? key, required this.categoryName})
      : super(key: key);
  final List<String> dummyAssets = const ["Model 1", "Model 2", "Model 3"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("$categoryName Seçimi"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1),
      body: GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: dummyAssets.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ARCameraScreen(selectedModel: dummyAssets[index])));
            },
            child: Container(
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image, size: 50),
                  Text(dummyAssets[index]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// 4. EKRAN: AR KAMERA (YAPIŞTIRMA)
// ---------------------------------------------------------
class ARCameraScreen extends StatefulWidget {
  final String selectedModel;
  const ARCameraScreen({Key? key, required this.selectedModel})
      : super(key: key);

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
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
      appBar: AppBar(
          title: Text(widget.selectedModel),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black54,
              child: const Text("Zemine dokunarak yerleştir",
                  style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

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

    // Yeni sürüm: onPlaneOrPointTap
    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapHandler;
  }

  Future<void> onPlaneOrPointTapHandler(
      List<ARHitTestResult?> hitTestResults) async {
    if (hitTestResults.isEmpty) return;

    // İlk geçerli plane'i bul
    ARHitTestResult? hitTestResult = hitTestResults.firstWhere(
      (hit) => hit != null && hit.type == ARHitTestResultType.plane,
      orElse: () => null,
    );

    if (hitTestResult == null ||
        hitTestResult.type == ARHitTestResultType.undefined) return;

    // Çapa ekle
    ARPlaneAnchor newAnchor =
        ARPlaneAnchor(transformation: hitTestResult.worldTransform);
    bool? didAddAnchor = await arAnchorManager.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      anchors.add(newAnchor);

      // Model ekle
      ARNode newNode = ARNode(
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
