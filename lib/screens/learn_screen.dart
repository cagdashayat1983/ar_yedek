// lib/screens/learn_screen.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/energy_service.dart';
import '../services/ad_service.dart';
import '../services/subscription_service.dart';

import 'tutorial_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';
import 'home_screen.dart';

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

class LessonModel {
  final String title;
  final String? coverImage;
  final List<String> steps;
  final Difficulty difficulty;
  bool isLocked;
  bool isCompleted;
  bool isPremium;
  int currentStep;

  LessonModel({
    required this.title,
    this.coverImage,
    required this.steps,
    required this.difficulty,
    this.isLocked = false,
    this.isCompleted = false,
    this.isPremium = false,
    this.currentStep = 0,
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
  String? _errorMessage;
  Difficulty? _selectedDifficulty;
  final int _bottomIndex = 1;

  int _userXp = 0;
  final int _nextLevelThreshold = 2000;
  String _userRank = "Çaylak";

  bool _isProUser = false;
  int _currentEnergy = 0;

  final String _workerBase = "https://hayatify-api.cagdasyucedag.workers.dev";

  @override
  void initState() {
    super.initState();
    _loadLessonsAndXp();
  }

  Future<void> _loadLessonsAndXp({bool isRefresh = false}) async {
    if (!isRefresh && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      _userXp = prefs.getInt('total_xp') ?? 0;
      _userRank = _userXp >= _nextLevelThreshold ? "Çizimci" : "Çaylak";

      _isProUser = await SubscriptionService.isProUser();
      _currentEnergy = await EnergyService.getEnergy();

      final uri = Uri.parse("$_workerBase/").replace(
        queryParameters: {'folder': 'tutorial'},
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception("Lesson list error: ${response.statusCode}");
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) {
        throw Exception("Lesson list is not a valid array");
      }

      final List<String> tutorialFiles = decoded
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      Map<String, List<String>> groups = {};

      for (var file in tutorialFiles) {
        final fileName = file.split('/').last;
        if (fileName.contains('_')) {
          List<String> parts = fileName.split('_');
          String lessonPrefix = parts[0];

          if (lessonPrefix.toLowerCase() == 'pro' && parts.length > 1) {
            lessonPrefix = 'pro_${parts[1]}';
          }

          groups.putIfAbsent(lessonPrefix, () => []);
          groups[lessonPrefix]!.add(fileName);
        }
      }

      List<LessonModel> loadedLessons = [];

      groups.forEach((lessonPrefix, files) {
        String? coverImg;
        List<String> stepImages = [];
        Difficulty diff = Difficulty.medium;

        bool isPremiumLesson = lessonPrefix.toLowerCase().startsWith('pro_');

        for (var file in files) {
          final lowerFileName = file.toLowerCase();
          final imageUrl = Uri.parse("$_workerBase/image").replace(
            queryParameters: {
              'folder': 'tutorial',
              'file': file,
            },
          ).toString();

          if (lowerFileName.contains('cover')) {
            coverImg = imageUrl;
            if (lowerFileName.contains('easy')) {
              diff = Difficulty.easy;
            } else if (lowerFileName.contains('hard')) {
              diff = Difficulty.hard;
            } else {
              diff = Difficulty.medium;
            }
          } else {
            stepImages.add(imageUrl);
          }
        }

        stepImages.sort((a, b) {
          final fileA = Uri.parse(a).queryParameters['file'] ?? a;
          final fileB = Uri.parse(b).queryParameters['file'] ?? b;

          final reg = RegExp(r'_(\d+)');
          final matchA = reg.firstMatch(fileA);
          final matchB = reg.firstMatch(fileB);

          final numA = matchA != null ? int.tryParse(matchA.group(1)!) ?? 0 : 0;
          final numB = matchB != null ? int.tryParse(matchB.group(1)!) ?? 0 : 0;

          return numA.compareTo(numB);
        });

        if (coverImg != null) {
          stepImages.add(coverImg);
        }

        String rawTitle =
            isPremiumLesson ? lessonPrefix.substring(4) : lessonPrefix;
        final displayTitle = rawTitle[0].toUpperCase() + rawTitle.substring(1);

        if (stepImages.isNotEmpty || coverImg != null) {
          loadedLessons.add(
            LessonModel(
              title: displayTitle,
              coverImage: coverImg,
              steps: stepImages,
              difficulty: diff,
              isPremium: isPremiumLesson,
            ),
          );
        }
      });

      // ✅ YENİ: Ücretsiz olanlar daima en başta listelenir!
      loadedLessons.sort((a, b) {
        if (a.isPremium != b.isPremium) {
          return a.isPremium ? 1 : -1;
        }
        return a.title.compareTo(b.title);
      });

      for (int i = 0; i < loadedLessons.length; i++) {
        final lesson = loadedLessons[i];
        final isDone = prefs.getBool('completed_${lesson.title}') ?? false;
        final savedStep = prefs.getInt('progress_${lesson.title}') ?? 0;

        lesson.isCompleted = isDone;
        lesson.isLocked = false;

        if (lesson.steps.isEmpty) {
          lesson.currentStep = 0;
        } else if (isDone) {
          lesson.currentStep = lesson.steps.length;
        } else {
          lesson.currentStep = savedStep.clamp(0, lesson.steps.length);
        }
      }

      if (mounted) {
        setState(() {
          _lessons = loadedLessons;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint("LESSON LOAD ERROR: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Dersler yüklenemedi. Lütfen tekrar dene.";
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadLessonsAndXp(isRefresh: true);
  }

  List<LessonModel> get _filteredLessons {
    if (_selectedDifficulty == null) return _lessons;
    return _lessons
        .where((lesson) => lesson.difficulty == _selectedDifficulty)
        .toList();
  }

  // ✅ YENİ: Ücretsiz dersler enerji harcamaz.
  void _onLessonTap(LessonModel lesson) async {
    if (_isProUser) {
      _checkLessonProgressAndStart(lesson);
      return;
    }

    if (!lesson.isPremium) {
      _checkLessonProgressAndStart(lesson);
      return;
    }

    if (lesson.isCompleted || lesson.currentStep > 0) {
      _checkLessonProgressAndStart(lesson);
      return;
    }

    _showPremiumUpsellSheet(lesson);
  }

  void _checkLessonProgressAndStart(LessonModel lesson) async {
    final prefs = await SharedPreferences.getInstance();
    int? savedStep = prefs.getInt('progress_${lesson.title}');

    if (savedStep != null && savedStep > 0 && savedStep < lesson.steps.length) {
      _showResumeDialog(lesson, savedStep);
    } else {
      _startTutorial(lesson, 0);
    }
  }

  void _showPremiumUpsellSheet(LessonModel lesson) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.grey, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (lesson.coverImage != null)
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: lesson.difficulty.color.withValues(alpha: 0.10),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.network(lesson.coverImage!),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Bu ders Pro’ya özel',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium dersleri açmak için Pro\'ya geçebilir veya 1 Enerji harcayabilirsin.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (_currentEnergy > 0) {
                        await EnergyService.consumeEnergy();
                        setState(() => _currentEnergy -= 1);
                        _checkLessonProgressAndStart(lesson);
                      } else {
                        _showEnergyEmptyDialog(lesson);
                      }
                    },
                    icon: Icon(_currentEnergy > 0
                        ? Icons.bolt_rounded
                        : Icons.play_circle_filled_rounded),
                    label: Text(
                      _currentEnergy > 0
                          ? '⚡ 1 Enerji Harca ve Başla'
                          : '📺 Video İzle ve Aç',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SubscriptionScreen()))
                          .then((_) => _loadLessonsAndXp(isRefresh: true));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '💎 Pro\'ya Geç (Sınırsız)',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEnergyEmptyDialog(LessonModel lesson) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Color(0xFFD97706), size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enerjin Bitti!',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yeni derse başlamak için kısa bir video izle ve 3 Enerji kazan.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _playRewardedAdAndContinue(lesson);
                      },
                      icon: const Icon(Icons.play_circle_filled_rounded),
                      label: Text(
                        'Video İzle (+3 ⚡)',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SubscriptionScreen()))
                          .then((_) => _loadLessonsAndXp(isRefresh: true));
                    },
                    child: Text(
                      'Reklamları Kaldır (Pro)',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF6366F1),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playRewardedAdAndContinue(LessonModel lesson) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    AdService.showRewardedAd(
      onReward: () async {
        Navigator.pop(context);
        await EnergyService.rewardEnergy(3);
        setState(() => _currentEnergy = 3);

        await EnergyService.consumeEnergy();
        setState(() => _currentEnergy -= 1);
        _checkLessonProgressAndStart(lesson);
      },
      onFailed: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reklam şu an hazır değil, lütfen biraz bekle.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      },
    );
  }

  void _showResumeDialog(LessonModel lesson, int step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Devam Et?"),
        content: Text(
          "${lesson.title} dersine kaldığın yerden devam etmek ister misin?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startTutorial(lesson, 0);
            },
            child: const Text("Baştan"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTutorial(lesson, step);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: lesson.difficulty.color,
            ),
            child: const Text(
              "Devam Et",
              style: TextStyle(color: Colors.white),
            ),
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
          initialStep: startStep,
        ),
      ),
    );

    if (mounted) {
      _loadLessonsAndXp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLessons = _filteredLessons;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Gelişimim",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isProUser)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 4),
                    Text('$_currentEnergy',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD97706),
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Text(
                "$_userXp XP",
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildXpHeader(),
                const Divider(height: 1),
                _buildDifficultyFilters(),
                Expanded(
                  child: _buildBodyContent(filteredLessons),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBodyContent(List<LessonModel> filteredLessons) {
    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _loadLessonsAndXp(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  "Tekrar Dene",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_lessons.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                "Henüz ders bulunamadı.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (filteredLessons.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.10),
            Icon(
              Icons.filter_alt_off_rounded,
              size: 62,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                "Bu zorluk seviyesinde ders bulunamadı.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDifficulty = null;
                  });
                },
                child: Text(
                  "Filtreyi Temizle",
                  style: GoogleFonts.poppins(
                    color: Colors.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: filteredLessons.length,
        itemBuilder: (context, index) =>
            _buildLessonCard(filteredLessons[index]),
      ),
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
                  Text(
                    _userRank.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.blue,
                    ),
                  ),
                  const Text(
                    "Sanat Yolculuğu",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              Text(
                "%${(progress * 100).toInt()}",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 8),
          if (_userXp < _nextLevelThreshold)
            Text(
              "${_nextLevelThreshold - _userXp} XP sonra Çizimci olacaksın!",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            )
          else
            const Text(
              "Tebrikler, artık bir Çizimci'sin! 🎨",
              style: TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDifficultyFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(label: "Tümü", difficulty: null),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: Difficulty.easy.label,
              difficulty: Difficulty.easy,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: Difficulty.medium.label,
              difficulty: Difficulty.medium,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: Difficulty.hard.label,
              difficulty: Difficulty.hard,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Difficulty? difficulty,
  }) {
    final bool isSelected = _selectedDifficulty == difficulty;
    final Color chipColor = difficulty?.color ?? Colors.blue;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : chipColor,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedDifficulty = difficulty;
        });
      },
      selectedColor: chipColor,
      backgroundColor: chipColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: chipColor.withValues(alpha: 0.25),
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _buildLessonCard(LessonModel lesson) {
    final Color themeColor = lesson.difficulty.color;
    final bool locked = lesson.isPremium && !_isProUser;

    final int totalSteps = lesson.steps.length;
    final int currentStep = lesson.currentStep.clamp(0, totalSteps);
    final double progress =
        totalSteps == 0 ? 0 : (currentStep / totalSteps).clamp(0.0, 1.0);

    String progressText;
    if (lesson.isCompleted) {
      progressText = "Tamamlandı";
    } else if (currentStep > 0) {
      progressText = "$currentStep / $totalSteps tamamlandı";
    } else {
      progressText = "Henüz başlanmadı";
    }

    return GestureDetector(
      onTap: () => _onLessonTap(lesson),
      child: Container(
        height: 158,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: locked
                  ? const Color(0xFFFFE7B0)
                  : themeColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
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
                          child: Image.network(
                            lesson.coverImage!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: themeColor,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.brush,
                                color: themeColor,
                                size: 40,
                              );
                            },
                          ),
                        )
                      else
                        Icon(Icons.brush, color: themeColor, size: 40),
                      if (locked)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFFFE7B0)),
                            ),
                            child: Text(
                              "PRO",
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFFD97706),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        )
                      else if (lesson.isCompleted)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lesson.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lesson.isCompleted
                          ? "TEKRAR ÇİZ"
                          : (locked ? "PRO İLE AÇ" : "+100 XP KAZAN"),
                      style: TextStyle(
                        color: lesson.isCompleted
                            ? Colors.blueAccent
                            : (locked ? const Color(0xFFD97706) : themeColor),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "${lesson.steps.length - 1} Adım + Boyama",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progressText,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: lesson.isCompleted
                            ? Colors.green
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(locked ? Icons.lock_rounded : Icons.chevron_right,
                color: locked ? const Color(0xFFD97706) : Colors.grey),
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
              builder: (_) => HomeScreen(cameras: widget.cameras),
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          ).then((_) => _loadLessonsAndXp(isRefresh: true));
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
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
    String iconPath,
    String label,
    int index,
  ) {
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
