// lib/screens/categories_screen.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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

  const CategoriesScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final int _bottomIndex = 0;

  bool _isPro = false;
  Map<String, int> _categoryCounts = {};
  String _selectedFilter = 'all';

  final List<CategoryModel> _categories =
      categories.where((c) => c.templateFolder.isNotEmpty).toList();

  final String workerUrl = "https://hayatify-api.cagdasyucedag.workers.dev";

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      _checkSubscription(),
      _loadAllCategoryCounts(),
    ]);
  }

  Future<void> _refreshScreen() async {
    HapticFeedback.lightImpact();
    await Future.wait([
      _checkSubscription(),
      _loadAllCategoryCounts(forceRefresh: true),
    ]);
  }

  Future<void> _checkSubscription() async {
    final status = await SubscriptionService.isProUser();
    if (!mounted) return;
    setState(() => _isPro = status);
  }

  Future<void> _loadAllCategoryCounts({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> counts = {};

    if (!forceRefresh) {
      final cachedCounts = prefs.getString('cache_category_counts');
      if (cachedCounts != null) {
        try {
          final decoded = json.decode(cachedCounts);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (key is String && value is num) {
                counts[key] = value.toInt();
              }
            });
          }

          if (mounted && counts.isNotEmpty) {
            setState(() => _categoryCounts = counts);
          }
        } catch (e) {
          debugPrint("Cache okuma hatası: $e");
        }
      }
    }

    try {
      await Future.wait(
        _categories.map((cat) async {
          final folder = cat.templateFolder.toLowerCase().trim();
          final uri = Uri.parse(workerUrl).replace(
            queryParameters: {'folder': folder},
          );

          final response = await http.get(uri).timeout(
                const Duration(seconds: 10),
              );

          if (response.statusCode == 200) {
            final decoded = json.decode(response.body);
            if (decoded is List) {
              counts[cat.titleKey] = decoded.length;
            }
          }
        }),
      );

      await prefs.setString('cache_category_counts', json.encode(counts));

      if (!mounted) return;
      setState(() {
        _categoryCounts = counts;
      });
    } catch (e) {
      debugPrint("Bulut sayım hatası: $e");
    }
  }

  bool _isTurkish(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'tr';
  }

  String _txt(BuildContext context, String tr, String en) {
    return _isTurkish(context) ? tr : en;
  }

  List<CategoryModel> get _filteredCategories {
    switch (_selectedFilter) {
      case 'free':
        return _categories.where((c) => !c.isPremium).toList();
      case 'pro':
        return _categories.where((c) => c.isPremium).toList();
      default:
        return _categories;
    }
  }

  // ✅ YENİ: Bütün kategoriler şartsız şurtsuz içeri alır!
  // (Satışlar artık şablonların içinde yapılacak)
  void _openCategory(CategoryModel cat) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatesScreen(
          category: cat,
          cameras: widget.cameras,
        ),
      ),
    );
  }

  String _categorySubtitle(CategoryModel cat, BuildContext context) {
    final key = cat.titleKey.toLowerCase();

    if (key.contains('animal')) {
      return _txt(
        context,
        'Sevimli ve kolay çizim koleksiyonları',
        'Cute and easy drawing collections',
      );
    }
    if (key.contains('anime')) {
      return _txt(
        context,
        'Popüler anime tarzı çizim setleri',
        'Popular anime-style drawing sets',
      );
    }
    if (key.contains('flower') || key.contains('floral')) {
      return _txt(
        context,
        'Zarif ve estetik çiçek çizimleri',
        'Elegant and aesthetic flower drawings',
      );
    }
    if (key.contains('kid') || key.contains('children')) {
      return _txt(
        context,
        'Çocuklar için eğlenceli rehberler',
        'Fun guides for kids',
      );
    }
    if (key.contains('christmas') || key.contains('holiday')) {
      return _txt(
        context,
        'Tematik ve sezonluk çizimler',
        'Seasonal and themed drawings',
      );
    }
    if (cat.isPremium) {
      return _txt(
        context,
        'Özel ve gelişmiş içerikler',
        'Exclusive and advanced content',
      );
    }

    return _txt(
      context,
      'Yaratıcı çizim şablonlarını keşfet',
      'Explore creative drawing templates',
    );
  }

  String _categoryBadge(CategoryModel cat, BuildContext context) {
    final key = cat.titleKey.toLowerCase();

    // Premium olmasını umursamıyoruz, badge rengi değişecek ama hepsi açılacak.
    if (cat.isPremium) return 'PRO';
    if (key.contains('animal') || key.contains('anime')) {
      return _txt(context, 'Popüler', 'Popular');
    }
    if (key.contains('kid') || key.contains('beginner')) {
      return _txt(context, 'Kolay', 'Easy');
    }
    if (key.contains('flower') || key.contains('floral')) {
      return _txt(context, 'Estetik', 'Aesthetic');
    }

    return _txt(context, 'Keşfet', 'Explore');
  }

  Color _badgeColor(CategoryModel cat) {
    if (cat.isPremium) return const Color(0xFFFFB703);
    return cat.color;
  }

  String _headerSubtitle(BuildContext context) {
    return _txt(
      context,
      'Kategorini seç, AR çizim yolculuğunu hemen başlat.',
      'Choose a category and start your AR drawing journey.',
    );
  }

  String _collectionsTitle(BuildContext context) {
    return _txt(context, 'Koleksiyonlar', 'Collections');
  }

  String _collectionsSubtitle(BuildContext context) {
    return _txt(
      context,
      'Sana en uygun çizim stilini seç.',
      'Pick the drawing style that fits you best.',
    );
  }

  String _ctaTitle(BuildContext context) {
    return _txt(
      context,
      'Tüm premium şablonların kilidini aç',
      'Unlock all premium templates',
    );
  }

  String _ctaSubtitle(BuildContext context) {
    return _txt(
      context,
      'Daha fazla şablon ve gelişmiş içeriklere eriş.',
      'Access more templates and advanced content.',
    );
  }

  String _filterLabel(BuildContext context, String key) {
    switch (key) {
      case 'free':
        return _txt(context, 'Ücretsiz', 'Free');
      case 'pro':
        return 'Pro';
      default:
        return _txt(context, 'Tümü', 'All');
    }
  }

  Widget _buildCountWidget(CategoryModel cat, AppLocalizations l10n) {
    final count = _categoryCounts[cat.titleKey];

    if (count != null) {
      return Text(
        l10n.templatesCount(count),
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      width: 84,
      height: 11,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF5),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildTopGradientBackground() {
    return Container(
      height: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5B5FEF),
            Color(0xFF7A5AF8),
            Color(0xFF8B5CF6),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 90,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 25,
            right: 35,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.freeAtelier,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 30,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _headerSubtitle(context),
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.90),
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContentHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          _buildFilterChips(),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _collectionsTitle(context),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _collectionsSubtitle(context),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ['all', 'free', 'pro'];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final key = filters[index];
          final isSelected = _selectedFilter == key;

          return Material(
            color: isSelected ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = key);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF111827)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    if (key == 'pro')
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFFFB703),
                        ),
                      ),
                    Text(
                      _filterLabel(context, key),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAestheticCategoryCard(CategoryModel cat, AppLocalizations l10n) {
    // ✅ YENİ: Kilit ikonu tamamen kaldırıldı, çünkü her yere girilebiliyor.
    final badgeColor = _badgeColor(cat);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _openCategory(cat),
          child: Container(
            height: 154,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFEAEFF6)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cat.color.withOpacity(0.18),
                        cat.color.withOpacity(0.46),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Hero(
                    tag: "cat_${cat.titleKey}",
                    child: Image.asset(
                      cat.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          cat.icon,
                          color: Colors.white,
                          size: 42,
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                cat.getLocalizedTitle(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _categoryBadge(cat, context),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _categorySubtitle(cat, context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            height: 1.30,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: _buildCountWidget(cat, l10n),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFFCBD5E1),
                              size: 18,
                            ),
                          ],
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
    );
  }

  Widget _buildPremiumCtaCard(AppLocalizations l10n) {
    if (_isPro) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF111827),
              Color(0xFF1F2937),
              Color(0xFF312E81),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF111827).withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 360;

            if (isTight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFFFD166),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _ctaTitle(context),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _ctaSubtitle(context),
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.82),
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SubscriptionScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Text(
                            l10n.navPro,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF111827),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD166),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ctaTitle(context),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _ctaSubtitle(context),
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.82),
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        l10n.navPro,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEAEFF6)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 34,
              color: Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 12),
            Text(
              _txt(
                context,
                'Bu filtrede henüz kategori yok',
                'No categories in this filter yet',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
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
              builder: (_) => HomeScreen(cameras: widget.cameras),
            ),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LearnScreen(cameras: widget.cameras),
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SubscriptionScreen(),
            ),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            ),
          );
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 12,
      selectedItemColor: const Color(0xFF6366F1),
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
      unselectedLabelStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
      items: [
        _buildColorNavItem("assets/icons/menu.png", l10n.navHome, 0),
        _buildColorNavItem("assets/icons/learn.png", l10n.navLearn, 1),
        _buildColorNavItem("assets/icons/pro.png", l10n.navPro, 2),
        _buildColorNavItem("assets/icons/profile.png", l10n.navProfile, 3),
      ],
    );
  }

  BottomNavigationBarItem _buildColorNavItem(
    String iconPath,
    String label,
    int index,
  ) {
    final isSelected = _bottomIndex == index;

    return BottomNavigationBarItem(
      icon: Opacity(
        opacity: isSelected ? 1.0 : 0.5,
        child: Image.asset(
          iconPath,
          width: 24,
          height: 24,
        ),
      ),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filteredCategories = _filteredCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Stack(
        children: [
          _buildTopGradientBackground(),
          SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFF6366F1),
              onRefresh: _refreshScreen,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(l10n),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                  SliverToBoxAdapter(
                    child: _buildMainContentHeader(),
                  ),
                  if (filteredCategories.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyFilterState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                      sliver: AnimationLimiter(
                        child: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final cat = filteredCategories[index];
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 450),
                                child: SlideAnimation(
                                  verticalOffset: 24,
                                  child: FadeInAnimation(
                                    child:
                                        _buildAestheticCategoryCard(cat, l10n),
                                  ),
                                ),
                              );
                            },
                            childCount: filteredCategories.length,
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _buildPremiumCtaCard(l10n),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(l10n),
    );
  }
}
