import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import '../models/category_model.dart';

class DrawingScreen extends StatefulWidget {
  final CategoryModel category;
  final List<CameraDescription> cameras;
  final String imagePath; // ✅ EKLENEN 1: Resim yolu değişkeni

  const DrawingScreen({
    super.key,
    required this.category,
    required this.cameras,
    required this.imagePath, // ✅ EKLENEN 2: Zorunlu parametre
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  CameraController? controller;
  bool isCameraReady = false;

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

    // 🔥 OPTİMİZASYON: Medium (720p) performans için iyidir.
    controller =
        CameraController(cams[0], ResolutionPreset.medium, enableAudio: false);

    try {
      await controller!.initialize();
      if (!mounted) return;
      setState(() => isCameraReady = true);
    } catch (e) {
      debugPrint("Kamera Başlatma Hatası: $e");
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    _recordingTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  // --- FONKSİYONLAR ---
  void togglePaper() => setState(() => _paperMode = (_paperMode + 1) % 3);

  void toggleGrid() => setState(() {
        if (_gridMode == 0)
          _gridMode = 3;
        else if (_gridMode == 3)
          _gridMode = 4;
        else if (_gridMode == 4)
          _gridMode = 5;
        else
          _gridMode = 0;
      });

  void togglePerspective() =>
      setState(() => _perspectiveMode = (_perspectiveMode + 1) % 3);

  Future<void> toggleRecording() async {
    if (controller == null || !controller!.value.isInitialized) return;

    if (isRecording) {
      try {
        final file = await controller!.stopVideoRecording();
        _recordingTimer?.cancel();
        setState(() {
          isRecording = false;
          _recordDuration = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Video Galeriye Kaydedildi"),
                backgroundColor: Colors.green),
          );
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

  @override
  Widget build(BuildContext context) {
    // ✅ EKLENEN 3: Artık gelen 'imagePath'i kullanıyoruz.
    String imageToDisplay = widget.imagePath;

    double perspectiveAngle =
        _perspectiveMode == 0 ? 0 : (_perspectiveMode == 1 ? 0.35 : 0.70);

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
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height),
                    painter: PaperFramePainter(isLandscape: _paperMode == 2),
                  ),
                ),
              ),
            ),

          // 3. RESİM VE IZGARA (Interactive Viewer)
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
                        // Resim
                        Container(
                          decoration: BoxDecoration(
                            border: !isGhostLocked
                                ? Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                    style: BorderStyle.solid)
                                : null,
                          ),
                          child: Image.asset(
                            imageToDisplay,
                            opacity: AlwaysStoppedAnimation(_opacity),
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Icon(
                                Icons.broken_image,
                                color: Colors.red,
                                size: 50),
                          ),
                        ),
                        // Izgara
                        if (_gridMode > 0)
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: GridPainter(gridCount: _gridMode),
                              ),
                            ),
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
              children: [
                // --- ÜST BAR ---
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(30),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const BackButton(color: Colors.white),
                            if (isRecording)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.circle,
                                        color: Colors.white, size: 10),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDuration(_recordDuration),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Expanded(
                                child: Text(
                                  widget.category.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0),
                                ),
                              ),
                            if (!isRecording)
                              _buildTopIconBtn(
                                  _paperMode == 0
                                      ? Icons.crop_free
                                      : (_paperMode == 1
                                          ? Icons.crop_portrait
                                          : Icons.crop_landscape),
                                  _paperMode > 0,
                                  togglePaper),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // --- ALT KONTROL PANELİ ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(
                              color: isRecording
                                  ? Colors.redAccent.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.15),
                              width: 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // AKILLI SLIDER
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _isOpacityMode = !_isOpacityMode),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.white10,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white24)),
                                      child: Icon(
                                          _isOpacityMode
                                              ? Icons.opacity
                                              : Icons.rotate_right,
                                          color: _isOpacityMode
                                              ? Colors.cyanAccent
                                              : Colors.purpleAccent,
                                          size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: _isOpacityMode
                                            ? Colors.cyanAccent
                                            : Colors.purpleAccent,
                                        inactiveTrackColor: Colors.white10,
                                        thumbColor: Colors.white,
                                        overlayColor: (_isOpacityMode
                                                ? Colors.cyanAccent
                                                : Colors.purpleAccent)
                                            .withOpacity(0.2),
                                        trackHeight: 3.0,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 8),
                                      ),
                                      child: Slider(
                                        value: _isOpacityMode
                                            ? _opacity
                                            : _rotationAngle,
                                        onChanged: (v) => setState(() {
                                          if (_isOpacityMode) {
                                            _opacity = v;
                                          } else {
                                            _rotationAngle = v;
                                          }
                                        }),
                                        min: 0.0,
                                        max: _isOpacityMode ? 1.0 : 360.0,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      _isOpacityMode
                                          ? "%${(_opacity * 100).toInt()}"
                                          : "${_rotationAngle.toInt()}°",
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.end,
                                    ),
                                  )
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // BUTONLAR
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildModernBtn(
                                    icon: isRecording
                                        ? Icons.stop_circle_outlined
                                        : Icons.videocam,
                                    label: isRecording ? "Durdur" : "Kaydet",
                                    isActive: isRecording,
                                    activeColor: Colors.redAccent,
                                    isPulse: isRecording,
                                    onTap: toggleRecording,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildModernBtn(
                                    icon: isGhostLocked
                                        ? Icons.lock
                                        : Icons.lock_open,
                                    label: "Kilit",
                                    isActive: isGhostLocked,
                                    activeColor: Colors.redAccent,
                                    onTap: () => setState(
                                        () => isGhostLocked = !isGhostLocked),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildModernBtn(
                                    icon: Icons.view_in_ar,
                                    label: _perspectiveMode == 0
                                        ? "Eğim"
                                        : "${_perspectiveMode}x",
                                    isActive: _perspectiveMode > 0,
                                    activeColor: Colors.orangeAccent,
                                    onTap: togglePerspective,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildModernBtn(
                                    icon: Icons.flip,
                                    label: "Ayna",
                                    isActive: isFlipped,
                                    activeColor: Colors.blueAccent,
                                    onTap: () =>
                                        setState(() => isFlipped = !isFlipped),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildModernBtn(
                                    icon: Icons.rotate_90_degrees_cw,
                                    label: "+90°",
                                    isActive: false,
                                    activeColor: Colors.white,
                                    onTap: () => setState(() => _rotationAngle =
                                        (_rotationAngle + 90) % 360),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildModernBtn(
                                    icon: Icons.grid_on,
                                    label: _gridMode == 0
                                        ? "Izgara"
                                        : "${_gridMode}x",
                                    isActive: _gridMode > 0,
                                    activeColor: Colors.greenAccent,
                                    onTap: toggleGrid,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildModernBtn(
                                    icon: isFlashOn
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    label: "Flaş",
                                    isActive: isFlashOn,
                                    activeColor: Colors.amber,
                                    onTap: () {
                                      setState(() => isFlashOn = !isFlashOn);
                                      controller?.setFlashMode(isFlashOn
                                          ? FlashMode.torch
                                          : FlashMode.off);
                                    },
                                  ),
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

  // --- MODERN BUTON WIDGET ---
  Widget _buildModernBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    bool isPulse = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [activeColor, activeColor.withOpacity(0.6)])
                  : LinearGradient(colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05)
                    ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isActive
                      ? activeColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.4),
                        blurRadius: isPulse ? 15 : 8,
                        spreadRadius: isPulse ? 2 : 0,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Icon(icon,
                color: isActive ? Colors.white : Colors.white70, size: 22),
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

  Widget _buildTopIconBtn(IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? Colors.orangeAccent : Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// PAINTERS
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

    RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, rectW, rectH), const Radius.circular(12));
    canvas.drawRRect(rrect, paint);
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
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
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
