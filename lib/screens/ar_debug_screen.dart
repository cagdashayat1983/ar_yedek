import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_plus/ar_flutter_plugin_plus.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_plus/models/ar_hittest_result.dart';

class ARDebugScreen extends StatefulWidget {
  const ARDebugScreen({super.key});

  @override
  State<ARDebugScreen> createState() => _ARDebugScreenState();
}

class _ARDebugScreenState extends State<ARDebugScreen> {
  ARSessionManager? _session;
  ARAnchorManager? _anchors;

  final List<ARAnchor> _addedAnchors = [];
  String _status = "Zemini tara ve ekrana dokun.";
  bool _busy = false;

  void _log(String s) => setState(() => _status = s);

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    _session = sessionManager;
    _anchors = anchorManager;

    try {
      await sessionManager.onInitialize(
        showPlanes: true,
        handleTaps: true,
        showWorldOrigin: false,
        showFeaturePoints: false,
      );

      await objectManager.onInitialize();
      sessionManager.onPlaneOrPointTap = _onTap;

      _log("AR hazır ✅ Zemini tara, plane çıkmalı.");
    } catch (e) {
      _log("AR init hatası: $e");
    }
  }

  Future<void> _onTap(List<ARHitTestResult?> hits) async {
    if (_busy || _anchors == null) return;

    final valid = hits.where((h) => h != null).cast<ARHitTestResult>().toList();

    if (valid.isEmpty) {
      _log("Hit yok ❌ Zemini biraz daha tara.");
      return;
    }

    final planeHits =
        valid.where((h) => h.type == ARHitTestResultType.plane).toList();

    final hit = planeHits.isNotEmpty ? planeHits.first : valid.first;

    setState(() => _busy = true);

    try {
      final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final bool? ok = await _anchors!.addAnchor(anchor);

      if (ok == true) {
        _addedAnchors.add(anchor);
        _log("Anchor eklendi ✅ (${_addedAnchors.length})");
      } else {
        _log("Anchor eklenemedi ❌ (ARCore/plane sorunu olabilir)");
      }
    } catch (e) {
      _log("Tap/Anchor hatası: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_anchors == null) return;
    for (final a in List<ARAnchor>.from(_addedAnchors)) {
      await _anchors!.removeAnchor(a);
    }
    _addedAnchors.clear();
    _log("Temizlendi.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AR Debug"),
        actions: [
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          )
        ],
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (_busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
