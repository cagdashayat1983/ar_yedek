// lib/screens/learn_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tutorial_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';
import 'home_screen.dart';

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
    this.isLocked = false,
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

  final int _bottomIndex = 1;

  int _userXp = 0;
  final int _nextLevelThreshold = 2000;
  String _userRank = "Çaylak";

  @override
  void initState() {
    super.initState();
    // Asenkron işlemlerden önce context'i sabitleyip uyarıları önlüyoruz
    final assetBundle = DefaultAssetBundle.of(context);
    _loadLessonsAndXp(assetBundle);
  }

  Future<void> _loadLessonsAndXp(AssetBundle bundle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userXp = prefs.getInt('total_xp') ?? 0;
      _userRank = _userXp >= _nextLevelThreshold ? "Çizimci" : "Çaylak";

      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
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
            if (fileName.contains('easy')) {
              diff = Difficulty.easy;
            } else if (fileName.contains('hard')) {
              diff = Difficulty.hard;
            }
          } else {
            stepImages.add(file);
          }
        }

        stepImages.sort((a, b) => a.compareTo(b));

        if (coverImg != null) {
          stepImages.add(coverImg); // Gereksiz ! işareti uyarısı kalktı
        }

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
        loadedLessons[i].isLocked = false;
      }

      if (mounted) {
        setState(() {
          _lessons = loadedLessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onLessonTap(LessonModel lesson) async {
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

    if (mounted) {
      final assetBundle = DefaultAssetBundle.of(context);
      _loadLessonsAndXp(assetBundle);
    }
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

  Widget _buildLessonCard(LessonModel lesson) {
    Color themeColor = lesson.difficulty.color;

    return GestureDetector(
      onTap: () => _onLessonTap(lesson),
      child: Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          // Güncel withValues kullanımı ile uyarılar temizlendi
          border: Border.all(color: themeColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: themeColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 110,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(24)),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(24)),
                child: Center(
                    child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (lesson.coverImage != null)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(lesson.coverImage!,
                            fit: BoxFit.contain),
                      )
                    else
                      Icon(Icons.brush, color: themeColor, size: 40),
                    if (lesson.isCompleted)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2))
                              ]),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white, size: 10),
                              const SizedBox(width: 4),
                              Text(
                                "YAPILDI",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )),
              ),
            ),
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
                            color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text(lesson.isCompleted ? "TEKRAR ÇİZ" : "+100 XP KAZAN",
                        style: TextStyle(
                            color: lesson.isCompleted
                                ? Colors.blueAccent
                                : themeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("${lesson.steps.length - 1} Adım + Boyama",
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
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => HomeScreen(cameras: widget.cameras)));
        } else if (index == 2) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
        } else if (index == 3) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 10,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 11),
      items: [
        _buildColorNavItem("assets/icons/menu.png", "Ana Ekran", 0),
        _buildColorNavItem("assets/icons/learn.png", "Öğren", 1),
        _buildColorNavItem("assets/icons/pro.png", "PRO", 2),
        _buildColorNavItem("assets/icons/profile.png", "Hesabım", 3),
      ],
    );
  }

  BottomNavigationBarItem _buildColorNavItem(
      String iconPath, String label, int index) {
    bool isSelected = _bottomIndex == index;
    return BottomNavigationBarItem(
      icon: Opacity(
        opacity: isSelected ? 1.0 : 0.5,
        child: Image.asset(iconPath, width: 28, height: 28),
      ),
      label: label,
    );
  }
}
