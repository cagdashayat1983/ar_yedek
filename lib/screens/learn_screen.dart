import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tutorial_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';
import 'categories_screen.dart';

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
  bool isLocked;
  bool isCompleted;

  LessonModel({
    required this.title,
    this.coverImage,
    required this.steps,
    required this.difficulty,
    this.isLocked = true,
    this.isCompleted = false,
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
  int _bottomIndex = 1;

  int _userXp = 0;
  final int _nextLevelThreshold = 2000;
  String _userRank = "Çaylak";

  @override
  void initState() {
    super.initState();
    _loadLessonsAndXp();
  }

  Future<void> _loadLessonsAndXp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userXp = prefs.getInt('total_xp') ?? 0;
      _userRank = _userXp >= _nextLevelThreshold ? "Çizimci" : "Çaylak";

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
          if (!groups.containsKey(lessonPrefix)) groups[lessonPrefix] = [];
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
            else if (fileName.contains('hard')) diff = Difficulty.hard;
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

      for (int i = 0; i < loadedLessons.length; i++) {
        bool isDone =
            prefs.getBool('completed_${loadedLessons[i].title}') ?? false;
        loadedLessons[i].isCompleted = isDone;
        if (i == 0) {
          loadedLessons[i].isLocked = false;
        } else {
          bool prevIsDone =
              prefs.getBool('completed_${loadedLessons[i - 1].title}') ?? false;
          loadedLessons[i].isLocked = !prevIsDone;
        }
      }

      if (mounted)
        setState(() {
          _lessons = loadedLessons;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onLessonTap(LessonModel lesson) async {
    if (lesson.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Önceki dersi tamamlamalısın! 🔒"),
            backgroundColor: Colors.redAccent),
      );
      HapticFeedback.heavyImpact();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    int? savedStep = prefs.getInt('progress_${lesson.title}');
    if (savedStep != null && savedStep > 0 && savedStep < lesson.steps.length) {
      _showResumeDialog(lesson, savedStep);
    } else {
      _startTutorial(lesson, 0);
    }
  }

  void _showResumeDialog(LessonModel lesson, int step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Devam Et?"),
        content: Text(
            "${lesson.title} dersine kaldığın yerden devam etmek ister misin?"),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startTutorial(lesson, 0);
              },
              child: const Text("Baştan")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTutorial(lesson, step);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: lesson.difficulty.color),
            child:
                const Text("Devam Et", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startTutorial(LessonModel lesson, int startStep) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => TutorialScreen(
                title: lesson.title,
                imagePaths: lesson.steps,
                cameras: widget.cameras,
                initialStep: startStep)));
    _loadLessonsAndXp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Gelişimim",
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: Text("$_userXp XP",
                      style: GoogleFonts.poppins(
                          color: Colors.blue, fontWeight: FontWeight.bold))))
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildXpHeader(),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _lessons.length,
                    itemBuilder: (context, index) =>
                        _buildLessonCard(_lessons[index]),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildXpHeader() {
    double progress = _userXp / _nextLevelThreshold;
    if (progress > 1.0) progress = 1.0;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userRank.toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.blue)),
                  const Text("Sanat Yolculuğu",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Text("%${(progress * 100).toInt()}",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue)),
          ),
          const SizedBox(height: 8),
          if (_userXp < _nextLevelThreshold)
            Text("${_nextLevelThreshold - _userXp} XP sonra Çizimci olacaksın!",
                style: const TextStyle(fontSize: 11, color: Colors.grey))
          else
            const Text("Tebrikler, artık bir Çizimci'sin! 🎨",
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ✅ YENİ GÜNCELLENMİŞ KART TASARIMI
  Widget _buildLessonCard(LessonModel lesson) {
    Color themeColor = lesson.isLocked ? Colors.grey : lesson.difficulty.color;

    return GestureDetector(
      onTap: () => _onLessonTap(lesson),
      child: Opacity(
        opacity: lesson.isLocked ? 0.6 : 1.0,
        child: Container(
          height: 140, // Resim ve metin için alanı biraz artırdık
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: themeColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: themeColor.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              // --- SOL RESİM ALANI ---
              Container(
                width: 110,
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(24)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(24)),
                  child: Center(
                    child: lesson.isLocked
                        ? const Icon(Icons.lock, color: Colors.grey, size: 40)
                        : (lesson.isCompleted
                            ? Stack(
                                // ✅ TAMAMLANANLARDA RESİM ÜZERİNDE YAZI
                                fit: StackFit.expand,
                                children: [
                                  if (lesson.coverImage != null)
                                    Image.asset(lesson.coverImage!,
                                        fit: BoxFit.cover),
                                  Container(
                                      color: Colors.black
                                          .withOpacity(0.4)), // Karartma
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.9),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text(
                                        "TAMAMLANDI",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : (lesson.coverImage != null
                                ? Image.asset(lesson.coverImage!,
                                    fit: BoxFit.contain)
                                : Icon(Icons.brush,
                                    color: themeColor, size: 40))),
                  ),
                ),
              ),

              // --- SAĞ BİLGİ ALANI ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(lesson.title,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color:
                                  lesson.isLocked ? Colors.grey : Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Text(
                          lesson.isLocked
                              ? "KİLİTLİ"
                              : (lesson.isCompleted
                                  ? "BAŞARIYLA BİTTİ"
                                  : "+100 XP KAZAN"),
                          style: TextStyle(
                              color: lesson.isCompleted
                                  ? Colors.green
                                  : themeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("${lesson.steps.length} Adım",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: (index) {
        if (index == 0)
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => CategoriesScreen(cameras: widget.cameras)));
        else if (index == 2)
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
        else if (index == 3)
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()));
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded), label: "Menü"),
        BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_rounded), label: "Öğren"),
        BottomNavigationBarItem(
            icon: Icon(Icons.workspace_premium_rounded), label: "PRO"),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded), label: "Profil"),
      ],
    );
  }
}
