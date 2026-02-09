import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ EKLENDİ
import 'tutorial_screen.dart';

// 1. ZORLUK SEVİYESİ
enum Difficulty { easy, medium, hard }

extension DifficultyExtension on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return "BAŞLANGIÇ";
      case Difficulty.medium:
        return "ORTA SEVİYE";
      case Difficulty.hard:
        return "İLERİ SEVİYE";
    }
  }

  Color get color {
    switch (this) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.redAccent;
    }
  }
}

// 2. DERS MODELİ
class LessonModel {
  final String title;
  final String? coverImage;
  final List<String> steps;
  final Difficulty difficulty;

  LessonModel({
    required this.title,
    this.coverImage,
    required this.steps,
    required this.difficulty,
  });
}

class LearnScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LearnScreen({super.key, required this.cameras});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<LessonModel> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessonsFromSingleFolder();
  }

  // TEK KLASÖRDEN GRUPLAMA YAPAN FONKSİYON
  Future<void> _loadLessonsFromSingleFolder() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(
          DefaultAssetBundle.of(context));
      final allAssets = manifest.listAssets();

      final tutorialFiles = allAssets
          .where((String key) => key.contains('assets/tutorial/'))
          .where((String key) => key.endsWith('.png') || key.endsWith('.jpg'))
          .toList();

      Map<String, List<String>> groups = {};

      for (var file in tutorialFiles) {
        String fileName = file.split('/').last;
        if (fileName.contains('_')) {
          String lessonPrefix = fileName.split('_')[0];
          if (!groups.containsKey(lessonPrefix)) {
            groups[lessonPrefix] = [];
          }
          groups[lessonPrefix]!.add(file);
        }
      }

      List<LessonModel> loadedLessons = [];

      groups.forEach((lessonPrefix, files) {
        String? coverImg;
        List<String> stepImages = [];
        Difficulty diff = Difficulty.medium;

        for (var file in files) {
          String fileName = file.split('/').last.toLowerCase();

          if (fileName.contains('cover')) {
            coverImg = file;
            if (fileName.contains('easy'))
              diff = Difficulty.easy;
            else if (fileName.contains('hard'))
              diff = Difficulty.hard;
            else
              diff = Difficulty.medium;
          } else {
            stepImages.add(file);
          }
        }

        stepImages.sort((a, b) => a.compareTo(b));
        String displayTitle =
            lessonPrefix[0].toUpperCase() + lessonPrefix.substring(1);

        if (stepImages.isNotEmpty || coverImg != null) {
          loadedLessons.add(LessonModel(
            title: displayTitle,
            coverImage: coverImg,
            steps: stepImages,
            difficulty: diff,
          ));
        }
      });

      if (mounted) {
        setState(() {
          _lessons = loadedLessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ YENİ: DERS TIKLAMA MANTIĞI
  void _onLessonTap(LessonModel lesson) async {
    if (lesson.steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Bu dersin adımları eksik!", style: GoogleFonts.poppins()),
          backgroundColor: Colors.grey[800],
        ),
      );
      return;
    }

    // 1. Kaydedilmiş ilerlemeyi kontrol et
    final prefs = await SharedPreferences.getInstance();
    int? savedStep = prefs.getInt('progress_${lesson.title}');

    if (savedStep != null && savedStep > 0 && savedStep < lesson.steps.length) {
      // 2. Eğer kayıt varsa sor
      if (!mounted) return;
      _showResumeDialog(lesson, savedStep);
    } else {
      // 3. Kayıt yoksa direkt başla
      _startTutorial(lesson, 0);
    }
  }

  // ✅ YENİ: DEVAM ET / BAŞTAN BAŞLA DİYALOĞU
  void _showResumeDialog(LessonModel lesson, int step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Hoş Geldin! 👋",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "${lesson.title} çiziminde ${step + 1}. adımda kalmıştın. Kaldığın yerden devam etmek ister misin?",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startTutorial(lesson, 0); // Baştan başla
            },
            child: Text("Baştan Başla",
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTutorial(lesson, step); // Kaldığı yerden devam
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: lesson.difficulty.color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Devam Et (${step + 1}. Adım)",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ✅ YENİ: TUTORIAL BAŞLATMA YARDIMCISI
  void _startTutorial(LessonModel lesson, int startStep) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TutorialScreen(
          title: lesson.title,
          imagePaths: lesson.steps,
          cameras: widget.cameras,
          initialStep: startStep, // Başlangıç adımını gönderiyoruz
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Eğitim Merkezi",
            style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lessons.isEmpty
              ? Center(
                  child: Text(
                      "Ders bulunamadı.\nDosya isimlerinin 'dersadi_xx.png' formatında olduğundan emin olun."))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  itemCount: _lessons.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("AR ile Adım Adım Çiz",
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 20),
                          _buildLessonCard(context, _lessons[index]),
                        ],
                      );
                    }
                    return _buildLessonCard(context, _lessons[index]);
                  },
                ),
    );
  }

  // 🔥 KART TASARIMI
  Widget _buildLessonCard(BuildContext context, LessonModel lesson) {
    Color themeColor = lesson.difficulty.color;
    String levelLabel = lesson.difficulty.label;

    return GestureDetector(
      onTap: () => _onLessonTap(lesson), // ✅ ARTIK YENİ FONKSİYONU ÇAĞIRIYOR
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              // SOL TARAF: RESİM ALANI
              Container(
                width: 130,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(24)),
                ),
                child: Center(
                  child: lesson.coverImage != null
                      ? Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Image.asset(
                            lesson.coverImage!,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) =>
                                Icon(Icons.broken_image, color: themeColor),
                          ),
                        )
                      : Icon(Icons.image_not_supported_rounded,
                          color: themeColor.withOpacity(0.5), size: 40),
                ),
              ),

              // SAĞ TARAF: BİLGİLER (Aynı kaldı)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          levelLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: themeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "⏱ ${lesson.steps.length} Adım",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              color: themeColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: themeColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3))
                              ]),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("BAŞLA",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                              const SizedBox(width: 4),
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
