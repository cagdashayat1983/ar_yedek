import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class IosArSayfasi extends StatefulWidget {
  final String imagePath;

  const IosArSayfasi({super.key, required this.imagePath});

  @override
  State<IosArSayfasi> createState() => _IosArSayfasiState();
}

class _IosArSayfasiState extends State<IosArSayfasi> {
  static const double _defaultOpacity = 0.82;
  static const double _planeVisualSink = 0.0015;
  static const String _nodeId = 'image_plane_node';

  final GlobalKey _sceneKey = GlobalKey();

  ARKitController? arkitController;
  ARKitNode? imageNode;
  String? nodeName;

  bool _placing = false;
  bool _tapLocked = false;
  bool _mirrored = false;

  int _gridMode = 0;
  int _tiltMode = 0;

  double _scale = 0.22;
  double _liftMeters = 0.0;

  double _posX = 0.0;
  double _posZ = -0.5;

  double _baseScale = 0.22;
  double _rotYRad = -math.pi / 2;
  double _rotZRad = 0.0;
  double _baseRotZRad = 0.0;

  double _opacity = _defaultOpacity;

  bool _isTablet = false;
  bool _isTrackingNormal = true;

  bool _isDragHitTestBusy = false;
  Offset? _queuedDragPoint;

  bool _imageMetricsReady = false;
  double _imageAspectRatio = 1.0;
  double _planeWidth = 1.0;
  double _planeHeight = 1.0;

  String _lastTrackingToastKey = '';

  Timer? _toastTimer;
  String _toastText = "";

  bool get _hasModel => imageNode != null;

  @override
  void dispose() {
    _toastTimer?.cancel();
    arkitController?.dispose();
    super.dispose();
  }

  double _defaultStartScale() => _isTablet ? 0.18 : 0.22;

  String get _tiltLabel {
    switch (_tiltMode) {
      case 1:
        return "15°";
      case 2:
        return "30°";
      default:
        return "Eğim";
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

  String _normalizedLocalPath(String rawPath) {
    final uri = Uri.tryParse(rawPath);
    if (uri != null && uri.scheme == 'file') {
      return uri.toFilePath();
    }
    return rawPath;
  }

  Future<void> _ensureImageMetrics() async {
    if (_imageMetricsReady) return;

    try {
      final rawPath = widget.imagePath.trim();
      final normalizedPath = _normalizedLocalPath(rawPath);

      Uint8List bytes;

      final file = File(normalizedPath);
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      } else {
        final assetPath = normalizedPath.startsWith('/')
            ? normalizedPath.substring(1)
            : normalizedPath;
        final data = await rootBundle.load(assetPath);
        bytes = data.buffer.asUint8List();
      }

      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width.toDouble();
      final height = image.height.toDouble();

      _imageAspectRatio = height > 0 ? (width / height) : 1.0;

      const longestEdgeMeters = 1.0;
      if (_imageAspectRatio >= 1.0) {
        _planeWidth = longestEdgeMeters;
        _planeHeight = longestEdgeMeters / _imageAspectRatio;
      } else {
        _planeHeight = longestEdgeMeters;
        _planeWidth = longestEdgeMeters * _imageAspectRatio;
      }

      _imageMetricsReady = true;
    } catch (_) {
      _imageAspectRatio = 1.0;
      _planeWidth = 1.0;
      _planeHeight = 1.0;
      _imageMetricsReady = true;
    }
  }

  ARKitMaterial _buildMaterial() {
    return ARKitMaterial(
      diffuse: ARKitMaterialProperty.image(widget.imagePath),
      emission: ARKitMaterialProperty.image(widget.imagePath),
      transparency: _opacity,
      doubleSided: true,
    );
  }

  v.Vector3 _currentEulerAngles() {
    double tiltAngle = 0.0;
    if (_tiltMode == 1) tiltAngle = math.pi / 12;
    if (_tiltMode == 2) tiltAngle = math.pi / 6;

    final xAngle = (-math.pi / 2) + tiltAngle + (_mirrored ? math.pi : 0.0);
    return v.Vector3(xAngle, _rotYRad, _rotZRad);
  }

  ARKitTestResult? _pickBestPlaneHit(List<ARKitTestResult> hits) {
    if (hits.isEmpty) return null;

    const preferredTypes = <ARKitHitTestResultType>[
      ARKitHitTestResultType.existingPlaneUsingGeometry,
      ARKitHitTestResultType.existingPlaneUsingExtent,
      ARKitHitTestResultType.existingPlane,
      ARKitHitTestResultType.estimatedHorizontalPlane,
    ];

    for (final type in preferredTypes) {
      for (final hit in hits) {
        if (hit.type == type) {
          return hit;
        }
      }
    }

    return null;
  }

  Future<void> _addCoachingOverlayIfPossible() async {
    final controller = arkitController;
    if (controller == null) return;

    try {
      await controller.addCoachingOverlay(CoachingOverlayGoal.horizontalPlane);
    } catch (_) {
      // Sessiz geç
    }
  }

  void _configureCallbacks(ARKitController controller) {
    controller.onARTap = (List<ARKitTestResult> results) {
      if (!_isTrackingNormal) {
        _showToast("Zemin henüz net değil. Kamerayı biraz daha gezdir.");
        return;
      }

      if (_hasModel) {
        _showToast("Zaten eklendi. Temizle ile sıfırla.");
        return;
      }

      if (_tapLocked || _placing) return;

      if (results.isEmpty) {
        _showToast("Yüzey bulunamadı. Kamerayı zemine doğru tut.");
        return;
      }

      final hit = _pickBestPlaneHit(results);
      if (hit == null) {
        _showToast("Düz bir zemin algılanamadı. Biraz daha tarat.");
        return;
      }

      unawaited(_addPlaneImage(hit));
    };

    controller.onCameraDidChangeTrackingState =
        (ARTrackingState trackingState, ARTrackingStateReason? reason) {
      final isNormal = trackingState == ARTrackingState.normal;

      if (mounted && _isTrackingNormal != isNormal) {
        setState(() => _isTrackingNormal = isNormal);
      }

      if (isNormal) {
        _lastTrackingToastKey = '';
        return;
      }

      final key = '${trackingState.name}_${reason?.name ?? ''}';
      if (key == _lastTrackingToastKey) return;
      _lastTrackingToastKey = key;

      final reasonText = reason?.name;
      if (reasonText != null && reasonText.isNotEmpty) {
        _showToast("AR izleme zayıf: $reasonText");
      } else {
        _showToast("AR izleme zayıf. Kamerayı zeminde gezdir.");
      }
    };

    controller.onError = (String? error) {
      _showToast("AR hatası: ${error ?? 'Bilinmeyen hata'}");
    };

    controller.onSessionWasInterrupted = () {
      _showToast("AR oturumu durakladı.");
    };

    controller.onSessionInterruptionEnded = () {
      _showToast("AR devam ediyor. Gerekirse zemini tekrar tara.");
    };

    controller.coachingOverlayViewDidDeactivate = () {
      if (!_hasModel) {
        _showToast("Kamerayı zemine tut ve dokun.");
      }
    };
  }

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;
    _configureCallbacks(controller);
    unawaited(_addCoachingOverlayIfPossible());
    _showToast("Kamerayı yavaşça zemine tutun ve dokunun.");
  }

  Future<void> _addPlaneImage(ARKitTestResult hit) async {
    if (_placing || _hasModel) return;

    final controller = arkitController;
    if (controller == null) return;

    _placing = true;

    try {
      await _ensureImageMetrics();

      final col = hit.worldTransform.getColumn(3);
      _posX = col.x;
      _posZ = col.z;

      _scale = _defaultStartScale();

      final plane = ARKitPlane(
        width: _planeWidth,
        height: _planeHeight,
        materials: [_buildMaterial()],
      );

      imageNode = ARKitNode(
        name: _nodeId,
        geometry: plane,
        position: v.Vector3(
          _posX,
          col.y + _liftMeters - _planeVisualSink,
          _posZ,
        ),
        scale: v.Vector3(_scale, _scale, _scale),
        eulerAngles: _currentEulerAngles(),
      );

      nodeName = _nodeId;

      await controller.add(imageNode!);

      if (mounted) {
        setState(() {});
      }

      _showToast("✅ Resim zemine yerleşti!");
    } catch (e) {
      _showToast("❌ Yerleştirme hatası: $e");
    } finally {
      _placing = false;
    }
  }

  Future<void> _updateNodeTransform() async {
    if (!_hasModel || nodeName == null) return;

    final controller = arkitController;
    if (controller == null) return;

    final currentY = imageNode!.position.y;

    imageNode!
      ..position = v.Vector3(_posX, currentY, _posZ)
      ..scale = v.Vector3(_scale, _scale, _scale)
      ..eulerAngles = _currentEulerAngles();

    await controller.update(nodeName!, node: imageNode!);
  }

  Future<void> _updateOpacity(double newOpacity) async {
    setState(() => _opacity = newOpacity);

    if (!_hasModel || nodeName == null) return;

    final controller = arkitController;
    if (controller == null) return;

    final newMaterial = _buildMaterial();

    imageNode!.geometry?.materials.value = [newMaterial];
    await controller.update(
      nodeName!,
      node: imageNode!,
      materials: [newMaterial],
    );
  }

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseRotZRad = _rotZRad;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_hasModel || _tapLocked) return;

    if (d.pointerCount > 1) {
      setState(() {
        if (!_mirrored) {
          _scale = (_baseScale * d.scale).clamp(0.05, 3.0).toDouble();
          _rotZRad = _baseRotZRad - d.rotation;
        }
      });

      unawaited(_updateNodeTransform());
      return;
    }

    unawaited(_dragNodeOnPlane(d.focalPoint));
  }

  Future<void> _dragNodeOnPlane(Offset globalPoint) async {
    if (!_hasModel || _tapLocked || !_isTrackingNormal) return;

    final controller = arkitController;
    if (controller == null) return;

    if (_isDragHitTestBusy) {
      _queuedDragPoint = globalPoint;
      return;
    }

    _isDragHitTestBusy = true;

    try {
      final renderBox =
          _sceneKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final local = renderBox.globalToLocal(globalPoint);
      final size = renderBox.size;

      final nx = (local.dx / size.width).clamp(0.0, 1.0).toDouble();
      final ny = (local.dy / size.height).clamp(0.0, 1.0).toDouble();

      final results = await controller.performHitTest(x: nx, y: ny);
      final hit = _pickBestPlaneHit(results);

      if (hit == null) return;

      final col = hit.worldTransform.getColumn(3);

      _posX = col.x;
      _posZ = col.z;

      imageNode!.position = v.Vector3(
        _posX,
        col.y + _liftMeters - _planeVisualSink,
        _posZ,
      );

      await _updateNodeTransform();
    } catch (_) {
      // Sessiz geç
    } finally {
      _isDragHitTestBusy = false;

      final pending = _queuedDragPoint;
      _queuedDragPoint = null;

      if (pending != null && mounted) {
        unawaited(_dragNodeOnPlane(pending));
      }
    }
  }

  Future<void> _clearAll() async {
    final controller = arkitController;

    if (nodeName != null && controller != null) {
      try {
        await controller.remove(nodeName!);
      } catch (_) {
        // Sessiz geç
      }
    }

    setState(() {
      imageNode = null;
      nodeName = null;
      _scale = _defaultStartScale();
      _rotYRad = -math.pi / 2;
      _rotZRad = 0.0;
      _liftMeters = 0.0;
      _tiltMode = 0;
      _mirrored = false;
      _opacity = _defaultOpacity;
    });

    _showToast("Temizlendi. Tekrar dokunabilirsin.");
  }

  void _toggleGrid() {
    setState(() {
      _gridMode = (_gridMode == 0)
          ? 3
          : (_gridMode == 3 ? 4 : (_gridMode == 4 ? 5 : 0));
    });
  }

  void _toggleTilt() {
    setState(() => _tiltMode = (_tiltMode + 1) % 3);
    unawaited(_updateNodeTransform());
  }

  void _toggleMirror() {
    setState(() => _mirrored = !_mirrored);
    unawaited(_updateNodeTransform());
  }

  void _rotPlus90() {
    setState(() => _rotZRad -= (math.pi / 2));
    unawaited(_updateNodeTransform());
  }

  Future<void> _changeLift(double delta) async {
    if (!_hasModel || nodeName == null) return;

    final controller = arkitController;
    if (controller == null) return;

    final oldLift = _liftMeters;
    final newLift = (_liftMeters + delta).clamp(-0.03, 0.30).toDouble();
    final appliedDelta = newLift - oldLift;

    if (appliedDelta == 0.0) return;

    setState(() => _liftMeters = newLift);

    imageNode!.position = v.Vector3(
      _posX,
      imageNode!.position.y + appliedDelta,
      _posZ,
    );

    await controller.update(nodeName!, node: imageNode!);
  }

  void _comingSoon(String label) {
    _showToast("$label şu an pasif. Stabil AR yerleşimi hazır.");
  }

  @override
  Widget build(BuildContext context) {
    _isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: SizedBox.expand(
              key: _sceneKey,
              child: ARKitSceneView(
                onARKitViewCreated: _onARKitViewCreated,
                planeDetection: ARPlaneDetection.horizontal,
                enableTapRecognizer: true,
                showFeaturePoints: kDebugMode,
                showStatistics: kDebugMode,
              ),
            ),
          ),
          if (_hasModel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: Container(color: Colors.transparent),
              ),
            ),
          if (_gridMode > 0)
            Positioned.fill(
              child: IgnorePointer(
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
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: Icon(
                            Icons.apple,
                            color: _isTrackingNormal
                                ? Colors.cyanAccent
                                : Colors.orangeAccent,
                          ),
                          label: Text(
                            _isTrackingNormal
                                ? "PRO AR MODU (iOS)"
                                : "ZEMİN TARAMA...",
                            style: TextStyle(
                              color: _isTrackingNormal
                                  ? Colors.cyanAccent
                                  : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_toastText.isNotEmpty)
                          Flexible(
                            child: Text(
                              _toastText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => unawaited(_clearAll()),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.opacity, color: Colors.white, size: 20),
                      Expanded(
                        child: Slider(
                          value: _opacity,
                          min: 0.1,
                          max: 1.0,
                          activeColor: Colors.cyanAccent,
                          inactiveColor: Colors.white24,
                          onChanged: (v) => unawaited(_updateOpacity(v)),
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
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.70),
                            Colors.black.withValues(alpha: 0.50),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _btn(
                              Icons.videocam_outlined,
                              "Kayıt",
                              false,
                              Colors.redAccent,
                              () => _comingSoon("Kayıt"),
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
                              _tiltLabel,
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
                              () => unawaited(_changeLift(-0.01)),
                            ),
                            const SizedBox(width: 8),
                            _btn(
                              Icons.arrow_upward,
                              "Y+",
                              true,
                              Colors.cyanAccent,
                              () => unawaited(_changeLift(0.01)),
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
                              Icons.flash_on,
                              "Flaş",
                              false,
                              Colors.amber,
                              () => _comingSoon("Flaş"),
                            ),
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
                      colors: [
                        activeColor,
                        activeColor.withValues(alpha: 0.6),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                    ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? activeColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.10),
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
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
      ..color = Colors.cyanAccent.withValues(alpha: 0.3)
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
