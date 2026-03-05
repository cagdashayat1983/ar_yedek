// lib/screens/learn_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart'; // ✅ l10n eklendi
import 'tutorial_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';
import 'home_screen.dart';

// 1. ZORLUK SEVİYESİ
enum Difficulty { easy, medium, hard }

extension DifficultyExtension on Difficulty {
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

  @override
  void initState() {
    super.initState();
    final assetBundle = DefaultAssetBundle.of(context);
    _loadLessonsAndXp(assetBundle);
  }

  Future<void> _loadLessonsAndXp(AssetBundle bundle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userXp = prefs.getInt('total_xp') ?? 0;

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
          stepImages.add(coverImg);
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

  void _onLessonTap(LessonModel lesson, AppLocalizations l10n) async {
    final prefs = await SharedPreferences.getInstance();
    int? savedStep = prefs.getInt('progress_${lesson.title}');
    if (savedStep != null && savedStep > 0 && savedStep < lesson.steps.length) {
      _showResumeDialog(lesson, savedStep, l10n);
    } else {
      _startTutorial(lesson, 0);
    }
  }

  void _showResumeDialog(LessonModel lesson, int step, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.resumeDrawing), // ✅ Localized
        content: Text("${lesson.title} ${l10n.resumeDesc}"), // ✅ Localized
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startTutorial(lesson, 0);
              },
              child: Text(l10n.startOver)), // ✅ Localized
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTutorial(lesson, step);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: lesson.difficulty.color),
            child: Text(l10n.continueBtn,
                style: const TextStyle(color: Colors.white)), // ✅ Localized
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
    final l10n = AppLocalizations.of(context)!; // ✅ l10n tanımlandı

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.navLearn, // ✅ Localized (Öğren)
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
                _buildXpHeader(l10n), // ✅ l10n gönderildi
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _lessons.length,
                    itemBuilder: (context, index) => _buildLessonCard(
                        _lessons[index], l10n), // ✅ l10n gönderildi
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(l10n), // ✅ l10n gönderildi
    );
  }

  Widget _buildXpHeader(AppLocalizations l10n) {
    double progress = _userXp / _nextLevelThreshold;
    if (progress > 1.0) progress = 1.0;

    // ✅ Rütbe ismini dile göre hesapla
    String userRank =
        _userXp >= _nextLevelThreshold ? l10n.rankArtist : l10n.rankRookie;

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
                  Text(userRank.toUpperCase(), // ✅ Localized
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.blue)),
                  Text(
                      l10n.aboutUs, // Veya özel bir 'Art Journey' anahtarı eklenebilir
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
            Text(
                l10n.xpToTarget(_nextLevelThreshold -
                    _userXp), // ✅ Localized (Placeholder kullanır)
                style: const TextStyle(fontSize: 11, color: Colors.grey))
          else
            Text(l10n.congratsArtist, // ✅ Localized
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLessonCard(LessonModel lesson, AppLocalizations l10n) {
    Color themeColor = lesson.difficulty.color;

    return GestureDetector(
      onTap: () => _onLessonTap(lesson, l10n),
      child: Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
                                l10n.doneLabel, // ✅ Localized (YAPILDI)
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
                    Text(
                        lesson.isCompleted
                            ? l10n.drawAgain
                            : l10n.earnXp, // ✅ Localized
                        style: TextStyle(
                            color: lesson.isCompleted
                                ? Colors.blueAccent
                                : themeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(
                        l10n.stepsLabel(lesson.steps.length -
                            1), // ✅ Localized ({count} Adım...)
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

  Widget _buildBottomNav(AppLocalizations l10n) {
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
      selectedItemColor: const Color(0xFF6366F1), // Home Screen ile aynı mavi
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 11),
      items: [
        _buildColorNavItem(
            "assets/icons/menu.png", l10n.navHome, 0), // ✅ Localized
        _buildColorNavItem(
            "assets/icons/learn.png", l10n.navLearn, 1), // ✅ Localized
        _buildColorNavItem(
            "assets/icons/pro.png", l10n.navPro, 2), // ✅ Localized
        _buildColorNavItem(
            "assets/icons/profile.png", l10n.navProfile, 3), // ✅ Localized
      ],
    );
  }

  BottomNavigationBarItem _buildColorNavItem(
      String iconPath, String label, int index) {
    bool isSelected = _bottomIndex == index;
    return BottomNavigationBarItem(
      icon: Opacity(
        opacity: isSelected ? 1.0 : 0.5,
        child: Image.asset(iconPath,
            width: 24, height: 24), // Home Screen ile aynı boyut (24)
      ),
      label: label,
    );
  }
}
