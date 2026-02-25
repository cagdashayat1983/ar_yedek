// lib/screens/categories_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:math';
import 'dart:async';

import '../models/category_model.dart';
import 'templates_screen.dart';
import 'learn_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CategoriesScreen({super.key, required this.cameras});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final int _bottomIndex = 0;
  int _streakCount = 0;
  Map<String, int> _categoryCounts = {};
  Timer? _colorTimer;

  Color _currentHeaderColor = const Color(0xFF4ECDC4);

  final List<Color> _headerPalette = [
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4),
    const Color(0xFFFFBE0B),
    const Color(0xFFFF006E),
    const Color(0xFF8338EC),
    const Color(0xFF3A86FF),
    const Color(0xFFFB5607),
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

    // Arka plan rengini yavaşça değiştiren animasyon
    _colorTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _currentHeaderColor =
              _headerPalette[Random().nextInt(_headerPalette.length)];
        });
      }
    });
  }

  @override
  void dispose() {
    _colorTimer?.cancel();
    super.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // Dinamik Renkli Arka Plan
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            height: MediaQuery.of(context).size.height * 0.35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _currentHeaderColor,
                  _currentHeaderColor.withOpacity(0.5),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),

                // Kategoriler Başlığı
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(25, 25, 25, 15),
                      child: Text("Şablon Koleksiyonları",
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B))),
                    ),
                  ),
                ),

                // Kategori Listesi
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
      bottomNavigationBar: _buildNormalBottomBar(),
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
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5))
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
                    borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.all(10),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B))),
                        const SizedBox(height: 4),
                        Text("$count şablon",
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w500)),
                      ]),
                ),
              ),
              const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.black12, size: 16)),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text("Şablonlar",
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
      centerTitle: true,
      actions: [
        if (_streakCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15)),
              child: Text("🔥 $_streakCount",
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            )),
          ),
      ],
    );
  }

  Widget _buildNormalBottomBar() {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: (i) {
        if (i == 1) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => LearnScreen(cameras: widget.cameras)));
        }
        if (i == 2) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
        }
        if (i == 3) {
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
        _buildColorNavItem("assets/icons/menu.png", "Şablonlar", 0),
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
