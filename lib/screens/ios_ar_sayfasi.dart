import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class IosArSayfasi extends StatefulWidget {
  final String imagePath;

  const IosArSayfasi({super.key, required this.imagePath});

  @override
  State<IosArSayfasi> createState() => _IosArSayfasiState();
}

class _IosArSayfasiState extends State<IosArSayfasi> {
  ARKitController? arkitController;

  // ✅ OYUN MOTORU MİMARİSİ: Taşıyıcı Tepsi ve Üstündeki Resim
  ARKitNode? parentNode; // Görünmez Tepsi (Sadece bu döner ve hareket eder)
  ARKitNode? imageNode; // Resim (Tepsiye kalıcı olarak YATIK mühürlenir)

  bool _placing = false;
  bool _tapLocked = false;
  bool _mirrored = false;
  bool _flashOn = false;
  bool _isRecording = false;

  int _gridMode = 0;
  int _tiltMode = 0;

  double _scale = 0.3;
  double _liftMeters = 0.0;

  double _posX = 0.0;
  double _posZ = -0.5;

  double _baseScale = 0.3;

  // ✅ YATAY BAŞLANGIÇ: Resmin sana yan (manzara) gelmesi için Y ekseninde -90 derece ile başlar.
  double _rotYRad = -math.pi / 2;
  double _baseRotYRad = 0.0;

  double _opacity = 0.6;

  Timer? _toastTimer;
  String _toastText = "";

  bool get _hasModel => parentNode != null;

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
    _toastTimer?.cancel();
    arkitController?.dispose();
    super.dispose();
  }

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;

    arkitController!.onARTap = (List<ARKitTestResult> ar) {
      if (!_hasModel && !_tapLocked && !_placing) {
        final hit = ar.firstWhere(
          (hit) => hit.type == ARKitHitTestResultType.existingPlaneUsingExtent,
          orElse: () => ar.first,
        );
        _addPlaneImage(hit);
      } else if (_hasModel) {
        _showToast("Zaten eklendi. Temizle ile sıfırla.");
      }
    };

    _showToast("Kamerayı yavaşça zemine tutun ve dokunun.");
  }

  void _addPlaneImage(ARKitTestResult hit) {
    _placing = true;
    try {
      final material = ARKitMaterial(
        diffuse: ARKitMaterialProperty.image(widget.imagePath),
        // Işıksız ortamda bile resmin net görünmesini sağlar
        emission: ARKitMaterialProperty.image(widget.imagePath),
        transparency: _opacity,
        doubleSided: true,
      );

      final plane = ARKitPlane(
        width: 1.0,
        height: 1.0,
        materials: [material],
      );

      _posX = hit.worldTransform.getColumn(3).x;
      _posZ = hit.worldTransform.getColumn(3).z;
      final startY = hit.worldTransform.getColumn(3).y + _liftMeters;

      // 1. GÖRÜNMEZ TEPSİYİ YARAT (Hareket ve dönüş buraya uygulanır)
      parentNode = ARKitNode(
        position: v.Vector3(_posX, startY, _posZ),
        eulerAngles: v.Vector3(0, _rotYRad, 0), // Sadece yere paralel döner
        scale: v.Vector3.all(_scale), // Büyüme/küçülme tepsiye uygulanır
      );
      arkitController!.add(parentNode!);

      // 2. RESMİ YARAT VE TEPSİYE MÜHÜRLE
      imageNode = ARKitNode(
        geometry: plane,
        position: v.Vector3.zero(),
        // 🔴 KESİN ÇÖZÜM: Resim sonsuza kadar masaya yatık kalır (-90 derece) ve bir daha ASLA güncellenmez.
        eulerAngles: v.Vector3(-math.pi / 2, 0, 0),
      );

      arkitController!.add(imageNode!, parentNodeName: parentNode!.name);

      _showToast("✅ Resim Masaya Serildi!");
      setState(() {});
    } catch (e) {
      _showToast("❌ Hata: $e");
    } finally {
      _placing = false;
    }
  }

  // ✅ SADECE TEPSİ GÜNCELLENİR: Resim asla bozulmaz!
  void _updateParentTransform() {
    if (!_hasModel) return;

    parentNode!.position = v.Vector3(_posX, parentNode!.position.y, _posZ);
    parentNode!.eulerAngles =
        v.Vector3(0, _rotYRad, 0); // Sadece pikap gibi Y ekseninde döner
    parentNode!.scale = v.Vector3.all(_scale);

    arkitController?.update(parentNode!.name, node: parentNode!);
  }

  void _updateOpacity(double newOpacity) {
    setState(() => _opacity = newOpacity);
    if (imageNode == null) return;

    final newMaterial = ARKitMaterial(
      diffuse: ARKitMaterialProperty.image(widget.imagePath),
      emission: ARKitMaterialProperty.image(widget.imagePath),
      transparency: _opacity,
      doubleSided: true,
    );

    imageNode!.geometry!.materials.value = [newMaterial];
  }

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseRotYRad = _rotYRad;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_hasModel || _tapLocked) return;

    setState(() {
      if (d.pointerCount > 1) {
        // İki Parmak: Büyütme ve Döndürme
        _scale = (_baseScale * d.scale).clamp(0.05, 3.0);
        _rotYRad = _baseRotYRad + d.rotation;
      } else {
        // Tek Parmak: Masanın üzerinde sürükleme
        _posX += d.focalPointDelta.dx * 0.002;
        _posZ += d.focalPointDelta.dy * 0.002;
      }
    });

    _updateParentTransform();
  }

  void _clearAll() {
    if (parentNode != null) {
      arkitController?.remove(parentNode!.name);
    }
    setState(() {
      parentNode = null;
      imageNode = null;
      _scale = 0.3;
      _rotYRad = -math.pi / 2;
      _liftMeters = 0.0;
      _tiltMode = 0;
      _mirrored = false;
    });
    _showToast("Temizlendi. Tekrar dokunabilirsin.");
  }

  void _toggleGrid() => setState(() => _gridMode =
      (_gridMode == 0) ? 3 : (_gridMode == 3 ? 4 : (_gridMode == 4 ? 5 : 0)));

  void _toggleTilt() {
    setState(() => _tiltMode = (_tiltMode + 1) % 3);
  }

  void _toggleMirror() {
    setState(() => _mirrored = !_mirrored);
    if (parentNode != null) {
      final currentScale = parentNode!.scale;
      // Aynalama da tepsiye uygulanır
      parentNode!.scale =
          v.Vector3(-currentScale.x, currentScale.y, currentScale.z);
      arkitController?.update(parentNode!.name, node: parentNode!);
    }
  }

  void _rotPlus90() {
    setState(() => _rotYRad += (math.pi / 2));
    _updateParentTransform();
  }

  void _liftUp() {
    if (parentNode == null) return;
    setState(() => _liftMeters += 0.01);
    parentNode!.position =
        v.Vector3(_posX, parentNode!.position.y + 0.01, _posZ);
    arkitController?.update(parentNode!.name, node: parentNode!);
  }

  // ✅ EĞRETİ/HAVADA DURMA ÇÖZÜMÜ: Bu butona basarak resmi masaya gömebilirsin
  void _liftDown() {
    if (parentNode == null) return;
    setState(() => _liftMeters -= 0.01);
    parentNode!.position =
        v.Vector3(_posX, parentNode!.position.y - 0.01, _posZ);
    arkitController?.update(parentNode!.name, node: parentNode!);
  }

  void _toggleFlash() => setState(() => _flashOn = !_flashOn);
  void _toggleRecording() => setState(() => _isRecording = !_isRecording);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ARKitSceneView(
            onARKitViewCreated: _onARKitViewCreated,
            planeDetection: ARPlaneDetection.horizontal,
            enableTapRecognizer: true,
          ),
          if (_hasModel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          if (_gridMode > 0)
            IgnorePointer(
              child: Positioned.fill(
                child: RepaintBoundary(
                  child:
                      CustomPaint(painter: GridPainter(gridCount: _gridMode)),
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
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
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
                          icon:
                              const Icon(Icons.apple, color: Colors.cyanAccent),
                          label: const Text("PRO AR MODU (iOS)",
                              style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        if (_toastText.isNotEmpty)
                          Text(_toastText,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        IconButton(
                            onPressed: _clearAll,
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white)),
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
                      borderRadius: BorderRadius.circular(20)),
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
                          onChanged: _updateOpacity,
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
                        gradient: LinearGradient(colors: [
                          Colors.black.withValues(alpha: 0.70),
                          Colors.black.withValues(alpha: 0.50)
                        ]),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
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
                                _toggleRecording),
                            const SizedBox(width: 8),
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
                            // Y- BUTONU İLE MASAYA GÖMEBİLİRSİN
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
                            const SizedBox(width: 8),
                            _btn(_flashOn ? Icons.flash_on : Icons.flash_off,
                                "Flaş", _flashOn, Colors.amber, _toggleFlash),
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
                      colors: [activeColor, activeColor.withValues(alpha: 0.6)])
                  : LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.06)
                    ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isActive
                      ? activeColor.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.10),
                  width: 1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
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
