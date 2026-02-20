import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
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

  // Multi-touch klon fix
  int _activePointers = 0;
  bool get _isMultiTouch => _activePointers > 1;

  // Gesture sonrası “fake tap”leri blokla
  DateTime _lastGestureAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _tapCooldownAfterGesture = Duration(milliseconds: 550);

  // UI state
  bool _tapLocked = false;
  bool _mirrored = false;

  // Note8: plane çizimi kapalı başlat
  bool _showPlanes = false;

  bool _flashOn = false; // ARView torch çoğu cihazda yok
  bool _isRecording = false; // ARView kayıt API yok

  int _gridMode = 0; // 0 / 3 / 4 / 5
  int _tiltMode = 0; // 0 / 1 / 2

  // Transform
  double _scale = 0.6;
  double _rotYDeg = 0.0;

  // Zemine oturma için default negatif lift
  double _liftMeters = -0.03;
  static const double _liftStep = 0.01; // 1 cm

  // Drag X/Z
  double _posX = 0.0;
  double _posZ = 0.0;
  static const double _dragToMeters = 0.0012;

  // Gesture base
  double _baseScale = 0.6;
  double _baseRotYDeg = 0.0;
  double _baseX = 0.0;
  double _baseZ = 0.0;

  // Debounce update
  Timer? _updateTimer;

  // Rebuild kilidi (klon olmasın)
  bool _rebuilding = false;

  Timer? _toastTimer;
  String _toastText = "";

  bool get _hasModel => _activeNode != null && _activeAnchor != null;

  // ✅ Bu düzeltme: modelin “ters gelmesini” sabitler (plane üstünde 180° flip)
  // Eğer bir gün terslik tamamen düzelirse bunu 0 yapabilirsin.
  static const double _inPlaneFlipRad = math.pi; // 180°

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

    _showToast("Plane görünce dokun → model 1 kez. Y- ile zemine oturt.");
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;

  v.Vector3 _positionVec() => v.Vector3(_posX, _liftMeters, _posZ);

  // ✅ Sağlam quaternion → axis-angle
  v.Vector4 _quatToAxisAngle(v.Quaternion q) {
    q.normalize();
    final w = q.w.clamp(-1.0, 1.0);
    final angle = 2.0 * math.acos(w);
    final s = math.sin(angle / 2.0);

    if (s.abs() < 1e-6) {
      return v.Vector4(0.0, 1.0, 0.0, 0.0);
    }

    final axis = v.Vector3(q.x / s, q.y / s, q.z / s)..normalize();
    return v.Vector4(axis.x, axis.y, axis.z, angle);
  }

  // ✅ Yatay kilit: Pitch/Roll sabit, sadece Yaw + Scale değişir
  // ✅ Ters gelme fix: plane üstünde 180° flip ekli
  v.Vector4 _combinedRotation() {
    final tiltDeg = _tiltMode == 0 ? 0.0 : (_tiltMode == 1 ? 15.0 : 30.0);

    // Yatay duruş (zemine yatır)
    final qBase = v.Quaternion.axisAngle(
      v.Vector3(1, 0, 0),
      -math.pi / 2,
    ); // -90° X

    // ✅ Ters gelme düzeltmesi: yaw'a +180 ekle
    double yawDeg = (_rotYDeg + 180.0) % 360.0;

    // Mirror: yaw yönünü ters çevir
    if (_mirrored) yawDeg = (360.0 - yawDeg) % 360.0;

    // ✅ Yaw HER ZAMAN world-up (0,1,0) ekseninde (dikleşmeyi engeller)
    final qYawWorld = v.Quaternion.axisAngle(
      v.Vector3(0, 1, 0),
      _degToRad(yawDeg),
    );

    // Tilt (opsiyonel)
    final qTilt = v.Quaternion.axisAngle(
      v.Vector3(1, 0, 0),
      _degToRad(tiltDeg),
    );

    // ✅ Sıra: önce (base*tilt) ile yatay ekseni kur, sonra world yaw ile sadece kendi etrafında döndür
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
      } else {
        _showToast("❌ Güncelleme başarısız (node eklenemedi)");
      }
    } catch (_) {
      _showToast("❌ Güncelleme hatası");
    } finally {
      _rebuilding = false;
    }
  }

  Future<void> _onPlaneOrPointTap(List<ARHitTestResult?> hits) async {
    if (_isMultiTouch) return;

    final now = DateTime.now();
    if (now.difference(_lastGestureAt) < _tapCooldownAfterGesture) return;

    if (_hasModel) {
      _showToast("Zaten eklendi. Temizle ile sıfırla.");
      return;
    }

    if (_tapLocked) return;
    if (_placing) return;
    if (_anchors == null || _objects == null) return;
    if (hits.isEmpty) return;

    _placing = true;

    final valid = hits.where((h) => h != null).cast<ARHitTestResult>().toList();
    if (valid.isEmpty) {
      _placing = false;
      return;
    }

    final planeHits = valid
        .where((h) => h.type == ARHitTestResultType.plane)
        .toList();
    final hit = planeHits.isNotEmpty ? planeHits.first : valid.first;

    try {
      final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final okAnchor = (await _anchors!.addAnchor(anchor)) ?? false;
      if (!okAnchor) {
        _showToast("❌ Anchor eklenemedi");
        _placing = false;
        return;
      }

      final node = _buildNode();
      final okNode =
          (await _objects!.addNode(node, planeAnchor: anchor)) ?? false;
      if (!okNode) {
        await _anchors!.removeAnchor(anchor);
        _showToast("❌ Model eklenemedi");
        _placing = false;
        return;
      }

      _activeAnchor = anchor;
      _activeNode = node;

      _showToast("✅ Eklendi. 2 parmak: scale + kendi etrafında dön (yaw)");
    } catch (e) {
      _showToast("❌ Hata: $e");
    } finally {
      _placing = false;
    }
  }

  Future<void> _clearAll() async {
    if (_objects == null || _anchors == null) return;

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

      _scale = 0.6;
      _rotYDeg = 0.0;
      _liftMeters = -0.03;
      _posX = 0.0;
      _posZ = 0.0;

      _tiltMode = 0;
      _mirrored = false;
    });

    _showToast("Temizlendi. Tekrar dokunabilirsin.");
  }

  // Gestures
  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseRotYDeg = _rotYDeg;
    _baseX = _posX;
    _baseZ = _posZ;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_hasModel) return;

    if (_isMultiTouch) {
      _lastGestureAt = DateTime.now();

      final newScale = (_baseScale * d.scale).clamp(0.05, 2.0);

      // ✅ Pitch/Roll kilitli → sadece YAW (kendi etrafında) + SCALE
      final deltaDeg = d.rotation * 180.0 / math.pi;
      final newRot = (_baseRotYDeg + deltaDeg) % 360.0;

      setState(() {
        _scale = newScale;
        _rotYDeg = newRot;
      });

      _debounceApply();
    } else {
      final dx = d.focalPointDelta.dx * _dragToMeters;
      final dz = d.focalPointDelta.dy * _dragToMeters;

      setState(() {
        _posX = _baseX + dx;
        _posZ = _baseZ + dz;
      });

      _debounceApply();
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (!_hasModel) return;
    _lastGestureAt = DateTime.now();
    _debounceApply(ms: 60);
  }

  // Buttons
  void _toggleGrid() {
    setState(() {
      if (_gridMode == 0) {
        _gridMode = 3;
      } else if (_gridMode == 3) {
        _gridMode = 4;
      } else if (_gridMode == 4) {
        _gridMode = 5;
      } else {
        _gridMode = 0;
      }
    });
    _showToast(_gridMode == 0 ? "Izgara kapalı" : "Izgara: ${_gridMode}x");
  }

  void _toggleTilt() {
    setState(() => _tiltMode = (_tiltMode + 1) % 3);
    _debounceApply(ms: 80);
  }

  void _toggleMirror() {
    setState(() => _mirrored = !_mirrored);
    _debounceApply(ms: 80);
  }

  void _rotPlus90() {
    setState(() => _rotYDeg = (_rotYDeg + 90.0) % 360.0);
    _debounceApply(ms: 80);
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
    _showToast("ARView flash kontrolünü çoğu cihaz desteklemez.");
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    _showToast("ARView video kaydı yok. Ekran kaydı kullan.");
  }

  void _liftUp() {
    setState(() => _liftMeters = (_liftMeters + _liftStep).clamp(-0.30, 0.60));
    _showToast("Lift: ${_liftMeters.toStringAsFixed(3)} m");
    _debounceApply(ms: 50);
  }

  void _liftDown() {
    setState(() => _liftMeters = (_liftMeters - _liftStep).clamp(-0.30, 0.60));
    _showToast("Lift: ${_liftMeters.toStringAsFixed(3)} m");
    _debounceApply(ms: 50);
  }

  void _togglePlanes() {
    setState(() => _showPlanes = !_showPlanes);
    _showToast(
      _showPlanes ? "Plane açık (ağır olabilir)" : "Plane kapalı (hızlı)",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => setState(() => _activePointers++),
            onPointerUp: (_) => setState(
              () => _activePointers = (_activePointers - 1).clamp(0, 10),
            ),
            onPointerCancel: (_) => setState(
              () => _activePointers = (_activePointers - 1).clamp(0, 10),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: ARView(
                onARViewCreated: _onARViewCreated,
                planeDetectionConfig:
                    PlaneDetectionConfig.horizontalAndVertical,
              ),
            ),
          ),
          if (_gridMode > 0)
            IgnorePointer(
              child: Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: GridPainter(gridCount: _gridMode),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: _togglePlanes,
                          icon: Icon(
                            _showPlanes ? Icons.layers : Icons.layers_clear,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        if (_toastText.isNotEmpty)
                          Text(
                            _toastText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: _clearAll,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.70),
                        Colors.black.withOpacity(0.50),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _btn(
                          _isRecording
                              ? Icons.stop_circle_outlined
                              : Icons.videocam,
                          _isRecording ? "Durdur" : "Kaydet",
                          _isRecording,
                          Colors.redAccent,
                          _toggleRecording,
                        ),
                        const SizedBox(width: 8),
                        _btn(
                          _tapLocked ? Icons.lock : Icons.lock_open,
                          "Kilit",
                          _tapLocked,
                          Colors.redAccent,
                          () => setState(() => _tapLocked = !_tapLocked),
                        ),
                        const SizedBox(width: 8),
                        _btn(
                          Icons.view_in_ar,
                          _tiltMode == 0 ? "Eğim" : "${_tiltMode}x",
                          _tiltMode > 0,
                          Colors.orangeAccent,
                          _toggleTilt,
                        ),
                        const SizedBox(width: 8),
                        _btn(
                          Icons.flip,
                          "Ayna",
                          _mirrored,
                          Colors.blueAccent,
                          _toggleMirror,
                        ),
                        const SizedBox(width: 8),
                        _btn(
                          Icons.rotate_90_degrees_cw,
                          "+90°",
                          false,
                          Colors.white,
                          _rotPlus90,
                        ),
                        const SizedBox(width: 8),
                        _btn(
                          Icons.arrow_downward,
                          "Y-",
                          true,
                          Colors.cyanAccent,
                          _liftDown,
                        ),
                        const SizedBox(width: 8),
                        _btn(
                          Icons.arrow_upward,
                          "Y+",
                          true,
                          Colors.cyanAccent,
                          _liftUp,
                        ),
                        const SizedBox(width: 8),
                        _btn(
                          Icons.grid_on,
                          _gridMode == 0 ? "Izgara" : "${_gridMode}x",
                          _gridMode > 0,
                          Colors.greenAccent,
                          _toggleGrid,
                        ),
                        const SizedBox(width: 8),
                        _btn(
                          _flashOn ? Icons.flash_on : Icons.flash_off,
                          "Flaş",
                          _flashOn,
                          Colors.amber,
                          _toggleFlash,
                        ),
                      ],
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

  Widget _btn(
    IconData icon,
    String label,
    bool isActive,
    Color activeColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [activeColor, activeColor.withOpacity(0.6)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.06),
                      ],
                    ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? activeColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.10),
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white54,
              fontSize: 9,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final int gridCount;
  GridPainter({required this.gridCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final w = size.width / gridCount;
    final h = size.height / gridCount;

    for (int i = 1; i < gridCount; i++) {
      canvas.drawLine(Offset(w * i, 0), Offset(w * i, size.height), paint);
      canvas.drawLine(Offset(0, h * i), Offset(size.width, h * i), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
