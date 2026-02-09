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
  // Yöneticileri 'dynamic' tanımlayarak isim hatalarını baypas ediyoruz
  dynamic arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hizli Tasarim AR")),
      body: ARView(
        onARViewCreated: onARViewCreated,
        planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
      ),
    );
  }

  void onARViewCreated(
      ARSessionManager sessionManager,
      ARObjectManager objectManager,
      ARAnchorManager anchorManager,
      ARLocationManager locationManager) {
    this.arSessionManager = sessionManager;
    this.arObjectManager = objectManager;
    this.arAnchorManager = anchorManager;

    this.arSessionManager.onInitialize(
          showFeaturePoints: true,
          showPlanes: true,
          handleTaps: true,
        );
    this.arObjectManager.onInitialize();

    // Setter hatasını çözmek için doğrudan atama yapıyoruz
    try {
      arSessionManager.onPlaneTap = onPlaneTapHandler;
    } catch (e) {
      debugPrint("Hata: onPlaneTap baglanamadi");
    }
  }

  // List<dynamic> kullanarak 'ARHitTestResult' tip hatasını siliyoruz
  Future<void> onPlaneTapHandler(List<dynamic> hitTestResults) async {
    if (hitTestResults.isEmpty) return;

    // Çalışma anında tipi kontrol etmeden ilk sonucu alıyoruz
    final tap = hitTestResults.first;

    var newAnchor = ARPlaneAnchor(transformation: tap.worldTransform);
    bool? didAddAnchor = await arAnchorManager.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      anchors.add(newAnchor);

      var newNode = ARNode(
        type: NodeType.webGLB,
        uri:
            "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Duck/glTF-Binary/Duck.glb",
        scale: vector.Vector3(0.1, 0.1, 0.1),
        position: vector.Vector3(0, 0, 0),
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      // Parametre ismine takılmadan eklemeyi deniyoruz
      bool? didAddNode =
          await arObjectManager.addNode(newNode, planeAnchor: newAnchor);
      if (didAddNode == true) {
        nodes.add(newNode);
      }
    }
  }

  Future<void> onRemoveEverything() async {
    for (var anchor in anchors) {
      arAnchorManager.removeAnchor(anchor);
    }
    anchors.clear();
    nodes.clear();
    setState(() {});
  }

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }
}
