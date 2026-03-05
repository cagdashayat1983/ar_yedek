// lib/screens/ar_mini_test_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Şık font eklendi
import 'package:ar_flutter_plugin_plus/ar_flutter_plugin_plus.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_plus/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import 'tutorial_screen.dart';

class ARMiniTestScreen extends StatefulWidget {
  final String glbAssetPath;

  const ARMiniTestScreen({super.key, required this.glbAssetPath});

  @override
  State<ARMiniTestScreen> createState() => _ARMiniTestScreenState();
}

class _ARMiniTestScreenState extends State<ARMiniTestScreen> {
  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARAnchorManager? _anchors;

  ARPlaneAnchor? _activeAnchor;
  ARNode? _activeNode;

  bool _placing = false;
  int _activePointers = 0;
  bool get _isMultiTouch => _activePointers > 1;

  DateTime _lastGestureAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _tapCooldownAfterGesture = Duration(milliseconds: 550);

  bool _tapLocked = false;
  bool _mirrored = false;
  bool _showPlanes = false;
  bool _flashOn = false;
  bool _isRecording = false;

  int _tiltMode = 0;

  double _scale = 1.0;
  double _rotYDeg = 0.0;

  double _liftMeters = 0.0;
  static const double _liftStep = 0.01;

  double _posX = 0.0;
  double _posZ = 0.0;
  static const double _dragToMeters = 0.0012;

  double _baseScale = 1.0;
  double _baseRotYDeg = 0.0;
  double _baseX = 0.0;
  double _baseZ = 0.0;

  double _opacity = 0.6;
  final bool _useIllusionMode = false;

  Timer? _updateTimer;
  bool _rebuilding = false;
  Timer? _toastTimer;
  String _toastText = "";

  bool get _hasModel => _activeNode != null && _activeAnchor != null;

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toastText = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _toastText = "");
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _toastTimer?.cancel();
    _session?.dispose();
    super.dispose();
  }

  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _session = sessionManager;
    _objects = objectManager;
    _anchors = anchorManager;

    _session!.onInitialize(
      showFeaturePoints: false,
      showPlanes: _showPlanes,
      showWorldOrigin: false,
      handleTaps: true,
    );
    _objects!.onInitialize();
    _session!.onPlaneOrPointTap = _onPlaneOrPointTap;

    if (!_useIllusionMode) {
      _showToast("Plane görünce dokun → model eklensin.");
    }
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;

  v.Vector3 _positionVec() => v.Vector3(_posX, _liftMeters, _posZ);

  v.Vector4 _combinedRotation() {
    final tiltDeg = _tiltMode == 0 ? 0.0 : (_tiltMode == 1 ? 15.0 : 30.0);

    final qBase = v.Quaternion.axisAngle(v.Vector3(1, 0, 0), -math.pi / 2);

    double yawDeg = (_rotYDeg + 180.0) % 360.0;
    if (_mirrored) yawDeg = (360.0 - yawDeg) % 360.0;

    final qYawWorld =
        v.Quaternion.axisAngle(v.Vector3(0, 1, 0), _degToRad(yawDeg));
    final qTilt =
        v.Quaternion.axisAngle(v.Vector3(1, 0, 0), _degToRad(tiltDeg));

    final q = (qYawWorld * (qBase * qTilt))..normalize();
    final w = q.w.clamp(-1.0, 1.0);
    final angle = 2.0 * math.acos(w);
    final s = math.sin(angle / 2.0);

    if (s.abs() < 1e-6) {
      return v.Vector4(0.0, 1.0, 0.0, 0.0);
    }

    final axis = v.Vector3(q.x / s, q.y / s, q.z / s)..normalize();
    return v.Vector4(axis.x, axis.y, axis.z, angle);
  }

  ARNode _buildNode() {
    return ARNode(
      type: NodeType.localGLTF2,
      uri: widget.glbAssetPath,
      scale: v.Vector3(_scale, _scale, _scale),
      position: _positionVec(),
      rotation: _combinedRotation(),
    );
  }

  void _debounceApply({int ms = 140}) {
    if (!_hasModel) return;
    _updateTimer?.cancel();
    _updateTimer = Timer(Duration(milliseconds: ms), () async {
      await _applyTransform();
    });
  }

  Future<void> _applyTransform() async {
    if (!_hasModel || _objects == null) return;
    if (_rebuilding) return;

    final node = _activeNode!;
    try {
      final dyn = _objects as dynamic;
      await dyn.updateNode(
        node,
        position: _positionVec(),
        scale: v.Vector3(_scale, _scale, _scale),
        rotation: _combinedRotation(),
      );
      return;
    } catch (_) {}

    await _rebuildSameAnchor();
  }

  Future<void> _rebuildSameAnchor() async {
    if (!_hasModel || _objects == null) return;
    if (_rebuilding) return;

    _rebuilding = true;
    final anchor = _activeAnchor!;
    final oldNode = _activeNode!;

    try {
      await _objects!.removeNode(oldNode);
      await Future.delayed(const Duration(milliseconds: 80));

      final newNode = _buildNode();
      final ok =
          (await _objects!.addNode(newNode, planeAnchor: anchor)) ?? false;
      if (ok) {
        _activeNode = newNode;
      }
    } catch (_) {
    } finally {
      _rebuilding = false;
    }
  }

  Future<void> _onPlaneOrPointTap(List<ARHitTestResult?> hits) async {
    if (_useIllusionMode) return;

    if (_isMultiTouch) return;

    final now = DateTime.now();
    if (now.difference(_lastGestureAt) < _tapCooldownAfterGesture) return;

    if (_hasModel) {
      _showToast("Zaten eklendi. Temizle ile sıfırla.");
      return;
    }

    if (_tapLocked ||
        _placing ||
        _anchors == null ||
        _objects == null ||
        hits.isEmpty) return;

    _placing = true;
    final valid = hits.where((h) => h != null).cast<ARHitTestResult>().toList();
    if (valid.isEmpty) {
      _placing = false;
      return;
    }

    final planeHits =
        valid.where((h) => h.type == ARHitTestResultType.plane).toList();
    final hit = planeHits.isNotEmpty ? planeHits.first : valid.first;

    try {
      final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final okAnchor = (await _anchors!.addAnchor(anchor)) ?? false;
      if (!okAnchor) {
        _placing = false;
        return;
      }

      final node = _buildNode();
      final okNode =
          (await _objects!.addNode(node, planeAnchor: anchor)) ?? false;
      if (!okNode) {
        await _anchors!.removeAnchor(anchor);
        _placing = false;
        return;
      }

      _activeAnchor = anchor;
      _activeNode = node;
      _showToast("✅ Masaya Yapıştırıldı!");
    } catch (e) {
      _showToast("❌ Hata: $e");
    } finally {
      _placing = false;
    }
  }

  Future<void> _clearAll() async {
    if (_objects == null || _anchors == null) return;
    HapticFeedback.mediumImpact();

    if (_activeNode != null) {
      try {
        await _objects!.removeNode(_activeNode!);
      } catch (_) {}
    }
    if (_activeAnchor != null) {
      try {
        await _anchors!.removeAnchor(_activeAnchor!);
      } catch (_) {}
    }

    setState(() {
      _activeNode = null;
      _activeAnchor = null;
      _scale = 1.0;
      _rotYDeg = 0.0;
      _liftMeters = 0.0;
      _posX = 0.0;
      _posZ = 0.0;
      _tiltMode = 0;
      _mirrored = false;
    });

    _showToast("Temizlendi. Tekrar dokunabilirsin.");
  }

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseRotYDeg = _rotYDeg;
    _baseX = _posX;
    _baseZ = _posZ;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_hasModel && !_useIllusionMode) return;

    if (_mirrored && _isMultiTouch) return;

    if (_isMultiTouch) {
      _lastGestureAt = DateTime.now();
      final newScale = (_baseScale * d.scale).clamp(0.05, 3.0);
      final deltaDeg = d.rotation * 180.0 / math.pi;

      final newRot = _useIllusionMode
          ? (_baseRotYDeg + deltaDeg) % 360.0
          : (_baseRotYDeg - deltaDeg) % 360.0;

      setState(() {
        _scale = newScale;
        _rotYDeg = newRot;
      });
      if (!_useIllusionMode) _debounceApply();
    } else {
      final dx =
          d.focalPointDelta.dx * (_useIllusionMode ? 1.0 : _dragToMeters);
      final dz =
          d.focalPointDelta.dy * (_useIllusionMode ? 1.0 : _dragToMeters);

      setState(() {
        _posX = _baseX + dx;
        _posZ = _baseZ + dz;
      });
      if (!_useIllusionMode) _debounceApply();
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (!_hasModel && !_useIllusionMode) return;
    _lastGestureAt = DateTime.now();
    if (!_useIllusionMode) _debounceApply(ms: 60);
  }

  void _toggleTilt() {
    HapticFeedback.selectionClick();
    setState(() => _tiltMode = (_tiltMode + 1) % 3);
    if (!_useIllusionMode) _debounceApply(ms: 80);
  }

  void _toggleMirror() {
    HapticFeedback.selectionClick();
    setState(() => _mirrored = !_mirrored);
    if (!_useIllusionMode) _debounceApply(ms: 80);
  }

  void _rotPlus90() {
    HapticFeedback.selectionClick();
    setState(() => _rotYDeg = _useIllusionMode
        ? (_rotYDeg + 90.0) % 360.0
        : (_rotYDeg - 90.0) % 360.0);
    if (!_useIllusionMode) _debounceApply(ms: 80);
  }

  void _liftUp() {
    HapticFeedback.selectionClick();
    setState(() => _liftMeters = (_liftMeters + _liftStep).clamp(-0.30, 0.60));
    if (!_useIllusionMode) _debounceApply(ms: 50);
  }

  void _liftDown() {
    HapticFeedback.selectionClick();
    setState(() => _liftMeters = (_liftMeters - _liftStep).clamp(-0.30, 0.60));
    if (!_useIllusionMode) _debounceApply(ms: 50);
  }

  @override
  Widget build(BuildContext context) {
    String pngPath = widget.glbAssetPath
        .replaceAll('assets/models/', 'assets/templates/')
        .replaceAll('.glb', '.png');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => setState(() => _activePointers++),
            onPointerUp: (_) => setState(
                () => _activePointers = (_activePointers - 1).clamp(0, 10)),
            onPointerCancel: (_) => setState(
                () => _activePointers = (_activePointers - 1).clamp(0, 10)),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: Stack(
                children: [
                  ARView(
                    onARViewCreated: _onARViewCreated,
                    planeDetectionConfig:
                        PlaneDetectionConfig.horizontalAndVertical,
                  ),
                ],
              ),
            ),
          ),

          // ÜST BAR (Geri, Normal Mod'a Geçiş, Silme)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final cameras = await availableCameras();
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TutorialScreen(
                                  title: "Çizim Şablonu",
                                  imagePaths: [pngPath],
                                  cameras: cameras,
                                  isLocalFile: false,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.cyanAccent,
                            size: 18,
                          ),
                          label: Text(
                            "NORMAL MOD",
                            style: GoogleFonts.poppins(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        const Spacer(),
                        if (_toastText.isNotEmpty)
                          Expanded(
                            child: Text(
                              _toastText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ YENİ ALT MENÜ (TUTORIAL_SCREEN STİLİ)
          Positioned(
            bottom: 0,
            left: 10,
            right: 10,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.40),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _controlBtn(
                                  icon: _tapLocked
                                      ? Icons.lock_rounded
                                      : Icons.lock_open_rounded,
                                  label: _tapLocked ? "Locked" : "Lock",
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _tapLocked = !_tapLocked);
                                  },
                                  active: _tapLocked,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.flip_rounded,
                                  label: "Flip",
                                  onPressed: _toggleMirror,
                                  active: _mirrored,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.rotate_90_degrees_ccw_rounded,
                                  label: "Rotate",
                                  onPressed: _rotPlus90,
                                  active: _rotYDeg != 0.0,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.view_in_ar_rounded,
                                  label: _tiltMode == 0
                                      ? "Tilt"
                                      : "Tilt ${_tiltMode}x",
                                  onPressed: _toggleTilt,
                                  active: _tiltMode > 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.arrow_downward_rounded,
                                  label: "Y -",
                                  onPressed: _liftDown,
                                  active: false,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.arrow_upward_rounded,
                                  label: "Y +",
                                  onPressed: _liftUp,
                                  active: false,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ KUSURSUZ GLASSMORPHISM BUTON MİMARİSİ
  Widget _controlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: active
              ? Colors.white.withOpacity(0.20)
              : Colors.white.withOpacity(0.08),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600))
        ],
      ),
    );
  }
}
