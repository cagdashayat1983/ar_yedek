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

class _IosArSayfasiState extends State<IosArSayfasi>
    with SingleTickerProviderStateMixin {
  static const double _defaultOpacity = 0.82;
  static const double _planeVisualSink = 0.0015;
  static const String _nodeId = 'image_plane_node';

  final GlobalKey _sceneKey = GlobalKey();

  late final AnimationController _scanAnimController;

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
  bool _surfaceReady = false;

  bool _isDragHitTestBusy = false;
  Offset? _queuedDragPoint;

  bool _imageMetricsReady = false;
  double _imageAspectRatio = 1.0;
  double _planeWidth = 1.0;
  double _planeHeight = 1.0;

  String _lastTrackingToastKey = '';

  Timer? _toastTimer;
  Timer? _surfaceProbeTimer;
  String _toastText = '';

  bool get _hasModel => imageNode != null;

  @override
  void initState() {
    super.initState();
    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _surfaceProbeTimer?.cancel();
    _scanAnimController.dispose();
    arkitController?.dispose();
    super.dispose();
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

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toastText = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _toastText = '');
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

  void _startSurfaceProbeLoop() {
    _surfaceProbeTimer?.cancel();
    _surfaceProbeTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) async {
        if (!mounted) return;
        if (_hasModel) {
          if (_surfaceReady) {
            setState(() => _surfaceReady = false);
          }
          return;
        }

        if (!_isTrackingNormal) {
          if (_surfaceReady) {
            setState(() => _surfaceReady = false);
          }
          return;
        }

        final hit = await _performBestHitTest(0.5, 0.56);
        if (!mounted) return;

        final readyNow = hit != null;
        if (readyNow != _surfaceReady) {
          setState(() => _surfaceReady = readyNow);
        }
      },
    );
  }

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;
    _configureCallbacks(controller);
    _startSurfaceProbeLoop();
    _showToast('Kamerayı zemine tut ve ekrana dokun.');
  }

  Future<void> _tryPlaceAtGlobalPoint(Offset globalPoint) async {
    if (_placing || _hasModel || _tapLocked) return;

    final controller = arkitController;
    if (controller == null) return;

    if (!_isTrackingNormal) {
      _showToast('Takip henüz hazır değil. Kamerayı biraz daha gezdir.');
      return;
    }

    final renderBox =
        _sceneKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final local = renderBox.globalToLocal(globalPoint);
    final size = renderBox.size;

    final nx = (local.dx / size.width).clamp(0.0, 1.0).toDouble();
    final ny = (local.dy / size.height).clamp(0.0, 1.0).toDouble();

    final hit = await _performBestHitTest(nx, ny) ??
        await _performBestHitTest(0.5, 0.56);

    if (hit == null) {
      _showToast('Zemin bulunamadı. Kamerayı biraz daha aşağı tut.');
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
        });
      }

      _showToast('✅ Resim zemine yapıştı!');
    } catch (e) {
      _showToast('❌ Yerleştirme hatası: $e');
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

      final hit = await _performBestHitTest(nx, ny);
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
      // sessiz geç
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
      } catch (_) {}
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
      _surfaceReady = false;
    });

    _showToast('Temizlendi. Tekrar dokunabilirsin.');
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
    _showToast('$label şu an pasif.');
  }

  Widget _buildScanOverlay() {
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _scanAnimController,
                builder: (context, child) {
                  final t = _scanAnimController.value;
                  return Transform.rotate(
                    angle: t * math.pi * 2,
                    child: CustomPaint(
                      size: const Size(96, 96),
                      painter: ScanCubePainter(
                        active: _surfaceReady && _isTrackingNormal,
                        progress: t,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
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
          ),
        ),
      ),
    );
  }

  Widget _buildGlassPanel({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111).withOpacity(0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
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
          Container(
            key: _sceneKey,
            color: Colors.black,
            child: ARKitSceneView(
              onARKitViewCreated: _onARKitViewCreated,
              planeDetection: ARPlaneDetection.horizontal,
              enableTapRecognizer: false,
              showFeaturePoints: kDebugMode,
              showStatistics: kDebugMode,
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                if (!_hasModel) {
                  unawaited(_tryPlaceAtGlobalPoint(details.globalPosition));
                }
              },
              onScaleStart: _hasModel ? _onScaleStart : null,
              onScaleUpdate: _hasModel ? _onScaleUpdate : null,
              child: const SizedBox.expand(),
            ),
          ),
          if (!_hasModel) _buildScanOverlay(),
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
              child: _buildGlassPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 22),
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
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => unawaited(_clearAll()),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_toastText.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 78,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                  _buildGlassPanel(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.opacity_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 18),
                            ),
                            child: Slider(
                              value: _opacity,
                              min: 0.1,
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
                  _buildGlassPanel(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _toolButton(
                            icon: Icons.videocam_outlined,
                            label: 'Kayıt',
                            active: false,
                            activeColor: Colors.redAccent,
                            onTap: () => _comingSoon('Kayıt'),
                          ),
                          const SizedBox(width: 10),
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
                            icon: Icons.grid_view_rounded,
                            label: _gridMode == 0 ? 'Izgara' : '${_gridMode}x',
                            active: _gridMode > 0,
                            activeColor: Colors.greenAccent,
                            onTap: _toggleGrid,
                          ),
                          const SizedBox(width: 10),
                          _toolButton(
                            icon: Icons.flash_on_rounded,
                            label: 'Flaş',
                            active: false,
                            activeColor: Colors.amber,
                            onTap: () => _comingSoon('Flaş'),
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

  Widget _toolButton({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final Color bgColor =
        active ? activeColor.withOpacity(0.18) : Colors.white.withOpacity(0.06);

    final Color borderColor =
        active ? activeColor.withOpacity(0.55) : Colors.white.withOpacity(0.10);

    final Color iconColor = active ? activeColor : Colors.white;
    final Color textColor = active ? activeColor : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 54,
              width: 54,
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
                        )
                      ]
                    : null,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
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

class ScanCubePainter extends CustomPainter {
  final bool active;
  final double progress;

  ScanCubePainter({
    required this.active,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mainColor = active ? Colors.cyanAccent : Colors.white70;
    final glowColor = active
        ? Colors.cyanAccent.withOpacity(0.16)
        : Colors.white.withOpacity(0.08);

    final glowPaint = Paint()..color = glowColor;
    final strokePaint = Paint()
      ..color = mainColor.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final softPaint = Paint()
      ..color = mainColor.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final pulse = 0.94 + (math.sin(progress * math.pi * 2) * 0.05);

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.86 * pulse,
      height: size.height * 0.86 * pulse,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      glowPaint,
    );

    final cx = size.width / 2;
    final cy = size.height / 2;
    final face = size.width * 0.30;
    final depth = size.width * 0.14;

    final front = Rect.fromCenter(
      center: Offset(cx - depth * 0.2, cy + depth * 0.16),
      width: face,
      height: face,
    );

    final back = front.shift(Offset(depth, -depth));

    canvas.drawRRect(
      RRect.fromRectAndRadius(back, const Radius.circular(10)),
      softPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(front, const Radius.circular(10)),
      strokePaint,
    );

    canvas.drawLine(front.topLeft, back.topLeft, strokePaint);
    canvas.drawLine(front.topRight, back.topRight, strokePaint);
    canvas.drawLine(front.bottomLeft, back.bottomLeft, strokePaint);
    canvas.drawLine(front.bottomRight, back.bottomRight, strokePaint);

    final scanPaint = Paint()
      ..color = mainColor.withOpacity(active ? 0.90 : 0.45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final lineY = lerpDouble(front.top + 6, front.bottom - 6, progress)!;
    canvas.drawLine(
      Offset(front.left + 6, lineY),
      Offset(front.right - 6, lineY),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScanCubePainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.progress != progress;
  }
}
