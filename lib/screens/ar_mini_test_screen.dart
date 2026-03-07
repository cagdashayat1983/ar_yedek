// lib/screens/ar_mini_test_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

  const ARMiniTestScreen({
    super.key,
    required this.glbAssetPath,
  });

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
  bool _tapLocked = false;
  bool _mirrored = false;
  bool _showPlanes = true;

  int _tiltMode = 0;

  double _scale = 0.48;
  double _rotYDeg = 0.0;

  double _liftMeters = 0.0;
  static const double _liftStep = 0.01;

  double _posX = 0.0;
  double _posZ = 0.0;
  static const double _dragToMeters = 0.0012;

  double _baseScale = 0.48;
  double _baseRotYDeg = 0.0;

  final Set<int> _pointerIds = <int>{};
  bool get _isMultiTouch => _pointerIds.length > 1;

  Offset? _lastSingleFocalPoint;
  DateTime _lastGestureAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _tapCooldownAfterGesture = Duration(milliseconds: 450);

  Timer? _updateTimer;
  Timer? _positionTimer;
  Timer? _toastTimer;

  bool _rebuilding = false;
  bool _gestureInProgress = false;
  bool _preferRebuildOnly = false;

  String _toastText = "";

  bool get _hasModel => _activeNode != null && _activeAnchor != null;

  bool get _isRemoteGlb {
    final p = widget.glbAssetPath.toLowerCase();
    return p.startsWith('http://') || p.startsWith('https://');
  }

  bool get _isLocalGlb {
    final p = widget.glbAssetPath.toLowerCase();
    return p.endsWith('.glb') && !_isRemoteGlb;
  }

  String get _pngPath {
    if (_isRemoteGlb) {
      try {
        final uri = Uri.parse(widget.glbAssetPath);
        final segments = uri.pathSegments;

        if (segments.length >= 3 && segments.first == 'model') {
          final folder = segments[1];
          final file = Uri.decodeComponent(segments.sublist(2).join('/'));
          final pngFile = file.replaceAll(
            RegExp(r'\.glb$', caseSensitive: false),
            '.png',
          );

          return Uri(
            scheme: uri.scheme,
            host: uri.host,
            port: uri.hasPort ? uri.port : null,
            path: '/image',
            queryParameters: {
              'folder': folder,
              'file': pngFile,
            },
          ).toString();
        }
      } catch (_) {}

      return widget.glbAssetPath.replaceAll(
        RegExp(r'\.glb$', caseSensitive: false),
        '.png',
      );
    }

    return widget.glbAssetPath
        .replaceAll('assets/models/', 'assets/templates/')
        .replaceAll(RegExp(r'\.glb$', caseSensitive: false), '.png');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final size = MediaQuery.of(context).size;
    final shortest = math.min(size.width, size.height);

    double suggestedScale;
    if (shortest <= 360) {
      suggestedScale = 0.38;
    } else if (shortest <= 430) {
      suggestedScale = 0.48;
    } else {
      suggestedScale = 0.58;
    }

    if (!_hasModel) {
      _scale = suggestedScale;
      _baseScale = suggestedScale;
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _positionTimer?.cancel();
    _toastTimer?.cancel();
    _pointerIds.clear();
    _safeDisposeSession();
    super.dispose();
  }

  Future<void> _safeDisposeSession() async {
    try {
      if (_activeNode != null && _objects != null) {
        try {
          await _objects!.removeNode(_activeNode!);
        } catch (e) {
          debugPrint("removeNode dispose hatası: $e");
        }
      }

      if (_activeAnchor != null && _anchors != null) {
        try {
          await _anchors!.removeAnchor(_activeAnchor!);
        } catch (e) {
          debugPrint("removeAnchor dispose hatası: $e");
        }
      }
    } catch (e) {
      debugPrint("AR cleanup genel hata: $e");
    }

    try {
      _session?.dispose();
    } catch (e) {
      debugPrint("session dispose hatası: $e");
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toastText = msg);

    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _toastText = "");
    });
  }

  void _log(String msg) {
    debugPrint("[ARMiniTestScreen] $msg");
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

    _log("MODEL URL => ${widget.glbAssetPath}");
    _showToast("Düzlem görünce dokun ve modeli yerleştir.");
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;

  v.Vector3 _positionVec() => v.Vector3(_posX, _liftMeters, _posZ);

  v.Vector4 _combinedRotation() {
    final tiltDeg = _tiltMode == 0 ? 0.0 : (_tiltMode == 1 ? 15.0 : 30.0);

    final qBase = v.Quaternion.axisAngle(v.Vector3(1, 0, 0), -math.pi / 2);

    double yawDeg = (_rotYDeg + 180.0) % 360.0;
    if (_mirrored) {
      yawDeg = (360.0 - yawDeg) % 360.0;
    }

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
    late final NodeType nodeType;

    if (_isRemoteGlb) {
      nodeType = NodeType.webGLB;
    } else if (_isLocalGlb) {
      nodeType = NodeType.localGLB;
    } else {
      nodeType = NodeType.localGLTF2;
    }

    return ARNode(
      type: nodeType,
      uri: widget.glbAssetPath,
      scale: v.Vector3(_scale, _scale, _scale),
      position: _positionVec(),
      rotation: _combinedRotation(),
    );
  }

  bool get _allowLiveUpdateDuringGesture =>
      !_isRemoteGlb && !_preferRebuildOnly;

  void _queueTransformCommit({
    int ms = 90,
    bool forceRebuild = false,
  }) {
    if (!_hasModel) return;

    _updateTimer?.cancel();
    _updateTimer = Timer(Duration(milliseconds: ms), () async {
      await _commitTransform(forceRebuild: forceRebuild);
    });
  }

  Future<void> _commitTransform({bool forceRebuild = false}) async {
    if (!_hasModel || _objects == null) return;
    if (_rebuilding) return;
    if (_gestureInProgress && !forceRebuild) return;

    if (_isRemoteGlb || _preferRebuildOnly || forceRebuild) {
      await _rebuildSameAnchor();
      return;
    }

    final node = _activeNode!;

    try {
      final dyn = _objects as dynamic;
      await dyn.updateNode(
        node,
        position: _positionVec(),
        scale: v.Vector3(_scale, _scale, _scale),
        rotation: _combinedRotation(),
      );
    } catch (e) {
      _preferRebuildOnly = true;
      _log("updateNode başarısız, rebuildOnly moduna geçildi: $e");
      await _rebuildSameAnchor();
    }
  }

  void _queuePositionCommit({int ms = 180}) {
    if (!_hasModel) return;

    _positionTimer?.cancel();
    _positionTimer = Timer(Duration(milliseconds: ms), () async {
      await _commitPositionOnly();
    });
  }

  Future<void> _commitPositionOnly() async {
    if (!_hasModel || _objects == null) return;
    if (_rebuilding) return;

    final node = _activeNode!;

    try {
      final dyn = _objects as dynamic;
      await dyn.updateNode(
        node,
        position: _positionVec(),
      );
      return;
    } catch (e) {
      _log("positionOnly update başarısız, rebuild fallback: $e");
    }

    await _rebuildSameAnchor();
  }

  Future<void> _rebuildSameAnchor() async {
    if (!_hasModel || _objects == null || _anchors == null) return;
    if (_rebuilding) return;

    _rebuilding = true;
    final anchor = _activeAnchor!;
    final oldNode = _activeNode!;

    try {
      try {
        await _objects!.removeNode(oldNode);
      } catch (e) {
        _log("removeNode rebuild hatası: $e");
      }

      await Future.delayed(
        Duration(milliseconds: _isRemoteGlb ? 180 : 90),
      );

      final newNode = _buildNode();
      final ok =
          (await _objects!.addNode(newNode, planeAnchor: anchor)) ?? false;

      if (ok) {
        _activeNode = newNode;
      } else {
        _showToast("Model güncellenemedi.");
      }
    } catch (e) {
      _log("rebuild hatası: $e");
      _showToast("Model güncelleme hatası.");
    } finally {
      _rebuilding = false;
    }
  }

  void _applyAfterButtonChange({int ms = 60}) {
    if (!_hasModel) return;

    if (_isRemoteGlb || _preferRebuildOnly) {
      _queueTransformCommit(ms: 20, forceRebuild: true);
    } else {
      _queueTransformCommit(ms: ms);
    }
  }

  Future<void> _onPlaneOrPointTap(List<ARHitTestResult?> hits) async {
    if (_tapLocked) {
      _showToast("Kilit açık. Önce kilidi kapat.");
      return;
    }

    if (_isMultiTouch) return;

    final now = DateTime.now();
    if (now.difference(_lastGestureAt) < _tapCooldownAfterGesture) return;

    if (_hasModel) {
      _showToast("Model zaten eklendi. Sil ile sıfırla.");
      return;
    }

    if (_placing || _anchors == null || _objects == null || hits.isEmpty) {
      return;
    }

    final validHits = hits.whereType<ARHitTestResult>().toList();
    if (validHits.isEmpty) return;

    final planeHits =
        validHits.where((h) => h.type == ARHitTestResultType.plane).toList();

    if (planeHits.isEmpty) {
      _showToast("Önce zemini/masayı algılat.");
      return;
    }

    _placing = true;

    try {
      final hit = planeHits.first;
      final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final okAnchor = (await _anchors!.addAnchor(anchor)) ?? false;

      if (!okAnchor) {
        _showToast("Anchor eklenemedi.");
        _placing = false;
        return;
      }

      final node = _buildNode();
      final okNode =
          (await _objects!.addNode(node, planeAnchor: anchor)) ?? false;

      if (!okNode) {
        try {
          await _anchors!.removeAnchor(anchor);
        } catch (e) {
          _log("Anchor rollback hatası: $e");
        }
        _showToast("Model eklenemedi.");
        _placing = false;
        return;
      }

      _activeAnchor = anchor;
      _activeNode = node;

      HapticFeedback.mediumImpact();
      _showToast("✅ Model zemine yerleştirildi.");
    } catch (e) {
      _log("Plane tap hatası: $e");
      _showToast("Yerleştirme hatası.");
    } finally {
      _placing = false;
    }
  }

  Future<void> _clearAll() async {
    HapticFeedback.mediumImpact();

    _updateTimer?.cancel();
    _positionTimer?.cancel();

    if (_objects != null && _activeNode != null) {
      try {
        await _objects!.removeNode(_activeNode!);
      } catch (e) {
        _log("clear removeNode hatası: $e");
      }
    }

    if (_anchors != null && _activeAnchor != null) {
      try {
        await _anchors!.removeAnchor(_activeAnchor!);
      } catch (e) {
        _log("clear removeAnchor hatası: $e");
      }
    }

    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final shortest = math.min(size.width, size.height);
    final resetScale = shortest <= 360
        ? 0.38
        : shortest <= 430
            ? 0.48
            : 0.58;

    setState(() {
      _activeNode = null;
      _activeAnchor = null;
      _scale = resetScale;
      _baseScale = resetScale;
      _rotYDeg = 0.0;
      _liftMeters = 0.0;
      _posX = 0.0;
      _posZ = 0.0;
      _tiltMode = 0;
      _mirrored = false;
      _lastSingleFocalPoint = null;
      _gestureInProgress = false;
      _preferRebuildOnly = false;
    });

    _showToast("Temizlendi. Tekrar dokunabilirsin.");
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (_tapLocked) return;
    if (!_hasModel) return;

    _gestureInProgress = true;
    _baseScale = _scale;
    _baseRotYDeg = _rotYDeg;
    _lastSingleFocalPoint = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_tapLocked) return;
    if (!_hasModel) return;

    _lastGestureAt = DateTime.now();

    if (_isMultiTouch) {
      if (_mirrored) return;

      final newScale = (_baseScale * d.scale).clamp(0.08, 4.0);
      final deltaDeg = d.rotation * 180.0 / math.pi;
      final newRot = (_baseRotYDeg - deltaDeg) % 360.0;

      setState(() {
        _scale = newScale;
        _rotYDeg = newRot;
      });

      if (_allowLiveUpdateDuringGesture) {
        _queueTransformCommit(ms: 70);
      }
      return;
    }

    if (_lastSingleFocalPoint == null) {
      _lastSingleFocalPoint = d.focalPoint;
      return;
    }

    final delta = d.focalPoint - _lastSingleFocalPoint!;
    _lastSingleFocalPoint = d.focalPoint;

    final dx = delta.dx * _dragToMeters;
    final dz = delta.dy * _dragToMeters;

    setState(() {
      _posX = (_posX + dx).clamp(-1.5, 1.5);
      _posZ = (_posZ + dz).clamp(-1.5, 1.5);
    });

    if (_allowLiveUpdateDuringGesture) {
      _queueTransformCommit(ms: 70);
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_tapLocked) return;
    if (!_hasModel) return;

    _gestureInProgress = false;
    _lastGestureAt = DateTime.now();
    _lastSingleFocalPoint = null;

    if (_isRemoteGlb || _preferRebuildOnly) {
      _queueTransformCommit(ms: 20, forceRebuild: true);
    } else {
      _queueTransformCommit(ms: 40);
    }
  }

  Future<void> _togglePlanes() async {
    HapticFeedback.selectionClick();

    setState(() => _showPlanes = !_showPlanes);

    try {
      await _session?.onInitialize(
        showFeaturePoints: false,
        showPlanes: _showPlanes,
        showWorldOrigin: false,
        handleTaps: true,
      );
      _showToast(_showPlanes ? "Düzlemler açık." : "Düzlemler kapalı.");
    } catch (e) {
      _log("Plane toggle hatası: $e");
      _showToast("Düzlem görünürlüğü değiştirilemedi.");
    }
  }

  void _toggleTilt() {
    if (_tapLocked || !_hasModel) return;
    HapticFeedback.selectionClick();

    setState(() => _tiltMode = (_tiltMode + 1) % 3);
    _applyAfterButtonChange();
  }

  void _toggleMirror() {
    if (_tapLocked || !_hasModel) return;
    HapticFeedback.selectionClick();

    setState(() => _mirrored = !_mirrored);
    _applyAfterButtonChange();
  }

  void _rotPlus90() {
    if (_tapLocked || !_hasModel) return;
    if (_mirrored) {
      _showToast("Ayna açıkken döndürme kapalı.");
      return;
    }

    HapticFeedback.selectionClick();

    setState(() => _rotYDeg = (_rotYDeg - 90.0) % 360.0);
    _applyAfterButtonChange();
  }

  void _liftUp() {
    if (_tapLocked || !_hasModel) return;
    HapticFeedback.selectionClick();

    setState(() {
      _liftMeters = (_liftMeters + _liftStep).clamp(-0.30, 0.60);
    });

    if (_isRemoteGlb) {
      _queuePositionCommit(ms: 180);
    } else {
      _applyAfterButtonChange(ms: 40);
    }
  }

  void _liftDown() {
    if (_tapLocked || !_hasModel) return;
    HapticFeedback.selectionClick();

    setState(() {
      _liftMeters = (_liftMeters - _liftStep).clamp(-0.30, 0.60);
    });

    if (_isRemoteGlb) {
      _queuePositionCommit(ms: 180);
    } else {
      _applyAfterButtonChange(ms: 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pngPath = _pngPath;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              setState(() {
                _pointerIds.add(e.pointer);
              });
            },
            onPointerUp: (e) {
              setState(() {
                _pointerIds.remove(e.pointer);
              });
            },
            onPointerCancel: (e) {
              setState(() {
                _pointerIds.remove(e.pointer);
              });
            },
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
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
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
                                  isLocalFile: !_isRemoteGlb,
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
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_toastText.isNotEmpty)
                          Expanded(
                            child: Text(
                              _toastText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: _clearAll,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
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
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
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
                                  label: _tapLocked ? "Kilitli" : "Kilitle",
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
                                  icon: _showPlanes
                                      ? Icons.grid_on_rounded
                                      : Icons.grid_off_rounded,
                                  label: _showPlanes
                                      ? "Düzlem Açık"
                                      : "Düzlem Kapalı",
                                  onPressed: _togglePlanes,
                                  active: _showPlanes,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.flip_rounded,
                                  label: "Ayna",
                                  onPressed: _toggleMirror,
                                  active: _mirrored,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.rotate_90_degrees_ccw_rounded,
                                  label: "Döndür",
                                  onPressed: _rotPlus90,
                                  active: _rotYDeg != 0.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.view_in_ar_rounded,
                                  label: _tiltMode == 0
                                      ? "Eğim"
                                      : "Eğim ${_tiltMode}x",
                                  onPressed: _toggleTilt,
                                  active: _tiltMode > 0,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.arrow_downward_rounded,
                                  label: "Y -",
                                  onPressed: _liftDown,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _controlBtn(
                                  icon: Icons.arrow_upward_rounded,
                                  label: "Y +",
                                  onPressed: _liftUp,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tapLocked
                                ? "Kilit açık: taşıma, ölçekleme, döndürme ve eğim kapalı."
                                : _mirrored
                                    ? "Ayna açık: tek parmak taşıma serbest, pinch ve döndürme kapalı."
                                    : _isRemoteGlb
                                        ? "Remote GLB: pinch ve Y değişiklikleri klon olmaması için kontrollü uygulanır."
                                        : "Tek parmak taşı • Çift parmak ölçekle/döndür • Zemine dokunarak yerleştir",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
