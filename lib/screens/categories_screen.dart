// lib/screens/categories_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:ui';
import 'dart:io'; // Platform kontrolü için
import 'dart:math';
import 'dart:async';

import '../models/category_model.dart';
import 'templates_screen.dart';
import 'drawing_screen.dart';
import 'learn_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';

// ✅ PRO AR MODU İÇİN İMPORT EKLENDİ
import 'ios_ar_sayfasi.dart';

class CategoriesScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CategoriesScreen({super.key, required this.cameras});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _bottomIndex = 0;
  int _streakCount = 0;
  Map<String, int> _categoryCounts = {};
  Timer? _inspirationTimer;

  String? _randomTemplatePath;
  CategoryModel? _randomTemplateCategory;
  Color _currentHeaderColor = const Color(0xFF4ECDC4);

  final List<Color> _inspirationPalette = [
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4),
    const Color(0xFFFFBE0B),
    const Color(0xFFFF006E),
    const Color(0xFF8338EC),
    const Color(0xFF3A86FF),
    const Color(0xFFFB5607),
    const Color(0xFF00F5D4),
    const Color(0xFF9B5DE5),
  ];

  final List<CategoryModel> _categories = [
    CategoryModel(
        title: "Hayvanlar",
        color: const Color(0xFFFF6B6B),
        templateFolder: "animals",
        imagePath: "assets/categories/animals.png"),
    CategoryModel(
        title: "Arabalar",
        color: const Color(0xFF4ECDC4),
        templateFolder: "cars",
        imagePath: "assets/categories/cars.png"),
    CategoryModel(
        title: "Anime",
        color: const Color(0xFFFFBE0B),
        templateFolder: "anime",
        imagePath: "assets/categories/anime.png"),
    CategoryModel(
        title: "Çizgi Film",
        color: const Color(0xFFFF006E),
        templateFolder: "cartoon",
        imagePath: "assets/categories/cartoon.png"),
    CategoryModel(
        title: "Çiçekler",
        color: const Color(0xFF8338EC),
        templateFolder: "flowers",
        imagePath: "assets/categories/flowers.png"),
    CategoryModel(
        title: "İnsanlar",
        color: const Color(0xFF3A86FF),
        templateFolder: "human",
        imagePath: "assets/categories/human.png"),
    CategoryModel(
        title: "Doğa",
        color: const Color(0xFFFB5607),
        templateFolder: "nature",
        imagePath: "assets/categories/nature.png"),
  ];

  @override
  void initState() {
    super.initState();
    _checkStreak();
    _loadAllCategoryCounts();
    _findRandomInspiration();
    _inspirationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _findRandomInspiration();
    });
  }

  @override
  void dispose() {
    _inspirationTimer?.cancel();
    super.dispose();
  }

  Future<void> _findRandomInspiration() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      final allTemplates = allAssets
          .where((path) =>
              path.startsWith("assets/templates/") &&
              (path.endsWith(".png") || path.endsWith(".jpg")))
          .toList();

      if (allTemplates.isNotEmpty) {
        final random = Random();
        final randomPath = allTemplates[random.nextInt(allTemplates.length)];
        CategoryModel? foundCat;
        for (var cat in _categories) {
          if (randomPath.contains("/${cat.templateFolder}/")) {
            foundCat = cat;
            break;
          }
        }
        if (mounted) {
          setState(() {
            _randomTemplatePath = randomPath;
            _randomTemplateCategory =
                foundCat ?? _categories[random.nextInt(_categories.length)];
            _currentHeaderColor =
                _inspirationPalette[random.nextInt(_inspirationPalette.length)];
          });
        }
      }
    } catch (e) {
      debugPrint("İlham hatası: $e");
    }
  }

  // ✅ AKILLI KÖPRÜ: GALERİDEN SEÇİM İŞLEMİ
  Future<void> _pickFromGallery() async {
    HapticFeedback.heavyImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      if (Platform.isIOS) {
        // iPhone ise PRO AR'a git
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => IosArSayfasi(imagePath: image.path)));
      } else {
        // Android ise Çizim Ekranına git
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DrawingScreen(
                    category: CategoryModel(
                        title: "Galerim",
                        color: Colors.purple,
                        templateFolder: "",
                        imagePath: ""),
                    cameras: widget.cameras,
                    imagePath: image.path)));
      }
    }
  }

  Future<void> _loadAllCategoryCounts() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      Map<String, int> counts = {};
      for (var cat in _categories) {
        final folder = cat.templateFolder.toLowerCase();
        counts[cat.title] = allAssets
            .where((path) => path.startsWith("assets/templates/$folder/"))
            .length;
      }
      if (mounted) setState(() => _categoryCounts = counts);
    } catch (e) {
      debugPrint("Sayım hatası: $e");
    }
  }

  Future<void> _checkStreak() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _streakCount = prefs.getInt('streak_count') ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final imageToShow = _randomTemplatePath ?? "assets/categories/anime.png";
    final categoryToShow = _randomTemplateCategory ?? _categories[2];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: () async {
          await _findRandomInspiration();
          await _loadAllCategoryCounts();
        },
        child: Stack(
          children: [
            _buildInspirationHeader(imageToShow, _currentHeaderColor),
            SafeArea(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(25, 10, 25, 30),
                      child: _buildHeaderContent(
                          categoryToShow, _currentHeaderColor),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 10),
                      child: Text("Koleksiyonlar",
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B))),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: AnimationLimiter(
                      child: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 500),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: _buildAestheticCategoryCard(
                                      _categories[index]),
                                ),
                              ),
                            );
                          },
                          childCount: _categories.length,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildAnimatedFAB(),
      bottomNavigationBar: _buildNormalBottomBar(),
    );
  }

  Widget _buildInspirationHeader(String imagePath, Color headerColor) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.38,
      child: AnimatedSwitcher(
        duration: const Duration(seconds: 1),
        child: Stack(
          key: ValueKey(imagePath),
          fit: StackFit.expand,
          children: [
            Image.asset(imagePath, fit: BoxFit.cover),
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    headerColor.withOpacity(0.01),
                    headerColor.withOpacity(0.18)
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xFFF5F7FA)]))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent(CategoryModel cat, Color headerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text("GÜNÜN İLHAMI",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        Text("Bugün Ne Çiziyoruz?",
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                shadows: [const Shadow(blurRadius: 8, color: Colors.black45)])),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            if (_randomTemplatePath != null) {
              // ✅ AKILLI KÖPRÜ EKLENEBİLİR: iOS İSE AR'A, DEĞİLSE NORMAL'E GİT.
              if (Platform.isIOS) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        IosArSayfasi(imagePath: _randomTemplatePath!),
                  ),
                );
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DrawingScreen(
                            category: cat,
                            cameras: widget.cameras,
                            imagePath: _randomTemplatePath!)));
              }
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: headerColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: Text("Hemen Başla",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildAestheticCategoryCard(CategoryModel cat) {
    final count = _categoryCounts[cat.title] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      TemplatesScreen(category: cat, cameras: widget.cameras)));
        },
        child: Container(
          height: 120,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
              ]),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      cat.color.withOpacity(0.2),
                      cat.color.withOpacity(0.6)
                    ]),
                    borderRadius: BorderRadius.circular(35)),
                padding: const EdgeInsets.all(8),
                child: Hero(
                    tag: "cat_${cat.title}",
                    child: Image.asset(cat.imagePath, fit: BoxFit.contain)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat.title,
                            style: GoogleFonts.poppins(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        Text("$count şablon",
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.blueGrey)),
                      ]),
                ),
              ),
              const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.black12, size: 14)),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text("Hayatify",
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
      actions: [
        if (_streakCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
                child: Text("🔥 $_streakCount",
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w800))),
          ),
      ],
    );
  }

  Widget _buildAnimatedFAB() {
    return FloatingActionButton.extended(
      onPressed: _pickFromGallery,
      backgroundColor: const Color(0xFF1E293B),
      icon: const Icon(Icons.add_photo_alternate_rounded,
          color: Colors.white, size: 20),
      label: Text("Galeriden Çiz",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
    );
  }

  Widget _buildNormalBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _bottomIndex,
          onTap: (i) {
            if (i == 1)
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LearnScreen(cameras: widget.cameras)));
            if (i == 2)
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen()));
            if (i == 3)
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()));
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedItemColor: const Color(0xFF1E293B),
          unselectedItemColor: Colors.blueGrey.shade300,
          selectedLabelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 10),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 10),
          items: [
            _buildColorNavItem("assets/icons/menu.png", "Sanat", 0),
            _buildColorNavItem("assets/icons/learn.png", "Öğren", 1),
            _buildColorNavItem("assets/icons/pro.png", "PRO", 2),
            _buildColorNavItem("assets/icons/profile.png", "Profil", 3),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildColorNavItem(String path, String label, int i) {
    bool isSelected = _bottomIndex == i;
    return BottomNavigationBarItem(
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isSelected ? 0 : 4),
          child: Image.asset(
            path,
            width: 22,
            height: 22,
            color: isSelected ? null : Colors.blueGrey.shade200,
            opacity: AlwaysStoppedAnimation(isSelected ? 1.0 : 0.6),
          ),
        ),
        label: label);
  }
}
