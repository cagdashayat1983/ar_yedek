import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HizliARResim(),
  ));
}

class HizliARResim extends StatefulWidget {
  const HizliARResim({super.key});

  @override
  State<HizliARResim> createState() => _HizliARResimState();
}

class _HizliARResimState extends State<HizliARResim> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hızlı Tasarım AR (Resim)')),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                "Masayı tara, mavi çizgiler çıkınca dokun ve resmini seç!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
          showFeaturePoints: true,
          showPlanes: true,
          showWorldOrigin: false,
        );
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onPlaneOrPointTap = (hitTestResults) async {
      if (hitTestResults.isEmpty) return;

      final singleHitTestResult = hitTestResults.first;
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null &&
          this.arAnchorManager != null &&
          this.arObjectManager != null) {
        var newAnchor =
            ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
        bool? didAddAnchor = await this.arAnchorManager!.addAnchor(newAnchor);

        if (didAddAnchor == true) {
          // DÜZELTİLEN SATIR: localGLB yerine fileSystemAppFolderGLB kullanıldı
          var newNode = ARNode(
            type: NodeType.fileSystemAppFolderGLB,
            uri: image.path,
            scale: vector.Vector3(0.1, 0.1, 0.1),
            position: vector.Vector3(0, 0, 0),
          );

          await this.arObjectManager!.addNode(newNode, planeAnchor: newAnchor);
        }
      }
    };
  }

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }
}
