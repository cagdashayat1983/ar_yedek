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
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ARDrawingCanvas(),
  ));
}

class ARDrawingCanvas extends StatefulWidget {
  const ARDrawingCanvas({super.key});

  @override
  State<ARDrawingCanvas> createState() => _ARDrawingCanvasState();
}

class _ARDrawingCanvasState extends State<ARDrawingCanvas> {
  // AR Yöneticileri
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  // Çizilen objeleri takip etmek için liste
  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hizli Tasarim AR Çizim"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRemoveEverything,
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. Gerçek Zamanlı AR Görünümü
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: ARPlaneDetectionConfig.horizontalAndVertical,
          ),

          // 2. Kullanıcı Arayüzü (Bilgilendirme)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "İpucu: Zemini veya duvarı tarayın, beliren noktalara dokunarak çizim yapın.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // AR Sahnesi Başlatma
  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    // Oturumu Ayarla
    this.arSessionManager.onInitialize(
          showFeaturePoints: true, // Zemin algılamayı kolaylaştırır
          showPlanes: true,
          customPlaneTexturePath:
              "assets/tutorial/triangle.png", // Varsa asset yolun
          handleTaps: true, // Dokunmaları dinle
        );
    this.arObjectManager.onInitialize();

    // Dokunma olayını bağla
    this.arSessionManager.onPlaneTap = onPlaneTapHandler;
  }

  // Ekrana Dokunulduğunda Çizim Yap/Nokta Koy
  Future<void> onPlaneTapHandler(List<ARHitTestResult> hitTestResults) async {
    // Sadece algılanan yüzeylere dokunulduğunda çalış
    var tap = hitTestResults
        .firstWhere((result) => result.type == ARHitTestResultType.plane);

    // 1. Dokunulan yere bir 'Anchor' (Çapa) koy
    var newAnchor = ARPlaneAnchor(transformation: tap.worldTransform);
    bool? didAddAnchor = await arAnchorManager.addAnchor(newAnchor);

    if (didAddAnchor!) {
      anchors.add(newAnchor);

      // 2. Bu çapaya 3D bir küre (fırça darbesi) ekle
      var newNode = ARNode(
        type: NodeType.webGLB, // veya basit bir küre için NodeType.localGLTF
        uri:
            "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Duck/glTF-Binary/Duck.glb", // Örnek 3D Obje
        scale: vector.Vector3(0.1, 0.1, 0.1),
        position: vector.Vector3(0, 0, 0),
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      bool? didAddNode =
          await arObjectManager.addNode(newNode, anchor: newAnchor);
      if (didAddNode!) {
        nodes.add(newNode);
      }
    }
  }

  // Sahneyi Temizle
  Future<void> onRemoveEverything() async {
    for (var anchor in anchors) {
      arAnchorManager.removeAnchor(anchor);
    }
    anchors = [];
    nodes = [];
  }

  @override
  void dispose() {
    arSessionManager.dispose();
    super.dispose();
  }
}
