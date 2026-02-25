// lib/screens/templates_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Haptic
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; // Galeri
import 'dart:io'; // Platform kontrolü için gerekli

import '../models/category_model.dart';
import 'drawing_screen.dart'; // Galeriden seçilenler için
import 'profile_screen.dart';
import 'subscription_screen.dart';
import 'learn_screen.dart';

import 'ios_ar_sayfasi.dart';
import 'ar_mini_test_screen.dart';

class DesignItem {
  final String path;
  final String difficulty;
  int likes;
  bool isLiked;
  bool isSaved;
  bool isPremium;

  DesignItem({
    required this.path,
    required this.difficulty,
    this.likes = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isPremium = false,
  });
}

class TemplatesScreen extends StatefulWidget {
  final CategoryModel category;
  final List<CameraDescription> cameras;

  const TemplatesScreen(
      {super.key, required this.category, required this.cameras});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen>
    with SingleTickerProviderStateMixin {
  late SharedPreferences _prefs;
  final ScrollController _scroll = ScrollController();

  bool _isProUser = false;
  bool _loading = true;
  int _bottomIndex = 0;

  String _selectedTab = "Hepsi";
  final List<String> _tabs = ["Hepsi", "Kolay", "Orta", "Zor"];

  // ✅ ARAMA YERİNE FİLTRELEME (SIRALAMA) SİSTEMİ EKLENDİ
  String _selectedSort = "En Yeni";
  final List<String> _sortOptions = ["En Yeni", "En Eski", "En Popüler"];

  List<DesignItem> _all = [];
  List<DesignItem> _shown = [];

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);

    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      _prefs = await SharedPreferences.getInstance();
      _isProUser = _prefs.getBool('is_pro_user') ?? false;
      await _loadAssetsAuto();
      _apply();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.mediumImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (!mounted) return;

      if (Platform.isIOS) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IosArSayfasi(imagePath: image.path),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DrawingScreen(
              category: CategoryModel(
                title: "Galerim",
                color: Colors.purpleAccent,
                templateFolder: "",
                imagePath: "",
              ),
              cameras: widget.cameras,
              imagePath: image.path,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAssetsAuto() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();
    final folder = widget.category.templateFolder.trim().toLowerCase();
    final folderPrefix = "assets/templates/$folder/";
    final paths = allAssets
        .where((p) => p.startsWith(folderPrefix))
        .where((p) =>
            p.endsWith(".png") || p.endsWith(".jpg") || p.endsWith(".webp"))
        .toList()
      ..sort(); // Alfabetik sıralar (Bu "En Eski" düzenidir)

    final List<DesignItem> items = [];
    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];
      final fileName = p.split('/').last.toLowerCase();
      String diff = "Kolay";
      if (fileName.contains("medium") || fileName.contains("orta")) {
        diff = "Orta";
      } else if (fileName.contains("hard") || fileName.contains("zor")) {
        diff = "Zor";
      }

      items.add(DesignItem(
        path: p,
        difficulty: diff,
        likes: _prefs.getInt('likes_$p') ?? (i * 3 + 5),
        isLiked: _prefs.getBool('liked_$p') ?? false,
        isSaved: _prefs.getBool('saved_$p') ?? false,
        isPremium: i >= 6,
      ));
    }
    _all = items;
  }

  // ✅ KATEGORİ VE SIRALAMA UYGULAYICI FONKSİYON
  void _apply() {
    setState(() {
      // 1. Önce Tab (Zorluk) Filtresini Uygula
      _shown = _all.where((d) {
        return _selectedTab == "Hepsi" || d.difficulty == _selectedTab;
      }).toList();

      // 2. Sonra Seçilen Sıralamaya Göre Diz
      if (_selectedSort == "En Yeni") {
        // Sondan başa (Z->A) sıralar
        _shown.sort((a, b) => b.path.compareTo(a.path));
      } else if (_selectedSort == "En Eski") {
        // Baştan sona (A->Z) sıralar
        _shown.sort((a, b) => a.path.compareTo(b.path));
      } else if (_selectedSort == "En Popüler") {
        // Beğeni sayısına göre yüksekten düşüğe sıralar
        _shown.sort((a, b) => b.likes.compareTo(a.likes));
      }
    });
  }

  void _onBottomTap(int i) {
    HapticFeedback.lightImpact();

    if (i == 0) {
      Navigator.pop(context);
      return;
    }

    if (i == 1) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LearnScreen(cameras: widget.cameras)));
    } else if (i == 2) {
      Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()))
          .then((_) => _init());
    } else if (i == 3) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: widget.category.color, size: 22),
            onPressed: () => Navigator.pop(context)),
        title: Text(widget.category.title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                fontSize: 20)),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton.extended(
          onPressed: _pickFromGallery,
          backgroundColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.add_photo_alternate_rounded,
              color: Colors.white),
          label: Text("Galeriden Seç",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
      body: _loading
          ? GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 22,
                  childAspectRatio: 0.8),
              itemCount: 6,
              itemBuilder: (_, __) {
                return FadeTransition(
                  opacity: _shimmerController,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                        child: Icon(Icons.image,
                            color: Colors.grey.shade300, size: 40)),
                  ),
                );
              },
            )
          : Column(
              children: [
                // ✅ YENİ SIRALAMA (FİLTRE) ÇUBUĞU
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
                  child: Row(
                    children: [
                      Icon(Icons.sort_rounded,
                          color: widget.category.color, size: 24),
                      const SizedBox(width: 8),
                      Text("Sırala:",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.grey.shade700)),
                      const Spacer(),
                      _neumorphic(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 42,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              value: _selectedSort,
                              icon: Icon(Icons.keyboard_arrow_down_rounded,
                                  color: widget.category.color),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: const Color(0xFF1E293B)),
                              items: _sortOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedSort = newValue);
                                  _apply(); // Seçim değiştiğinde listeyi günceller
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ZORLUK SEVİYELERİ
                Container(
                  height: 45,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        final tab = _tabs[index];
                        return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedTab = tab);
                                  _apply();
                                },
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    decoration: BoxDecoration(
                                        color: _selectedTab == tab
                                            ? widget.category.color
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: _selectedTab == tab
                                            ? []
                                            : [
                                                const BoxShadow(
                                                    color: Colors.white,
                                                    offset: Offset(-3, -3),
                                                    blurRadius: 5),
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.04),
                                                    offset: const Offset(3, 3),
                                                    blurRadius: 5)
                                              ]),
                                    child: Center(
                                        child: Text(tab,
                                            style: GoogleFonts.poppins(
                                                color: _selectedTab == tab
                                                    ? Colors.white
                                                    : Colors.grey.shade700,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13))))));
                      }),
                ),

                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _shown.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 22,
                            childAspectRatio: 0.8),
                    itemBuilder: (_, i) {
                      final item = _shown[i];
                      final locked = item.isPremium;
                      return Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              const BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-5, -5),
                                  blurRadius: 8),
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  offset: const Offset(5, 5),
                                  blurRadius: 8)
                            ]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (locked && !_isProUser) {
                                      Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SubscriptionScreen()))
                                          .then((_) => _init());
                                      return;
                                    }

                                    if (Platform.isIOS) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => IosArSayfasi(
                                            imagePath: item.path,
                                          ),
                                        ),
                                      );
                                    } else {
                                      String glbPath = item.path
                                          .replaceAll('assets/templates/',
                                              'assets/models/')
                                          .replaceAll('.png', '.glb')
                                          .replaceAll('.jpg', '.glb')
                                          .replaceAll('.webp', '.glb');

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ARMiniTestScreen(
                                            glbAssetPath: glbPath,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Hero(
                                            tag: item.path,
                                            child: Image.asset(item.path,
                                                fit: BoxFit.contain),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                          top: 0,
                                          left: 0,
                                          child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                  color: widget.category.color
                                                      .withOpacity(0.9),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                          bottomRight:
                                                              Radius.circular(
                                                                  15))),
                                              child: Text(
                                                  item.difficulty.toUpperCase(),
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white)))),
                                      if (locked)
                                        const Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Icon(
                                                Icons.workspace_premium_rounded,
                                                color: Colors.amber,
                                                size: 18)),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.06)),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                        onTap: () async {
                                          HapticFeedback.mediumImpact();
                                          setState(() {
                                            item.isLiked = !item.isLiked;
                                            item.likes += item.isLiked ? 1 : -1;
                                          });
                                          await _prefs.setBool(
                                              'liked_${item.path}',
                                              item.isLiked);
                                          await _prefs.setInt(
                                              'likes_${item.path}', item.likes);
                                        },
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4, horizontal: 4),
                                            child: Row(children: [
                                              AnimatedScale(
                                                scale:
                                                    item.isLiked ? 1.25 : 1.0,
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                curve: Curves.elasticOut,
                                                child: Icon(
                                                    item.isLiked
                                                        ? Icons.favorite_rounded
                                                        : Icons
                                                            .favorite_border_rounded,
                                                    size: 18,
                                                    color: item.isLiked
                                                        ? Colors.redAccent
                                                        : Colors.grey.shade600),
                                              ),
                                              const SizedBox(width: 4),
                                              Text("${item.likes}",
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700))
                                            ]))),
                                    GestureDetector(
                                      onTap: () async {
                                        HapticFeedback.selectionClick();
                                        setState(
                                            () => item.isSaved = !item.isSaved);
                                        await _prefs.setBool(
                                            'saved_${item.path}', item.isSaved);
                                      },
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4, horizontal: 4),
                                          child: Icon(
                                              item.isSaved
                                                  ? Icons.bookmark_rounded
                                                  : Icons
                                                      .bookmark_border_rounded,
                                              size: 18,
                                              color: item.isSaved
                                                  ? widget.category.color
                                                  : Colors.grey.shade600)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: _onBottomTap,
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
      ),
    );
  }

  Widget _neumorphic({required Widget child}) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              const BoxShadow(
                  color: Colors.white, offset: Offset(-5, -5), blurRadius: 10),
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  offset: const Offset(5, 5),
                  blurRadius: 10)
            ]),
        child: child);
  }
}
