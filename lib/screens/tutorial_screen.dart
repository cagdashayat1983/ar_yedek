import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class TutorialScreen extends StatefulWidget {
  final String title;
  final List<String> imagePaths;
  final List<CameraDescription> cameras;
  final int initialStep;

  const TutorialScreen({
    super.key,
    required this.title,
    required this.imagePaths,
    required this.cameras,
    this.initialStep = 0,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late int _currentStep;
  late PageController _pageController;
  CameraController? controller;
  bool isCameraReady = false;

  double _opacity = 0.5;
  bool isGhostLocked = false;
  bool isFlashOn = false;
  bool isFlipped = false;
  int _gridMode = 0;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: widget.initialStep);
    initializeCamera();
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

  Future<void> _saveProgress(int step) async {
    final prefs = await SharedPreferences.getInstance();
    if (step < widget.imagePaths.length - 1) {
      await prefs.setInt('progress_${widget.title}', step);
    }
  }

  // ✅ GÜNCELLENMİŞ BİTİRME FONKSİYONU
  Future<void> _finishTutorial() async {
    HapticFeedback.vibrate();
    final prefs = await SharedPreferences.getInstance();

    // 1. Kilit Açma Verisi
    await prefs.setBool('completed_${widget.title}', true);

    // 2. ✅ ÇİZİM GEÇMİŞİNE KAYDET (Profil sayfan için bu çok önemli)
    final List<String> history = prefs.getStringList('drawing_history') ?? [];
    if (!history.contains(widget.title)) {
      history.add(widget.title);
      await prefs.setStringList('drawing_history', history);
    }

    // 3. İlerlemeyi Sıfırla
    await prefs.setInt('progress_${widget.title}', 0);

    // 4. XP Ekle
    int currentXp = prefs.getInt('total_xp') ?? 0;
    int newXp = currentXp + 100;
    await prefs.setInt('total_xp', newXp);

    if (mounted) {
      _showSuccessDialog(newXp);
    }
  }

  void _showSuccessDialog(int totalXp) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1E293B),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 80),
              const SizedBox(height: 16),
              Text("TEBRİKLER!",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24)),
              const SizedBox(height: 8),
              Text("+100 XP Kazandın",
                  style: GoogleFonts.poppins(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 18)),
              const SizedBox(height: 12),
              Text("Toplam Puanın: $totalXp",
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Dialogu kapat
                    Navigator.pop(context); // LearnScreen'e dön
                  },
                  child: const Text("HARİKA!",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < widget.imagePaths.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      _finishTutorial();
    }
  }

  void _prevStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          if (isCameraReady)
            SizedBox.expand(child: CameraPreview(controller!))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          _buildAROverlay(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.title.toUpperCase(),
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.2)),
      backgroundColor: Colors.black.withOpacity(0.4),
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24)),
            child: Text("${_currentStep + 1}/${widget.imagePaths.length}",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        )
      ],
    );
  }

  Widget _buildAROverlay() {
    return IgnorePointer(
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
            transform: Matrix4.identity()..rotateY(isFlipped ? math.pi : 0),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.imagePaths.length,
                    onPageChanged: (index) {
                      setState(() => _currentStep = index);
                      _saveProgress(index);
                    },
                    itemBuilder: (context, index) {
                      return Opacity(
                        opacity: _opacity,
                        child: Image.asset(widget.imagePaths[index],
                            fit: BoxFit.contain),
                      );
                    },
                  ),
                  if (_gridMode > 0)
                    CustomPaint(
                        size: Size.infinite,
                        painter: GridPainter(gridCount: _gridMode)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.9), Colors.transparent]),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolBtn(
                      icon: isGhostLocked
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      label: "Kilit",
                      isActive: isGhostLocked,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() => isGhostLocked = !isGhostLocked);
                      }),
                  const SizedBox(width: 10),
                  _buildToolBtn(
                      icon: isFlashOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      label: "Flaş",
                      isActive: isFlashOn,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => isFlashOn = !isFlashOn);
                        controller?.setFlashMode(
                            isFlashOn ? FlashMode.torch : FlashMode.off);
                      }),
                  const SizedBox(width: 10),
                  _buildToolBtn(
                      icon: Icons.grid_on_rounded,
                      label: "Izgara",
                      isActive: _gridMode > 0,
                      onTap: toggleGrid),
                  const SizedBox(width: 10),
                  _buildToolBtn(
                      icon: Icons.flip_rounded,
                      label: "Ayna",
                      isActive: isFlipped,
                      onTap: () => setState(() => isFlipped = !isFlipped)),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                const Icon(Icons.opacity_rounded,
                    color: Colors.white70, size: 20),
                Expanded(
                    child: Slider(
                        value: _opacity,
                        min: 0.1,
                        max: 1.0,
                        activeColor: Colors.blueAccent,
                        inactiveColor: Colors.white10,
                        onChanged: (v) => setState(() => _opacity = v))),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: "Geri",
                    onPressed: _currentStep == 0 ? null : _prevStep),
                _navBtn(
                    icon: _currentStep == widget.imagePaths.length - 1
                        ? Icons.done_all_rounded
                        : Icons.arrow_forward_ios_rounded,
                    label: _currentStep == widget.imagePaths.length - 1
                        ? "BİTİR"
                        : "İLERİ",
                    onPressed: _nextStep,
                    isPrimary: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(
      {required IconData icon,
      required String label,
      required VoidCallback? onPressed,
      bool isPrimary = false}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? (label == "BİTİR" ? Colors.green : Colors.blueAccent)
            : Colors.white10,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
    );
  }

  Widget _buildToolBtn(
      {required IconData icon,
      required String label,
      required bool isActive,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent : Colors.white12,
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
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
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int i = 1; i < gridCount; i++) {
      canvas.drawLine(Offset(size.width / gridCount * i, 0),
          Offset(size.width / gridCount * i, size.height), paint);
      canvas.drawLine(Offset(0, size.height / gridCount * i),
          Offset(size.width, size.height / gridCount * i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
