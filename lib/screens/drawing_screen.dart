// lib/screens/drawing_screen.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

// ✅ YENİ PAKETLER
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/category_model.dart';
import 'ar_mini_test_screen.dart';

class DrawingScreen extends StatefulWidget {
  final CategoryModel category;
  final List<CameraDescription> cameras;
  final String imagePath;

  const DrawingScreen({
    super.key,
    required this.category,
    required this.cameras,
    required this.imagePath,
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  CameraController? controller;
  bool isCameraReady = false;

  // ✅ PAYLAŞIM İÇİN CONTROLLER
  final ScreenshotController _screenshotController = ScreenshotController();

  // --- AYARLAR ---
  double _opacity = 0.5;
  double _scale = 1.0;
  bool isGhostLocked = false;
  bool isFlashOn = false;
  bool isFlipped = false;

  double _rotationAngle = 0.0;
  int _perspectiveMode = 0;
  bool _isOpacityMode = true;

  bool isRecording = false;
  Timer? _recordingTimer;
  int _recordDuration = 0;

  int _paperMode = 0;
  int _gridMode = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    List<CameraDescription> cams = widget.cameras;
    if (cams.isEmpty) {
      try {
        cams = await availableCameras();
      } catch (e) {
        debugPrint("Kamera Bulunamadı: $e");
      }
    }
    if (cams.isEmpty) return;

    controller =
        CameraController(cams[0], ResolutionPreset.high, enableAudio: false);

    try {
      await controller!.initialize();
      if (!mounted) return;
      setState(() => isCameraReady = true);
    } catch (e) {
      debugPrint("Kamera Başlatma Hatası: $e");
    }
  }

  // ✅ 5. ÖZELLİK: BAŞARI KARTI PAYLAŞMA FONKSİYONU
  void _shareMyArt() async {
    HapticFeedback.heavyImpact(); // Güçlü titreşim feedback'i

    // Paylaşılacak Kartın Görselleştirilmesi
    _screenshotController
        .captureFromWidget(Container(
      width: 400,
      height: 600,
      padding: const EdgeInsets.all(35),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text("HAYATIFY",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  letterSpacing: 8)),
          const SizedBox(height: 10),
          Text("ARTÜRKİYE'NİN SANAT PLATFORMU",
              style: GoogleFonts.poppins(
                  color: Colors.grey, fontSize: 8, letterSpacing: 2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: widget.imagePath.startsWith('assets/')
                  ? Image.asset(widget.imagePath,
                      height: 280, fit: BoxFit.contain)
                  : Image.file(File(widget.imagePath),
                      height: 280, fit: BoxFit.contain),
            ),
          ),
          const Spacer(),
          Text("BU ESERİ AR İLE ÇİZDİM",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("🎨 #Hayatify",
              style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 20),
        ],
      ),
    ))
        .then((Uint8List? image) async {
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imageFile =
            await File('${directory.path}/hayatify_achievement.png').create();
        await imageFile.writeAsBytes(image);

        // Cihazın paylaşım menüsünü aç
        await Share.shareXFiles([XFile(imageFile.path)],
            text: 'Hayatify ile sanatımı konuşturdum! Sen de dene.');
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _recordingTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  // --- YARDIMCI FONKSİYONLAR (DOKUNULMADI) ---
  String _modelPathFromTemplate(String templateAssetPath) {
    if (!templateAssetPath.startsWith('assets/')) return "";
    final normalized = templateAssetPath.replaceAll('\\', '/');
    const tplRoot = 'assets/templates/';
    if (!normalized.startsWith(tplRoot)) {
      final cleaned = normalized.startsWith('assets/')
          ? normalized.substring('assets/'.length)
          : normalized;
      return 'assets/models/${cleaned.replaceAll(RegExp(r'\.(png|webp|jpg|jpeg)$', caseSensitive: false), '.glb')}';
    }
    final relative = normalized.substring(tplRoot.length);
    final glbRelative = relative.replaceAll(
        RegExp(r'\.(png|webp|jpg|jpeg)$', caseSensitive: false), '.glb');
    return 'assets/models/$glbRelative';
  }

  void togglePaper() {
    HapticFeedback.selectionClick();
    setState(() => _paperMode = (_paperMode + 1) % 3);
  }

  void toggleGrid() {
    HapticFeedback.selectionClick();
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

  void togglePerspective() {
    HapticFeedback.selectionClick();
    setState(() => _perspectiveMode = (_perspectiveMode + 1) % 3);
  }

  Future<void> toggleRecording() async {
    HapticFeedback.mediumImpact();
    if (controller == null || !controller!.value.isInitialized) return;

    if (isRecording) {
      try {
        await controller!.stopVideoRecording();
        _recordingTimer?.cancel();
        setState(() {
          isRecording = false;
          _recordDuration = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Video Kaydedildi"),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        debugPrint("Kayıt hatası: $e");
      }
    } else {
      try {
        await controller!.startVideoRecording();
        setState(() => isRecording = true);
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
        });
      } catch (e) {
        debugPrint("Başlatma hatası: $e");
      }
    }
  }

  String _formatDuration(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildImageWidget() {
    final bool isAsset = widget.imagePath.startsWith('assets/');
    if (isAsset) {
      return Image.asset(
        widget.imagePath,
        opacity: AlwaysStoppedAnimation(_opacity),
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) =>
            const Icon(Icons.broken_image, color: Colors.red, size: 50),
      );
    } else {
      return Image.file(
        File(widget.imagePath),
        opacity: AlwaysStoppedAnimation(_opacity),
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) =>
            const Icon(Icons.image_not_supported, color: Colors.red, size: 40),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double perspectiveAngle =
        (_perspectiveMode == 0 ? 0.0 : (_perspectiveMode == 1 ? 0.35 : 0.70))
            .toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. KAMERA
          if (isCameraReady)
            SizedBox.expand(child: CameraPreview(controller!))
          else
            const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent)),

          // 2. KAĞIT ÇERÇEVESİ
          if (_paperMode > 0)
            IgnorePointer(
              child: Center(
                child: CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: PaperFramePainter(isLandscape: _paperMode == 2),
                ),
              ),
            ),

          // 3. RESİM VE IZGARA
          IgnorePointer(
            ignoring: isGhostLocked,
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              panEnabled: !isGhostLocked,
              scaleEnabled: !isGhostLocked,
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(perspectiveAngle)
                    ..rotateZ(_rotationAngle * math.pi / 180)
                    ..rotateY(isFlipped ? math.pi : 0)
                    ..scale(_scale),
                  child: IntrinsicWidth(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Hero(
                          tag: widget.imagePath,
                          child: Container(
                            decoration: BoxDecoration(
                              border: !isGhostLocked
                                  ? Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1.5)
                                  : null,
                              boxShadow: !isGhostLocked
                                  ? [
                                      BoxShadow(
                                          color: Colors.blueAccent
                                              .withOpacity(0.3),
                                          blurRadius: 10)
                                    ]
                                  : [],
                            ),
                            child: _buildImageWidget(),
                          ),
                        ),
                        if (_gridMode > 0)
                          Positioned.fill(
                            child: CustomPaint(
                                painter: GridPainter(gridCount: _gridMode)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. ARAYÜZ
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- ÜST BAR ---
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1)),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      if (isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(_formatDuration(_recordDuration),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )
                      else
                        Text(widget.category.title.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      if (!isRecording)
                        Row(
                          children: [
                            _buildTopIconBtn(
                                _paperMode == 0
                                    ? Icons.crop_free_rounded
                                    : (_paperMode == 1
                                        ? Icons.crop_portrait_rounded
                                        : Icons.crop_landscape_rounded),
                                _paperMode > 0,
                                togglePaper),
                            const SizedBox(width: 8),
                            if (widget.imagePath.startsWith('assets/'))
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  final glbPath =
                                      _modelPathFromTemplate(widget.imagePath);
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ARMiniTestScreen(
                                              glbAssetPath: glbPath)));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        Colors.purpleAccent,
                                        Colors.deepPurple
                                      ]),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: const Row(children: [
                                    Icon(Icons.view_in_ar_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text("AR",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))
                                  ]),
                                ),
                              ),
                          ],
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                const Spacer(),

                // --- ALT KONTROL PANELİ ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E).withOpacity(0.75),
                          borderRadius: BorderRadius.circular(32),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(
                                        () => _isOpacityMode = !_isOpacityMode);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _isOpacityMode
                                          ? Colors.cyanAccent.withOpacity(0.2)
                                          : Colors.purpleAccent
                                              .withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _isOpacityMode
                                              ? Colors.cyanAccent
                                              : Colors.purpleAccent),
                                    ),
                                    child: Icon(
                                        _isOpacityMode
                                            ? Icons.opacity_rounded
                                            : Icons.rotate_right_rounded,
                                        color: _isOpacityMode
                                            ? Colors.cyanAccent
                                            : Colors.purpleAccent,
                                        size: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: _isOpacityMode
                                          ? Colors.cyanAccent
                                          : Colors.purpleAccent,
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: _isOpacityMode
                                          ? _opacity
                                          : _rotationAngle,
                                      min: 0.0,
                                      max: _isOpacityMode ? 1.0 : 360.0,
                                      onChanged: (v) => setState(() {
                                        if (_isOpacityMode)
                                          _opacity = v;
                                        else
                                          _rotationAngle = v;
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 2. BUTONLAR
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildModernBtn(
                                      icon: isRecording
                                          ? Icons.stop_rounded
                                          : Icons.videocam_rounded,
                                      label: isRecording ? "Durdur" : "Kaydet",
                                      isActive: isRecording,
                                      activeColor: Colors.redAccent,
                                      isPulse: isRecording,
                                      onTap: toggleRecording),
                                  const SizedBox(width: 10),
                                  // ✅ YENİ: PAYLAŞ BUTONU
                                  _buildModernBtn(
                                      icon: Icons.share_rounded,
                                      label: "Paylaş",
                                      isActive: false,
                                      activeColor: Colors.amber,
                                      onTap: _shareMyArt),
                                  const SizedBox(width: 10),
                                  _buildModernBtn(
                                      icon: isGhostLocked
                                          ? Icons.lock_rounded
                                          : Icons.lock_open_rounded,
                                      label: "Kilitle",
                                      isActive: isGhostLocked,
                                      activeColor: Colors.amber,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() =>
                                            isGhostLocked = !isGhostLocked);
                                      }),
                                  const SizedBox(width: 10),
                                  _buildModernBtn(
                                      icon: Icons.view_in_ar_rounded,
                                      label: _perspectiveMode == 0
                                          ? "Perspektif"
                                          : "${_perspectiveMode}x",
                                      isActive: _perspectiveMode > 0,
                                      activeColor: Colors.orangeAccent,
                                      onTap: togglePerspective),
                                  const SizedBox(width: 10),
                                  _buildModernBtn(
                                      icon: Icons.flip_rounded,
                                      label: "Ayna",
                                      isActive: isFlipped,
                                      activeColor: Colors.blueAccent,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => isFlipped = !isFlipped);
                                      }),
                                  const SizedBox(width: 10),
                                  _buildModernBtn(
                                      icon: Icons.grid_on_rounded,
                                      label: _gridMode == 0
                                          ? "Izgara"
                                          : "${_gridMode}x",
                                      isActive: _gridMode > 0,
                                      activeColor: Colors.greenAccent,
                                      onTap: toggleGrid),
                                  const SizedBox(width: 10),
                                  _buildModernBtn(
                                      icon: isFlashOn
                                          ? Icons.flash_on_rounded
                                          : Icons.flash_off_rounded,
                                      label: "Flaş",
                                      isActive: isFlashOn,
                                      activeColor: Colors.yellowAccent,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => isFlashOn = !isFlashOn);
                                        controller?.setFlashMode(isFlashOn
                                            ? FlashMode.torch
                                            : FlashMode.off);
                                      }),
                                ],
                              ),
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

  // --- MODERN BUTON TASARIMI ---
  Widget _buildModernBtn(
      {required IconData icon,
      required String label,
      required bool isActive,
      required Color activeColor,
      required VoidCallback onTap,
      bool isPulse = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [activeColor, activeColor.withOpacity(0.7)])
                  : LinearGradient(colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04)
                    ]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: isActive
                      ? activeColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1)),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                          color: activeColor.withOpacity(0.4),
                          blurRadius: isPulse ? 12 : 8)
                    ]
                  : [],
            ),
            child: Icon(icon,
                color: isActive ? Colors.black87 : Colors.white70, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: isActive ? activeColor : Colors.white54,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildTopIconBtn(IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: isActive ? Colors.orangeAccent : Colors.white10,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.1))),
        child:
            Icon(icon, color: isActive ? Colors.black : Colors.white, size: 18),
      ),
    );
  }
}

// PAINTERS (DOKUNULMADI)
class PaperFramePainter extends CustomPainter {
  final bool isLandscape;
  PaperFramePainter({required this.isLandscape});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    double screenW = size.width;
    double screenH = size.height;
    double rectW, rectH;
    if (isLandscape) {
      rectW = screenW * 0.8;
      rectH = rectW / 1.414;
    } else {
      rectH = screenH * 0.6;
      rectW = rectH / 1.414;
    }
    double left = (screenW - rectW) / 2;
    double top = (screenH - rectH) / 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, rectW, rectH), const Radius.circular(12)),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  final int gridCount;
  GridPainter({required this.gridCount});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    double w = size.width / gridCount;
    double h = size.height / gridCount;
    for (int i = 1; i < gridCount; i++) {
      canvas.drawLine(Offset(w * i, 0), Offset(w * i, size.height), paint);
      canvas.drawLine(Offset(0, h * i), Offset(size.width, h * i), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
