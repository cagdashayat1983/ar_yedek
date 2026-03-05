// lib/screens/tutorial_screen.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/speech_service.dart';

class TutorialScreen extends StatefulWidget {
  final String title;
  final List<String> imagePaths;
  final List<CameraDescription> cameras;
  final int initialStep;
  final bool isLocalFile;

  const TutorialScreen({
    super.key,
    required this.title,
    required this.imagePaths,
    required this.cameras,
    this.initialStep = 0,
    this.isLocalFile = false,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  late int _currentStep;
  late PageController _pageController;
  CameraController? controller;
  bool isCameraReady = false;

  double _opacity = 0.55;
  bool isGhostLocked = false;
  bool isFlashOn = false;
  bool isFlipped = false;
  int _gridMode = 0;

  // Serbest Kaydırma, Yakınlaştırma ve Döndürme (Pinch) için değişkenler
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  double _rotationAngle = 0.0;
  double _baseRotationAngle = 0.0;

  late ConfettiController _confettiController;
  bool _showCelebration = false;

  // 🎤 Voice
  bool _isListening = false;
  DateTime _lastCommandTime = DateTime.now();
  String _lastProcessedText = "";
  final SpeechService _speechService = SpeechService();

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: widget.initialStep);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    initializeCamera().then((_) {
      _checkPermissionsAndInitVoice();
    });
  }

  Future<void> _checkPermissionsAndInitVoice() async {
    debugPrint("🎤 [PERMISSION] Mikrofon izni kontrol ediliyor...");
    final status = await Permission.microphone.request();

    if (!mounted) return;

    if (status.isGranted) {
      debugPrint("✅ [PERMISSION] Mikrofon izni verildi.");
      _initVoiceControl();
    } else {
      debugPrint("❌ [PERMISSION] Mikrofon izni REDDEDİLDİ.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sesli komutlar için mikrofon izni gerekli."),
        ),
      );
    }
  }

  Future<void> _initVoiceControl() async {
    debugPrint("🚀 [SPEECH] Init...");
    try {
      final isReady = await _speechService.initSpeech();
      if (!mounted) return;

      if (isReady) {
        await _speechService.startListening((spokenWords) {
          _handleVoiceCommand(spokenWords);
        });
        if (mounted) setState(() => _isListening = true);
      }
    } catch (e) {
      debugPrint("❌ [SPEECH] Init error: $e");
    }
  }

  void _handleVoiceCommand(String spokenWords) {
    final clean = spokenWords.toLowerCase().trim();
    String newText = clean;
    if (clean.startsWith(_lastProcessedText) && _lastProcessedText.isNotEmpty) {
      newText = clean.substring(_lastProcessedText.length).trim();
    } else {
      newText = clean;
    }

    if (newText.isEmpty) return;

    if (DateTime.now().difference(_lastCommandTime).inMilliseconds <= 1200) {
      _lastProcessedText = clean;
      return;
    }

    final t = newText
        .replaceAll(RegExp(r"[^\w\sçğıöşü%\.]"), " ")
        .replaceAll(RegExp(r"\s+"), " ")
        .trim();

    bool hasAny(List<String> keys) {
      final words = t.split(" ");
      return keys.any((k) {
        if (k.contains(" ")) return t.contains(k);
        return words.contains(k);
      });
    }

    bool commandMatched = false;

    final goStepKeys = <String>["step", "adım", "adıma", "git", "geç", "gec"];
    if (hasAny(goStepKeys)) {
      final step = _extractStepNumber(t);
      if (step != null) {
        _goToStep(step);
        commandMatched = true;
      }
    }

    if (!commandMatched) {
      final opacityKeys = <String>[
        "opacity",
        "transparent",
        "transparency",
        "alpha",
        "opaklık",
        "opaklik",
        "saydamlık",
        "saydamlik",
        "şeffaflık",
        "seffaflik",
        "görünürlük",
        "gorunurluk"
      ];
      if (hasAny(opacityKeys)) {
        final value = _extractOpacityValue(t);
        if (value != null) {
          _setOpacity(value);
          commandMatched = true;
        }
      }
    }

    if (!commandMatched) {
      final gridKeys = <String>[
        "grid",
        "ızgara",
        "izgara",
        "kılavuz",
        "kilavuz"
      ];
      if (hasAny(gridKeys)) {
        final grid = _extractGridValue(t);
        if (grid != null) {
          _setGrid(grid);
        } else {
          toggleGrid();
        }
        commandMatched = true;
      }
    }

    if (!commandMatched) {
      final lockKeys = <String>[
        "lock",
        "freeze",
        "kilitle",
        "kilit",
        "sabitle",
        "dondur"
      ];
      final unlockKeys = <String>[
        "unlock",
        "unfreeze",
        "kilidi aç",
        "kilidi ac",
        "aç",
        "ac",
        "serbest",
        "çöz",
        "coz"
      ];
      final wantsLock = hasAny(lockKeys);
      final wantsUnlock = hasAny(unlockKeys);

      if (wantsLock != wantsUnlock) {
        _setLock(wantsLock);
        commandMatched = true;
      }
    }

    if (!commandMatched) {
      final flipKeys = <String>[
        "flip",
        "mirror",
        "ayna",
        "aynala",
        "çevir",
        "cevir",
        "ters"
      ];
      if (hasAny(flipKeys)) {
        _toggleFlip();
        commandMatched = true;
      }
    }

    if (!commandMatched) {
      final nextKeys = <String>[
        "next",
        "go",
        "forward",
        "ileri",
        "ilerle",
        "sonraki",
        "devam"
      ];
      final prevKeys = <String>[
        "back",
        "prev",
        "previous",
        "geri",
        "geriye",
        "önceki",
        "onceki",
        "dön",
        "don"
      ];

      final isNext = hasAny(nextKeys);
      final isPrev = hasAny(prevKeys);

      if (isNext != isPrev) {
        if (isNext) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _nextStep());
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => _prevStep());
        }
        commandMatched = true;
      }
    }

    if (commandMatched) {
      _lastProcessedText = clean;
      _lastCommandTime = DateTime.now();
      debugPrint("✅ KOMUT ÇALIŞTI. Yeni Hafıza: $_lastProcessedText");
    }
  }

  void _setOpacity(double value01) {
    final v = value01.clamp(0.1, 1.0);
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _opacity = v);
  }

  void _setGrid(int grid) {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _gridMode = grid);
  }

  void _setLock(bool lock) {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => isGhostLocked = lock);
  }

  void _toggleFlip() {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => isFlipped = !isFlipped);
  }

  void _rotateImage() {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      _rotationAngle += math.pi / 2; // 90 derece
    });
  }

  int? _extractStepNumber(String t) {
    final m = RegExp(r'(\d{1,2})').firstMatch(t);
    if (m != null) return int.tryParse(m.group(1)!);
    final map = <String, int>{
      "one": 1,
      "two": 2,
      "three": 3,
      "four": 4,
      "five": 5,
      "six": 6,
      "seven": 7,
      "eight": 8,
      "nine": 9,
      "ten": 10,
      "bir": 1,
      "iki": 2,
      "üç": 3,
      "uc": 3,
      "dört": 4,
      "dort": 4,
      "beş": 5,
      "bes": 5,
      "altı": 6,
      "alti": 6,
      "yedi": 7,
      "sekiz": 8,
      "dokuz": 9,
      "on": 10,
    };
    for (final e in map.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return null;
  }

  double? _extractOpacityValue(String t) {
    final textToNumber = <String, String>{
      "on": "10",
      "yirmi": "20",
      "otuz": "30",
      "kırk": "40",
      "kirk": "40",
      "elli": "50",
      "altmış": "60",
      "altmis": "60",
      "yetmiş": "70",
      "yetmis": "70",
      "seksen": "80",
      "doksan": "90",
      "yüz": "100",
      "yuz": "100",
      "yarı": "50",
      "yari": "50",
      "yarım": "50",
      "yarim": "50",
      "ten": "10",
      "twenty": "20",
      "thirty": "30",
      "forty": "40",
      "fifty": "50",
      "sixty": "60",
      "seventy": "70",
      "eighty": "80",
      "ninety": "90",
      "hundred": "100",
      "half": "50"
    };
    String parsedText = t;
    textToNumber.forEach((key, value) {
      parsedText = parsedText.replaceAll(RegExp(r'\b' + key + r'\b'), value);
    });
    final hasPercentWord =
        parsedText.contains("yüzde") || parsedText.contains("percent");
    final percentMatch = RegExp(r'(\d{1,3})\s*%').firstMatch(parsedText);
    if (percentMatch != null) {
      final p = int.tryParse(percentMatch.group(1)!);
      if (p == null) return null;
      return (p / 100.0).clamp(0.1, 1.0);
    }
    if (hasPercentWord) {
      final m = RegExp(r'(\d{1,3})').firstMatch(parsedText);
      final p = m != null ? int.tryParse(m.group(1)!) : null;
      if (p == null) return null;
      return (p / 100.0).clamp(0.1, 1.0);
    }
    final m2 = RegExp(r'(\d+(\.\d+)?)').firstMatch(parsedText);
    if (m2 != null) {
      final raw = double.tryParse(m2.group(1)!);
      if (raw == null) return null;
      if (raw > 1.0) return (raw / 100.0).clamp(0.1, 1.0);
      return raw.clamp(0.1, 1.0);
    }
    return null;
  }

  int? _extractGridValue(String t) {
    if (t.contains("off") || t.contains("kapat") || t.contains("disable")) {
      return 0;
    }
    final m = RegExp(r'(\d)').firstMatch(t);
    final n = m != null ? int.tryParse(m.group(1)!) : null;
    if (n == 3 || n == 4 || n == 5) return n;
    if (t.contains("three") || t.contains("üç") || t.contains("uc")) return 3;
    if (t.contains("four") || t.contains("dört") || t.contains("dort")) {
      return 4;
    }
    if (t.contains("five") || t.contains("beş") || t.contains("bes")) return 5;
    return null;
  }

  void _goToStep(int step1Based) {
    final maxStep = widget.imagePaths.length;
    final target = step1Based.clamp(1, maxStep) - 1;
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller!.initialize();
      if (!mounted) return;
      setState(() => isCameraReady = true);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _toggleFlash() async {
    if (controller == null) return;
    HapticFeedback.selectionClick();
    try {
      final next = !isFlashOn;
      await controller!.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => isFlashOn = next);
    } catch (e) {
      debugPrint("Flash Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Flash desteklenmiyor.")),
      );
    }
  }

  @override
  void dispose() {
    _speechService.stopListening();
    controller?.dispose();
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < widget.imagePaths.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _finishTutorial();
    }
  }

  void _prevStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finishTutorial() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_${widget.title}', true);
    final currentXp = prefs.getInt('total_xp') ?? 0;
    await prefs.setInt('total_xp', currentXp + 100);
    if (!mounted) return;
    setState(() => _showCelebration = true);
    _confettiController.play();
  }

  void toggleGrid() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_gridMode == 0) {
        _gridMode = 3;
      } else if (_gridMode == 3) {
        _gridMode = 4;
      } else if (_gridMode == 4) {
        _gridMode = 5;
      } else {
        _gridMode = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Kamera Önizlemesi
          if (isCameraReady && controller != null)
            SizedBox.expand(child: CameraPreview(controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // 2. Karartma Efekti
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.0,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
          ),

          // 3. Yakınlaştırma, Kaydırma ve Ekrandan Döndürme Alanı
          _buildAROverlay(),

          // 4. SOL OK (Geri)
          if (_currentStep > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _sideArrowButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: _prevStep,
                ),
              ),
            ),

          // 5. SAĞ OK (İleri) - SADECE son sayfaya gelene kadar görünür.
          if (_currentStep < widget.imagePaths.length - 1)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _sideArrowButton(
                  icon: Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  onPressed: _nextStep,
                ),
              ),
            ),

          // 6. En Alt Menü
          _buildBottomControls(),

          // 7. Kutlama
          if (_showCelebration) _buildCelebrationOverlay(),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
            createParticlePath: drawStar,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final stepText = "${_currentStep + 1}/${widget.imagePaths.length}";
    final isLastStep = _currentStep == widget.imagePaths.length - 1;

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title.toUpperCase(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 10),
          _pill(stepText),
          const SizedBox(width: 8),
          if (_isListening)
            const Icon(Icons.mic_rounded, color: Colors.redAccent, size: 18),
        ],
      ),
      backgroundColor: Colors.black.withOpacity(0.35),
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        // ✅ YENİ: Sağ üst köşeye alınan zarif BİTİR (Yeşil Tik) Butonu
        if (isLastStep)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.check_circle_rounded,
                  color: Colors.greenAccent, size: 28),
              onPressed: _finishTutorial,
            ),
          )
      ],
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sideArrowButton(
      {required IconData icon,
      required VoidCallback onPressed,
      Color color = Colors.white}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: IconButton(
        iconSize: 34,
        padding: const EdgeInsets.all(12),
        color: color,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildAROverlay() {
    return IgnorePointer(
      ignoring: isGhostLocked,
      child: GestureDetector(
        onScaleStart: (details) {
          if (isGhostLocked) return;
          _baseScale = _scale;
          _baseRotationAngle = _rotationAngle;
        },
        onScaleUpdate: (details) {
          if (isGhostLocked) return;
          setState(() {
            _scale = (_baseScale * details.scale).clamp(0.1, 10.0);
            _rotationAngle = _baseRotationAngle + details.rotation;
            _offset += details.focalPointDelta;
          });
        },
        child: Container(
          color: Colors.transparent,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(_offset.dx, _offset.dy)
              ..scale(_scale)
              ..rotateZ(_rotationAngle)
              ..rotateY(isFlipped ? math.pi : 0),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.imagePaths.length,
                  onPageChanged: (index) =>
                      setState(() => _currentStep = index),
                  itemBuilder: (context, index) {
                    return Opacity(
                      opacity: _opacity,
                      child: widget.isLocalFile
                          ? Image.file(
                              File(widget.imagePaths[index]),
                              fit: BoxFit.contain,
                            )
                          : Image.asset(
                              widget.imagePaths[index],
                              fit: BoxFit.contain,
                            ),
                    );
                  },
                ),
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
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.40),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _controlBtn(
                            icon: isGhostLocked
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            label: isGhostLocked ? "Locked" : "Lock",
                            onPressed: () =>
                                setState(() => isGhostLocked = !isGhostLocked),
                            active: isGhostLocked,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _controlBtn(
                            icon: Icons.flip_rounded,
                            label: "Flip",
                            onPressed: () =>
                                setState(() => isFlipped = !isFlipped),
                            active: isFlipped,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _controlBtn(
                            icon: Icons.rotate_90_degrees_ccw_rounded,
                            label: "Rotate",
                            onPressed: _rotateImage,
                            active: _rotationAngle != 0.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _controlBtn(
                            icon: Icons.grid_on_rounded,
                            label: _gridMode == 0 ? "Grid" : "Grid $_gridMode",
                            onPressed: toggleGrid,
                            active: _gridMode != 0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _controlBtn(
                            icon: isFlashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            label: "Flash",
                            onPressed: _toggleFlash,
                            active: isFlashOn,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text("Opacity",
                            style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16)),
                            child: Slider(
                              value: _opacity,
                              min: 0.1,
                              max: 1.0,
                              activeColor: Colors.blueAccent,
                              inactiveColor: Colors.white24,
                              onChanged: (v) => setState(() => _opacity = v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _pill("${(_opacity * 100).round()}%"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool active = false}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: active
              ? Colors.white.withOpacity(0.20)
              : Colors.white.withOpacity(0.08),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600))
        ],
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        color: Colors.black.withOpacity(0.80),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.12))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Colors.amber, size: 86),
                  const SizedBox(height: 12),
                  Text("AWESOME!",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text("+100 XP",
                      style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 18),
                  SizedBox(
                      width: 180,
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          child: Text("CLOSE",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800)))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (math.pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * math.cos(step),
          halfWidth + externalRadius * math.sin(step));
      path.lineTo(
          halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * math.sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
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
