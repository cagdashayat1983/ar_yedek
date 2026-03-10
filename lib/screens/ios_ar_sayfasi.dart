import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

class _IosArSayfasiState extends State<IosArSayfasi>
    with SingleTickerProviderStateMixin {
  static const String _nodeId = 'image_plane_node';
  static const double _defaultOpacity = 1.0;
  static const double _planeVisualSink = 0.004;

  final GlobalKey _sceneKey = GlobalKey();

  late final AnimationController _reticleAnim;

  ARKitController? arkitController;
  ARKitNode? imageNode;
  String? nodeName;

  ARKitTestResult? _currentPlacementHit;

  final Set<int> _activePointers = <int>{};

  bool _placing = false;
  bool _tapLocked = false;
  bool _mirrored = false;
  bool _isTrackingNormal = true;
  bool _surfaceReady = false;

  bool _isScalingGesture = false;

  int _gridMode = 0;
  int _tiltMode = 0;

  double _scale = 0.22;
  double _baseScale = 0.22;

  double _rotYRad = -math.pi / 2;
  double _rotZRad = 0.0;
  double _baseRotZRad = 0.0;

  double _liftMeters = 0.0;
  double _opacity = _defaultOpacity;

  double _posX = 0.0;
  double _posZ = -0.5;

  bool _isTablet = false;

  bool _imageMetricsReady = false;
  double _imageAspectRatio = 1.0;
  double _planeWidth = 1.0;
  double _planeHeight = 1.0;

  bool _isNodeUpdateBusy = false;
  bool _nodeUpdateQueued = false;

  Timer? _toastTimer;
  Timer? _placementProbeTimer;

  String _toastText = '';
  String _lastTrackingToastKey = '';

  bool get _hasModel => imageNode != null;

  @override
  void initState() {
    super.initState();
    _reticleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _placementProbeTimer?.cancel();
    _reticleAnim.dispose();
    arkitController?.dispose();
    super.dispose();
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toastText = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _toastText = '');
    });
  }

  double _defaultStartScale() => _isTablet ? 0.18 : 0.22;

  String get _tiltLabel {
    switch (_tiltMode) {
      case 1:
        return '15°';
      case 2:
        return '30°';
      default:
        return 'Eğim';
    }
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

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width.toDouble();
      final height = image.height.toDouble();

      _imageAspectRatio = height > 0 ? width / height : 1.0;

      const longestEdgeMeters = 1.0;
      if (_imageAspectRatio >= 1.0) {
        _planeWidth = longestEdgeMeters;
        _planeHeight = longestEdgeMeters / _imageAspectRatio;
      } else {
        _planeHeight = longestEdgeMeters;
        _planeWidth = longestEdgeMeters * _imageAspectRatio;
      }

      image.dispose();
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
      transparent: ARKitMaterialProperty.image(widget.imagePath),
      transparency: _opacity,
      lightingModelName: ARKitLightingModel.constant,
      doubleSided: true,
      cullMode: ARKitCullMode.back,
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

  Future<ARKitTestResult?> _performBestHitTest(double x, double y) async {
    final controller = arkitController;
    if (controller == null) return null;

    const offsets = <Offset>[
      Offset(0, 0),
      Offset(-0.03, 0),
      Offset(0.03, 0),
      Offset(0, -0.04),
      Offset(0, 0.04),
      Offset(-0.05, -0.05),
      Offset(0.05, -0.05),
      Offset(-0.05, 0.05),
      Offset(0.05, 0.05),
    ];

    for (final offset in offsets) {
      final nx = (x + offset.dx).clamp(0.0, 1.0).toDouble();
      final ny = (y + offset.dy).clamp(0.0, 1.0).toDouble();

      final results = await controller.performHitTest(x: nx, y: ny);
      final hit = _pickBestPlaneHit(results);
      if (hit != null) return hit;
    }

    return null;
  }

  void _configureCallbacks(ARKitController controller) {
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
        _showToast('AR izleme zayıf: $reasonText');
      } else {
        _showToast('AR izleme zayıf. Kamerayı zeminde gezdir.');
      }
    };

    controller.onError = (String? error) {
      _showToast("AR hatası: ${error ?? 'Bilinmeyen hata'}");
    };

    controller.onSessionWasInterrupted = () {
      _showToast('AR oturumu durakladı.');
    };

    controller.onSessionInterruptionEnded = () {
      _showToast('AR devam ediyor. Zemini tekrar tara.');
    };
  }

  void _startPlacementProbeLoop() {
    _placementProbeTimer?.cancel();
    _placementProbeTimer = Timer.periodic(
      const Duration(milliseconds: 180),
      (_) async {
        if (!mounted) return;
        if (_hasModel) return;

        if (!_isTrackingNormal) {
          if (_surfaceReady || _currentPlacementHit != null) {
            setState(() {
              _surfaceReady = false;
              _currentPlacementHit = null;
            });
          }
          return;
        }

        final hit = await _performBestHitTest(0.5, 0.58);
        if (!mounted) return;

        setState(() {
          _currentPlacementHit = hit;
          _surfaceReady = hit != null;
        });
      },
    );
  }

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;
    _configureCallbacks(controller);
    _startPlacementProbeLoop();
    _showToast('Kamerayı zemine tut. Nişangâh mavi olunca dokun.');
  }

  void _applyCurrentTransformToNode({double? yOverride}) {
    if (!_hasModel) return;

    imageNode!
      ..position = v.Vector3(
        _posX,
        yOverride ?? imageNode!.position.y,
        _posZ,
      )
      ..scale = v.Vector3(_scale, _scale, _scale)
      ..eulerAngles = _currentEulerAngles();
  }

  Future<void> _flushNodeUpdate() async {
    if (!_hasModel || nodeName == null || arkitController == null) return;

    if (_isNodeUpdateBusy) {
      _nodeUpdateQueued = true;
      return;
    }

    _isNodeUpdateBusy = true;

    try {
      do {
        _nodeUpdateQueued = false;
        await arkitController!.update(nodeName!, node: imageNode!);
      } while (_nodeUpdateQueued);
    } finally {
      _isNodeUpdateBusy = false;
    }
  }

  Future<void> _tryPlaceFromCenterHit() async {
    if (_placing || _hasModel || _tapLocked) return;

    if (!_isTrackingNormal) {
      _showToast('Takip hazır değil. Kamerayı biraz daha gezdir.');
      return;
    }

    final hit = _currentPlacementHit ?? await _performBestHitTest(0.5, 0.58);
    if (hit == null) {
      _showToast('Zemin kilitlenmedi. Kamerayı biraz daha aşağı indir.');
      return;
    }

    await _addPlaneImage(hit);
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
        setState(() {
          _surfaceReady = false;
          _currentPlacementHit = null;
        });
      }

      _showToast('✅ Resim zemine oturdu!');
    } catch (e) {
      _showToast('❌ Yerleştirme hatası: $e');
    } finally {
      _placing = false;
    }
  }

  Future<void> _updateOpacity(double newOpacity) async {
    setState(() => _opacity = newOpacity);

    if (!_hasModel || nodeName == null || arkitController == null) return;

    final newMaterial = _buildMaterial();
    imageNode!.geometry?.materials.value = [newMaterial];

    await arkitController!.update(
      nodeName!,
      node: imageNode!,
      materials: [newMaterial],
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);

    if (_activePointers.length >= 2) {
      _isScalingGesture = true;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_hasModel || _tapLocked) return;
    if (_isScalingGesture) return;
    if (_activePointers.length != 1) return;

    final dx = event.delta.dx.clamp(-24.0, 24.0);
    final dy = event.delta.dy.clamp(-24.0, 24.0);

    if (dx.abs() < 0.35 && dy.abs() < 0.35) return;

    final moveFactor = (0.00080 + (_scale * 0.00018)).clamp(0.00078, 0.00132);

    _posX += dx * moveFactor;
    _posZ += dy * moveFactor;

    _applyCurrentTransformToNode();
    unawaited(_flushNodeUpdate());
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    _activePointers.remove(event.pointer);

    if (_activePointers.isEmpty) {
      _isScalingGesture = false;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (_activePointers.length < 2) return;
    if (!_hasModel || _tapLocked) return;

    _baseScale = _scale;
    _baseRotZRad = _rotZRad;
    _isScalingGesture = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_activePointers.length < 2) return;
    if (!_hasModel || _tapLocked) return;

    setState(() {
      _scale = (_baseScale * d.scale).clamp(0.05, 2.4).toDouble();
      _rotZRad = _baseRotZRad - d.rotation;
    });

    _applyCurrentTransformToNode();
    unawaited(_flushNodeUpdate());
  }

  void _onScaleEnd(ScaleEndDetails d) {
    // Drag ancak tüm parmaklar kalkınca tekrar açılır.
  }

  Future<void> _reSnapToCenterPlane() async {
    if (!_hasModel || nodeName == null) return;

    final hit = await _performBestHitTest(0.5, 0.58);
    if (hit == null) {
      _showToast('Merkezde zemin bulunamadı.');
      return;
    }

    final col = hit.worldTransform.getColumn(3);
    _posX = col.x;
    _posZ = col.z;

    _applyCurrentTransformToNode(
      yOverride: col.y + _liftMeters - _planeVisualSink,
    );
    await _flushNodeUpdate();
    _showToast('Zemine yeniden oturtuldu.');
  }

  Future<void> _clearAll() async {
    final controller = arkitController;

    if (nodeName != null && controller != null) {
      try {
        await controller.remove(nodeName!);
      } catch (_) {}
    }

    setState(() {
      imageNode = null;
      nodeName = null;
      _currentPlacementHit = null;
      _surfaceReady = false;
      _scale = _defaultStartScale();
      _rotYRad = -math.pi / 2;
      _rotZRad = 0.0;
      _liftMeters = 0.0;
      _tiltMode = 0;
      _mirrored = false;
      _opacity = _defaultOpacity;
      _isScalingGesture = false;
      _activePointers.clear();
    });

    _showToast('Temizlendi. Tekrar yerleştirebilirsin.');
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
    _applyCurrentTransformToNode();
    unawaited(_flushNodeUpdate());
  }

  void _toggleMirror() {
    setState(() => _mirrored = !_mirrored);
    _applyCurrentTransformToNode();
    unawaited(_flushNodeUpdate());
  }

  void _rotPlus90() {
    setState(() => _rotZRad -= math.pi / 2);
    _applyCurrentTransformToNode();
    unawaited(_flushNodeUpdate());
  }

  Future<void> _changeLift(double delta) async {
    if (!_hasModel || nodeName == null) return;

    final oldLift = _liftMeters;
    final newLift = (_liftMeters + delta).clamp(-0.004, 0.03).toDouble();
    final appliedDelta = newLift - oldLift;

    if (appliedDelta == 0.0) return;

    setState(() => _liftMeters = newLift);

    _applyCurrentTransformToNode(
      yOverride: imageNode!.position.y + appliedDelta,
    );
    await _flushNodeUpdate();
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF101010).withOpacity(0.72),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final bgColor =
        active ? activeColor.withOpacity(0.18) : Colors.white.withOpacity(0.05);
    final borderColor =
        active ? activeColor.withOpacity(0.50) : Colors.white.withOpacity(0.10);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.20),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: active ? activeColor : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? activeColor : Colors.white70,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReticle() {
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: AnimatedBuilder(
            animation: _reticleAnim,
            builder: (context, child) {
              final t = _reticleAnim.value;
              final pulse = 0.95 + math.sin(t * math.pi * 2) * 0.04;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: pulse,
                    child: CustomPaint(
                      size: const Size(92, 92),
                      painter: ReticlePainter(
                        active: _surfaceReady && _isTrackingNormal,
                        progress: t,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    !_isTrackingNormal
                        ? 'Zemin aranıyor...'
                        : _surfaceReady
                            ? 'Dokun ve yerleştir'
                            : 'Kamerayı biraz daha zemine indir',
                    style: TextStyle(
                      color: _surfaceReady && _isTrackingNormal
                          ? Colors.cyanAccent
                          : Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 10),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            key: _sceneKey,
            child: ARKitSceneView(
              onARKitViewCreated: _onARKitViewCreated,
              planeDetection: ARPlaneDetection.horizontal,
              enableTapRecognizer: false,
              autoenablesDefaultLighting: true,
              showFeaturePoints: kDebugMode,
              showStatistics: kDebugMode,
            ),
          ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUpOrCancel,
              onPointerCancel: _onPointerUpOrCancel,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (_) {
                  if (!_hasModel) {
                    unawaited(_tryPlaceFromCenterHit());
                  }
                },
                onScaleStart: _hasModel ? _onScaleStart : null,
                onScaleUpdate: _hasModel ? _onScaleUpdate : null,
                onScaleEnd: _hasModel ? _onScaleEnd : null,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (!_hasModel) _buildReticle(),
          if (_gridMode > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GridPainter(gridCount: _gridMode),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: _glassPanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.apple,
                              size: 18,
                              color: _isTrackingNormal
                                  ? Colors.cyanAccent
                                  : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _isTrackingNormal
                                    ? 'PRO AR MODU (iOS)'
                                    : 'ZEMİN TARAMA...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _isTrackingNormal
                                      ? Colors.cyanAccent
                                      : Colors.orangeAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => unawaited(_clearAll()),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_toastText.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 28,
              right: 28,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.68),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      _toastText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _glassPanel(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.opacity_rounded,
                          color: Colors.white.withOpacity(0.95),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 18,
                              ),
                            ),
                            child: Slider(
                              value: _opacity,
                              min: 0.35,
                              max: 1.0,
                              activeColor: Colors.cyanAccent,
                              inactiveColor: Colors.white24,
                              onChanged: (v) => unawaited(_updateOpacity(v)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _glassPanel(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _toolButton(
                            icon: _tapLocked ? Icons.lock : Icons.lock_open,
                            label: 'Kilit',
                            active: _tapLocked,
                            activeColor: Colors.redAccent,
                            onTap: () =>
                                setState(() => _tapLocked = !_tapLocked),
                          ),
                          const SizedBox(width: 10),
                          _toolButton(
                            icon: Icons.view_in_ar_outlined,
                            label: _tiltLabel,
                            active: _tiltMode > 0,
                            activeColor: Colors.orangeAccent,
                            onTap: _toggleTilt,
                          ),
                          const SizedBox(width: 10),
                          _toolButton(
                            icon: Icons.flip,
                            label: 'Ayna',
                            active: _mirrored,
                            activeColor: Colors.lightBlueAccent,
                            onTap: _toggleMirror,
                          ),
                          const SizedBox(width: 10),
                          _toolButton(
                            icon: Icons.rotate_90_degrees_cw,
                            label: '+90°',
                            active: false,
                            activeColor: Colors.white,
                            onTap: _rotPlus90,
                          ),
                          const SizedBox(width: 10),
                          _toolButton(
                            icon: Icons.vertical_align_bottom,
                            label: 'Y-',
                            active: true,
                            activeColor: Colors.cyanAccent,
                            onTap: () => unawaited(_changeLift(-0.01)),
                          ),
                          const SizedBox(width: 10),
                          _toolButton(
                            icon: Icons.vertical_align_top,
                            label: 'Y+',
                            active: true,
                            activeColor: Colors.cyanAccent,
                            onTap: () => unawaited(_changeLift(0.01)),
                          ),
                          const SizedBox(width: 10),
                          _toolButton(
                            icon: Icons.center_focus_strong,
                            label: 'Oturt',
                            active: false,
                            activeColor: Colors.cyanAccent,
                            onTap: () => unawaited(_reSnapToCenterPlane()),
                          ),
                          const SizedBox(width: 10),
                          _toolButton(
                            icon: Icons.grid_view_rounded,
                            label: _gridMode == 0 ? 'Izgara' : '${_gridMode}x',
                            active: _gridMode > 0,
                            activeColor: Colors.greenAccent,
                            onTap: _toggleGrid,
                          ),
                        ],
                      ),
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

class GridPainter extends CustomPainter {
  final int gridCount;

  GridPainter({required this.gridCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.25)
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

class ReticlePainter extends CustomPainter {
  final bool active;
  final double progress;

  ReticlePainter({
    required this.active,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mainColor = active ? Colors.cyanAccent : Colors.white70;
    final glow = active
        ? Colors.cyanAccent.withOpacity(0.16)
        : Colors.white.withOpacity(0.06);

    final glowPaint = Paint()..color = glow;
    final linePaint = Paint()
      ..color = mainColor.withOpacity(0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final softPaint = Paint()
      ..color = mainColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final pulse = 0.95 + math.sin(progress * math.pi * 2) * 0.04;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.84 * pulse,
      height: size.height * 0.84 * pulse,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      glowPaint,
    );

    final c = Offset(size.width / 2, size.height / 2);
    const ringRadius = 16.0;

    canvas.drawCircle(c, ringRadius, linePaint);

    canvas.drawLine(
      Offset(c.dx - 28, c.dy),
      Offset(c.dx - 10, c.dy),
      softPaint,
    );
    canvas.drawLine(
      Offset(c.dx + 10, c.dy),
      Offset(c.dx + 28, c.dy),
      softPaint,
    );
    canvas.drawLine(
      Offset(c.dx, c.dy - 28),
      Offset(c.dx, c.dy - 10),
      softPaint,
    );
    canvas.drawLine(
      Offset(c.dx, c.dy + 10),
      Offset(c.dx, c.dy + 28),
      softPaint,
    );

    final scanPaint = Paint()
      ..color = mainColor.withOpacity(active ? 0.90 : 0.45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final lineY = ui.lerpDouble(c.dy - 10, c.dy + 10, progress)!;
    canvas.drawLine(
      Offset(c.dx - 10, lineY),
      Offset(c.dx + 10, lineY),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ReticlePainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.progress != progress;
  }
}
