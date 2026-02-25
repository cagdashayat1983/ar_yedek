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
  int _activePointers = 0;
  bool get _isMultiTouch => _activePointers > 1;

  DateTime _lastGestureAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _tapCooldownAfterGesture = Duration(milliseconds: 550);

  bool _tapLocked = false;
  bool _mirrored = false;
  bool _showPlanes = false;
  bool _flashOn = false;
  bool _isRecording = false;

  int _gridMode = 0;
  int _tiltMode = 0;

  // ✅ ÇÖZÜM 1: Başlangıç boyutu 0.6'dan 1.0'a çıkarıldı. (Direkt %100 boyutunda başlar)
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
  bool _useIllusionMode = true; // Direkt Çizim Modu

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

    final qBase = v.Quaternion.axisAngle(
      v.Vector3(1, 0, 0),
      -math.pi / 2,
    );

    double yawDeg = (_rotYDeg + 180.0) % 360.0;
    if (_mirrored) yawDeg = (360.0 - yawDeg) % 360.0;

    final qYawWorld = v.Quaternion.axisAngle(
      v.Vector3(0, 1, 0),
      _degToRad(yawDeg),
    );

    final qTilt = v.Quaternion.axisAngle(
      v.Vector3(1, 0, 0),
      _degToRad(tiltDeg),
    );

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
      _scale = 1.0; // SIFIRLARKEN DE YİNE BÜYÜK OLSUN
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

  void _toggleGrid() {
    setState(() {
      if (_gridMode == 0)
        _gridMode = 3;
      else if (_gridMode == 3)
        _gridMode = 4;
      else if (_gridMode == 4)
        _gridMode = 5;
      else
        _gridMode = 0;
    });
  }

  void _toggleTilt() {
    setState(() => _tiltMode = (_tiltMode + 1) % 3);
    if (!_useIllusionMode) _debounceApply(ms: 80);
  }

  void _toggleMirror() {
    setState(() => _mirrored = !_mirrored);
    if (!_useIllusionMode) _debounceApply(ms: 80);
  }

  void _rotPlus90() {
    setState(() => _rotYDeg = _useIllusionMode
        ? (_rotYDeg + 90.0) % 360.0
        : (_rotYDeg - 90.0) % 360.0);
    if (!_useIllusionMode) _debounceApply(ms: 80);
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
  }

  void _liftUp() {
    setState(() => _liftMeters = (_liftMeters + _liftStep).clamp(-0.30, 0.60));
    if (!_useIllusionMode) _debounceApply(ms: 50);
  }

  void _liftDown() {
    setState(() => _liftMeters = (_liftMeters - _liftStep).clamp(-0.30, 0.60));
    if (!_useIllusionMode) _debounceApply(ms: 50);
  }

  void _togglePlanes() => setState(() => _showPlanes = !_showPlanes);

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
                  if (_useIllusionMode)
                    Positioned.fill(
                      child: Center(
                        child: Opacity(
                          opacity: _opacity,
                          child: Transform(
                            alignment: FractionalOffset.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..translate(_posX, _posZ)
                              ..rotateX(_degToRad(_tiltMode == 0
                                  ? 65.0
                                  : (_tiltMode == 1 ? 45.0 : 0.0)))
                              ..rotateZ(_degToRad(_rotYDeg))
                              ..scale(_scale, _scale, 1.0),
                            child: Transform.flip(
                              flipX: _mirrored,
                              // ✅ ÇÖZÜM 2: Resim ekranın %90'ını kaplayacak şekilde DEVASA ve NET açılır. Asla bozulmaz!
                              child: Image.asset(
                                pngPath,
                                width: MediaQuery.of(context).size.width * 0.9,
                                fit: BoxFit.contain,
                                errorBuilder: (c, o, s) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                    size: 100),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await _clearAll();
                            setState(
                                () => _useIllusionMode = !_useIllusionMode);
                            if (!_useIllusionMode) {
                              _showToast("AR Modu: Zemine dokun.");
                            }
                          },
                          icon: Icon(
                            _useIllusionMode
                                ? Icons.view_in_ar
                                : Icons.edit_note,
                            color: Colors.cyanAccent,
                          ),
                          label: Text(
                            _useIllusionMode ? "AR'A GEÇ" : "ÇİZİME GEÇ",
                            style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        if (_toastText.isNotEmpty)
                          Text(
                            _toastText,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_useIllusionMode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.opacity,
                            color: Colors.white54, size: 20),
                        Expanded(
                          child: Slider(
                            value: _opacity,
                            min: 0.1,
                            max: 1.0,
                            activeColor: Colors.cyanAccent,
                            inactiveColor: Colors.white24,
                            onChanged: (val) => setState(() => _opacity = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.70),
                            Colors.black.withOpacity(0.50)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(35),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            if (_useIllusionMode) ...[
                              _btn(
                                  _isRecording
                                      ? Icons.stop_circle_outlined
                                      : Icons.videocam,
                                  _isRecording ? "Durdur" : "Kaydet",
                                  _isRecording,
                                  Colors.redAccent,
                                  _toggleRecording),
                              const SizedBox(width: 8),
                            ],
                            _btn(
                                _tapLocked ? Icons.lock : Icons.lock_open,
                                "Kilit",
                                _tapLocked,
                                Colors.redAccent,
                                () => setState(() => _tapLocked = !_tapLocked)),
                            const SizedBox(width: 8),
                            _btn(
                                Icons.view_in_ar,
                                _tiltMode == 0 ? "Eğim" : "${_tiltMode}x",
                                _tiltMode > 0,
                                Colors.orangeAccent,
                                _toggleTilt),
                            const SizedBox(width: 8),
                            _btn(Icons.flip, "Ayna", _mirrored,
                                Colors.blueAccent, _toggleMirror),
                            const SizedBox(width: 8),
                            _btn(Icons.rotate_90_degrees_cw, "+90°", false,
                                Colors.white, _rotPlus90),
                            const SizedBox(width: 8),
                            _btn(Icons.arrow_downward, "Y-", true,
                                Colors.cyanAccent, _liftDown),
                            const SizedBox(width: 8),
                            _btn(Icons.arrow_upward, "Y+", true,
                                Colors.cyanAccent, _liftUp),
                            const SizedBox(width: 8),
                            _btn(
                                Icons.grid_on,
                                _gridMode == 0 ? "Izgara" : "${_gridMode}x",
                                _gridMode > 0,
                                Colors.greenAccent,
                                _toggleGrid),
                            if (_useIllusionMode) ...[
                              const SizedBox(width: 8),
                              _btn(_flashOn ? Icons.flash_on : Icons.flash_off,
                                  "Flaş", _flashOn, Colors.amber, _toggleFlash),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String label, bool isActive, Color activeColor,
      VoidCallback onTap) {
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
                      colors: [activeColor, activeColor.withOpacity(0.6)])
                  : LinearGradient(colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.06)
                    ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isActive
                      ? activeColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.10),
                  width: 1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                          color: activeColor.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2))
                    ]
                  : [],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isActive ? activeColor : Colors.white54,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
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
