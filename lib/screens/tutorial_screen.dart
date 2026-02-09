import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ EKLENDİ
import 'dart:math' as math;

class TutorialScreen extends StatefulWidget {
  final String title;
  final List<String> imagePaths;
  final List<CameraDescription> cameras;
  final int initialStep; // ✅ YENİ: Başlangıç adımı parametresi

  const TutorialScreen({
    super.key,
    required this.title,
    required this.imagePaths,
    required this.cameras,
    this.initialStep = 0, // Varsayılan 0 (En baş)
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late int _currentStep; // ✅ late yaptık
  late PageController _pageController; // ✅ late yaptık
  CameraController? controller;
  bool isCameraReady = false;

  // --- ARAÇ DURUMLARI ---
  double _opacity = 0.5;
  bool isGhostLocked = false;
  bool isFlashOn = false;
  bool isFlipped = false;
  int _gridMode = 0;

  @override
  void initState() {
    super.initState();
    // ✅ YENİ: Başlangıç adımını ayarlıyoruz
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: widget.initialStep);

    initializeCamera();
  }

  // ✅ YENİ: İlerlemeyi kaydeden fonksiyon
  Future<void> _saveProgress(int step) async {
    final prefs = await SharedPreferences.getInstance();
    // Her dersin başlığına özel bir anahtar oluşturuyoruz (Örn: 'progress_Sevimli Kedi')
    await prefs.setInt('progress_${widget.title}', step);
  }

  Future<void> initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    controller = CameraController(widget.cameras[0], ResolutionPreset.high,
        enableAudio: false);
    try {
      await controller!.initialize();
      if (!mounted) return;
      setState(() => isCameraReady = true);
    } catch (e) {
      debugPrint("Kamera hatası: $e");
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- FONKSİYONLAR ---
  void _nextStep() {
    if (_currentStep < widget.imagePaths.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,

      // ÜST BAR
      appBar: AppBar(
        title: Text(widget.title,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24)),
                child: Text(
                  "${_currentStep + 1} / ${widget.imagePaths.length}",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14),
                ),
              ),
            ),
          )
        ],
      ),

      body: Stack(
        children: [
          // 1. KAMERA
          if (isCameraReady)
            SizedBox.expand(child: CameraPreview(controller!))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 2. ÇİZİM ALANI
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
                    ..rotateY(isFlipped ? math.pi : 0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        // Resim Slaytı
                        PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.imagePaths.length,
                          onPageChanged: (index) {
                            setState(() => _currentStep = index);
                            _saveProgress(
                                index); // ✅ DEĞİŞİKLİK: Her adımda kaydet
                          },
                          itemBuilder: (context, index) {
                            return Opacity(
                              opacity: _opacity,
                              child: Image.asset(
                                widget.imagePaths[index],
                                fit: BoxFit.contain,
                              ),
                            );
                          },
                        ),
                        // Izgara Katmanı
                        if (_gridMode > 0)
                          CustomPaint(
                            size: Size.infinite,
                            painter: GridPainter(gridCount: _gridMode),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. ALT KONTROL PANELİ
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.6, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.95),
                    Colors.black.withOpacity(0.6),
                    Colors.transparent
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- ARAÇ ÇUBUĞU ---
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildToolBtn(
                              icon:
                                  isGhostLocked ? Icons.lock : Icons.lock_open,
                              label: "Kilit",
                              isActive: isGhostLocked,
                              onTap: () => setState(
                                  () => isGhostLocked = !isGhostLocked),
                            ),
                            const SizedBox(width: 10),
                            _buildToolBtn(
                              icon:
                                  isFlashOn ? Icons.flash_on : Icons.flash_off,
                              label: "Flaş",
                              isActive: isFlashOn,
                              onTap: () {
                                setState(() => isFlashOn = !isFlashOn);
                                controller?.setFlashMode(isFlashOn
                                    ? FlashMode.torch
                                    : FlashMode.off);
                              },
                            ),
                            const SizedBox(width: 10),
                            _buildToolBtn(
                              icon: Icons.grid_on,
                              label:
                                  _gridMode == 0 ? "Izgara" : "${_gridMode}x",
                              isActive: _gridMode > 0,
                              onTap: toggleGrid,
                            ),
                            const SizedBox(width: 10),
                            _buildToolBtn(
                              icon: Icons.flip,
                              label: "Ayna",
                              isActive: isFlipped,
                              onTap: () =>
                                  setState(() => isFlipped = !isFlipped),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- OPACITY SLIDER ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.opacity,
                                color: Colors.white70, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.blueAccent,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                  trackHeight: 4.0,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 10),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 20),
                                ),
                                child: Slider(
                                  value: _opacity,
                                  min: 0.1,
                                  max: 1.0,
                                  onChanged: (value) =>
                                      setState(() => _opacity = value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // --- İLERİ / GERİ BUTONLARI ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _currentStep == 0 ? null : _prevStep,
                              icon: const Icon(Icons.arrow_back_ios_rounded,
                                  size: 20),
                              label: const Text("Geri"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white12,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      side: const BorderSide(
                                          color: Colors.white24))),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          Colors.blueAccent.withOpacity(0.5))),
                              child: Text(
                                "ADIM ${_currentStep + 1}",
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _nextStep,
                              icon: Icon(
                                  _currentStep == widget.imagePaths.length - 1
                                      ? Icons.check_circle
                                      : Icons.arrow_forward_ios_rounded,
                                  size: 20),
                              label: Text(
                                  _currentStep == widget.imagePaths.length - 1
                                      ? "Bitir"
                                      : "İleri"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30))),
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
    );
  }

  Widget _buildToolBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blueAccent : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? Colors.blueAccent : Colors.white24, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
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
      ..color = Colors.cyanAccent.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
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
