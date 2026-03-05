// lib/screens/categories_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:math';
import 'dart:async';

import '../l10n/app_localizations.dart';
import '../services/subscription_service.dart';
import '../models/category_model.dart';
import 'templates_screen.dart';
import 'learn_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CategoriesScreen({super.key, required this.cameras});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final int _bottomIndex = 0;
  int _streakCount = 0;
  bool _isPro = false;
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

  final List<CategoryModel> _categories =
      categories.where((c) => c.templateFolder.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _checkSubscription();
    _checkStreak();
    _loadAllCategoryCounts();

    _colorTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _currentHeaderColor =
              _headerPalette[Random().nextInt(_headerPalette.length)];
        });
      }
    });
  }

  Future<void> _checkSubscription() async {
    bool status = await SubscriptionService.isProUser();
    if (mounted) {
      setState(() => _isPro = status);
    }
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
        counts[cat.titleKey] = allAssets
            .where((path) => path.startsWith("assets/templates/$folder/"))
            .length;
      }
      if (mounted) setState(() => _categoryCounts = counts);
    } catch (e) {
      debugPrint("Count error: $e");
    }
  }

  Future<void> _checkStreak() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _streakCount = prefs.getInt('streak_count') ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
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
                  _currentHeaderColor.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(l10n),
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
                      // ✅ Hata 143 Çözüldü: l10n.freeAtelier
                      child: Text(l10n.freeAtelier,
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B))),
                    ),
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
                                    _categories[index], l10n),
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
      bottomNavigationBar: _buildBottomNav(l10n),
    );
  }

  Widget _buildAestheticCategoryCard(CategoryModel cat, AppLocalizations l10n) {
    final count = _categoryCounts[cat.titleKey] ?? 0;
    bool showLock = cat.isPremium && !_isPro;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          if (showLock) {
            Navigator.push(
                context,
                // ✅ Hata 194 Çözüldü: const eklendi
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => TemplatesScreen(
                        category: cat, cameras: widget.cameras)));
          }
        },
        child: Container(
          height: 120,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
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
                      cat.color.withValues(alpha: 0.2),
                      cat.color.withValues(alpha: 0.6)
                    ]),
                    borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.all(10),
                child: Hero(
                    tag: "cat_${cat.titleKey}",
                    child: Image.asset(cat.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(cat.icon, color: Colors.white, size: 40))),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat.getLocalizedTitle(context),
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B))),
                        const SizedBox(height: 4),
                        Text(l10n.templatesCount(count),
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w500)),
                      ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Icon(
                    showLock
                        ? Icons.lock_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: showLock ? Colors.amber : Colors.black12,
                    size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(AppLocalizations l10n) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      // ✅ Hata 282 Çözüldü: l10n.freeAtelier
      title: Text(l10n.freeAtelier,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15)),
              child: Text("🔥 $_streakCount",
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            )),
          ),
      ],
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
        } else if (index == 1) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => LearnScreen(cameras: widget.cameras)));
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
      selectedItemColor: const Color(0xFF6366F1),
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 11),
      items: [
        _buildColorNavItem("assets/icons/menu.png", l10n.navHome, 0),
        _buildColorNavItem("assets/icons/learn.png", l10n.navLearn, 1),
        _buildColorNavItem("assets/icons/pro.png", l10n.navPro, 2),
        _buildColorNavItem("assets/icons/profile.png", l10n.navProfile, 3),
      ],
    );
  }

  BottomNavigationBarItem _buildColorNavItem(
      String iconPath, String label, int index) {
    bool isSelected = _bottomIndex == index;
    return BottomNavigationBarItem(
      icon: Opacity(
        opacity: isSelected ? 1.0 : 0.5,
        child: Image.asset(iconPath, width: 24, height: 24),
      ),
      label: label,
    );
  }
}
