// lib/screens/templates_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../services/subscription_service.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';
import 'learn_screen.dart';
import 'home_screen.dart';

import 'ios_ar_sayfasi.dart';
import 'ar_mini_test_screen.dart';
import 'image_to_sketch_screen.dart';
import 'tutorial_screen.dart';

class DesignItem {
  final String path;
  final String difficultyKey;
  int likes;
  bool isLiked;
  bool isSaved;
  bool isPremium;

  DesignItem({
    required this.path,
    required this.difficultyKey,
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
  bool _isProUser = false;
  bool _loading = true;
  final int _bottomIndex = 0;

  String _selectedTabKey = "all";
  String _selectedSortKey = "newest";

  List<DesignItem> _all = [];
  List<DesignItem> _shown = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      _prefs = await SharedPreferences.getInstance();
      _isProUser = await SubscriptionService.isProUser();
      await _loadAssetsAuto();
      _apply();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _pickFromGallery(AppLocalizations l10n) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              Text(l10n.startDrawing, // ✅ Localized (Hata 170 çözüldü)
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: const Color(0xFF1E293B))),
              const SizedBox(height: 25),
              _buildGalleryOptionTile(
                icon: Icons.auto_fix_high_rounded,
                color: Colors.blueAccent,
                title: l10n.sketchTemplate,
                subtitle: l10n.sketchDesc,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ImageToSketchScreen(cameras: widget.cameras)));
                },
              ),
              const SizedBox(height: 12),
              _buildGalleryOptionTile(
                icon: Icons.photo_rounded,
                color: Colors.orangeAccent,
                title: l10n.originalPhoto,
                subtitle: l10n.originalDesc,
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (image != null && mounted) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TutorialScreen(
                                  title: l10n.originalPhoto,
                                  imagePaths: [image.path],
                                  cameras: widget.cameras,
                                  isLocalFile: true,
                                )));
                  }
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  void _showDrawOptions(DesignItem item, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              Text(l10n.startDrawing,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: const Color(0xFF1E293B))),
              const SizedBox(height: 25),
              _buildGalleryOptionTile(
                icon: Icons.camera_alt_rounded,
                color: Colors.blueAccent,
                title: "Normal Mode",
                subtitle: l10n.onb1Desc,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TutorialScreen(
                                title:
                                    widget.category.getLocalizedTitle(context),
                                imagePaths: [item.path],
                                cameras: widget.cameras,
                                isLocalFile: false,
                              )));
                },
              ),
              const SizedBox(height: 12),
              _buildGalleryOptionTile(
                icon: Icons.view_in_ar_rounded,
                color: Colors.purpleAccent,
                title: "AR Mode",
                subtitle: "3D Drawing Experience",
                onTap: () {
                  Navigator.pop(context);
                  String targetGlbPath = item.path
                      .replaceAll('assets/templates/', 'assets/models/')
                      .replaceAll('.png', '.glb')
                      .replaceAll('.jpg', '.glb');
                  if (Platform.isIOS) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                IosArSayfasi(imagePath: item.path)));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ARMiniTestScreen(glbAssetPath: targetGlbPath)));
                  }
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadAssetsAuto() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();
    final folder = widget.category.templateFolder.toLowerCase();
    final paths = allAssets
        .where((p) => p.startsWith("assets/templates/$folder/"))
        .toList()
      ..sort();

    final List<DesignItem> items = [];
    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];
      final fileName = p.split('/').last.toLowerCase();

      String diffKey = "easy";
      // ✅ Süslü parantez hataları (Hata 246, 248) düzeltildi
      if (fileName.contains("medium") || fileName.contains("orta")) {
        diffKey = "medium";
      } else if (fileName.contains("hard") || fileName.contains("zor")) {
        diffKey = "hard";
      }

      items.add(DesignItem(
        path: p,
        difficultyKey: diffKey,
        likes: _prefs.getInt('likes_$p') ?? (i * 2 + 10),
        isLiked: _prefs.getBool('liked_$p') ?? false,
        isSaved: _prefs.getBool('saved_$p') ?? false,
        isPremium: fileName.contains("pro_"),
      ));
    }
    _all = items;
  }

  void _apply() {
    setState(() {
      // ✅ Süslü parantez hataları (Hata 269, 271, 273) düzeltildi
      _shown = _all
          .where((d) =>
              _selectedTabKey == "all" || d.difficultyKey == _selectedTabKey)
          .toList();
      if (_selectedSortKey == "newest") {
        _shown.sort((a, b) => b.path.compareTo(a.path));
      } else if (_selectedSortKey == "oldest") {
        _shown.sort((a, b) => a.path.compareTo(b.path));
      } else if (_selectedSortKey == "popular") {
        _shown.sort((a, b) => b.likes.compareTo(a.likes));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
        title: Text(widget.category.getLocalizedTitle(context),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                fontSize: 20)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickFromGallery(l10n),
        backgroundColor: const Color(0xFF1E293B),
        icon:
            const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
        label: Text(l10n.drawYourPhoto, // ✅ Localized (Hata 302 çözüldü)
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSortAndFilter(l10n),
                _buildTabs(l10n),
                Expanded(child: _buildGrid(l10n)),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(l10n),
    );
  }

  Widget _buildSortAndFilter(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
      child: Row(
        children: [
          Icon(Icons.sort_rounded, color: widget.category.color, size: 24),
          const SizedBox(width: 8),
          Text(l10n.sort, // ✅ Localized (Hata 326 çözüldü)
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
                  value: _selectedSortKey,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: widget.category.color),
                  items: [
                    // ✅ Localized (Hata 342, 343, 345 çözüldü)
                    DropdownMenuItem(value: "newest", child: Text(l10n.newest)),
                    DropdownMenuItem(value: "oldest", child: Text(l10n.oldest)),
                    DropdownMenuItem(
                        value: "popular", child: Text(l10n.popular)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedSortKey = v);
                      _apply();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l10n) {
    final Map<String, String> tabs = {
      "all": l10n.navHome,
      "easy": l10n.difficultyEasy,
      "medium": l10n.difficultyMedium,
      "hard": l10n.difficultyHard,
    };

    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: tabs.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _selectedTabKey == e.key,
                    onSelected: (s) {
                      if (s) {
                        setState(() => _selectedTabKey = e.key);
                        _apply();
                      }
                    },
                    selectedColor: widget.category.color,
                    labelStyle: GoogleFonts.poppins(
                        color: _selectedTabKey == e.key
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildGrid(AppLocalizations l10n) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _shown.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 0.8),
      itemBuilder: (_, i) {
        final item = _shown[i];
        bool locked = item.isPremium && !_isProUser;
        return GestureDetector(
          onTap: () {
            // ✅ Süslü parantez hataları (Hata 465-480) düzeltildi
            if (locked) {
              _goToSub();
            } else {
              _showDrawOptions(item, l10n);
            }
          },
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100)),
            child: Column(
              children: [
                Expanded(
                    child: Stack(children: [
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(item.path, fit: BoxFit.contain))),
                  if (locked)
                    const Center(
                        child: Icon(Icons.lock_rounded,
                            color: Colors.amber, size: 40)),
                ])),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.favorite,
                          color:
                              item.isLiked ? Colors.red : Colors.grey.shade300,
                          size: 16),
                      Text("${item.likes}",
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _goToSub() {
    Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()))
        .then((_) => _init());
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: (i) {
        // ✅ Süslü parantez hataları düzeltildi
        if (i == 0) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => HomeScreen(cameras: widget.cameras)));
        } else if (i == 1) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LearnScreen(cameras: widget.cameras)));
        } else if (i == 2) {
          Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()))
              .then((_) => _init());
        } else if (i == 3) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF6366F1),
      unselectedItemColor: Colors.grey.shade400,
      items: [
        _buildNavItem("assets/icons/menu.png", l10n.navHome, 0),
        _buildNavItem("assets/icons/learn.png", l10n.navLearn, 1),
        _buildNavItem("assets/icons/pro.png", l10n.navPro, 2),
        _buildNavItem("assets/icons/profile.png", l10n.navProfile, 3),
      ],
    );
  }

  BottomNavigationBarItem _buildNavItem(String path, String label, int index) {
    bool isSelected = _bottomIndex == index;
    return BottomNavigationBarItem(
        icon: Opacity(
            opacity: isSelected ? 1.0 : 0.5,
            child: Image.asset(path, width: 24, height: 24)),
        label: label);
  }

  Widget _buildHandle() => Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10)));

  Widget _buildGalleryOptionTile(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      // ✅ withOpacity -> withValues güncellendi (Hata 520 çözüldü)
      leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color)),
      title: Text(title,
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      tileColor: Colors.grey.shade50,
    );
  }

  Widget _neumorphic({required Widget child}) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                  // ✅ withOpacity -> withValues güncellendi (Hata 538 çözüldü)
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ]),
        child: child);
  }
}
