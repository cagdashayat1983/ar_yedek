// lib/screens/home_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// ✅ Servis ve l10n Importları
import '../l10n/app_localizations.dart';
import '../services/subscription_service.dart';

import 'learn_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';
import 'categories_screen.dart';
import 'image_to_sketch_screen.dart';
import 'tutorial_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _bottomIndex = 0;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
  }

  Future<void> _checkProStatus() async {
    bool status = await SubscriptionService.isProUser();
    if (mounted) {
      setState(() => _isPro = status);
    }
  }

  Future<void> _pickNormalPhoto(String pageTitle) async {
    HapticFeedback.mediumImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TutorialScreen(
            title: pageTitle,
            imagePaths: [image.path],
            cameras: widget.cameras,
            isLocalFile: true,
          ),
        ),
      ).then((_) => _checkProStatus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          _buildTopDecoration(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(l10n),
                    const SizedBox(height: 24),
                    _buildFeatureCard(
                      title: l10n.drawingSchool,
                      desc: l10n.drawingSchoolDesc,
                      icon: Icons.school_rounded,
                      gradient: const [Color(0xFF6366F1), Color(0xFF4338CA)],
                      onTap: () =>
                          _navigateTo(LearnScreen(cameras: widget.cameras)),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      title: l10n.freeAtelier,
                      desc: l10n.freeAtelierDesc,
                      icon: Icons.palette_rounded,
                      isWhite: true,
                      gradient: const [Colors.white, Colors.white],
                      onTap: () => _navigateTo(
                          CategoriesScreen(cameras: widget.cameras)),
                    ),
                    const SizedBox(height: 24),
                    Text(l10n.drawYourPhoto,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B))),
                    const SizedBox(height: 12),
                    _buildHorizontalBanner(
                      title: l10n.sketchTemplate,
                      desc: l10n.sketchDesc,
                      icon: Icons.auto_fix_high_rounded,
                      accentColor: Colors.orange,
                      onTap: () => _navigateTo(
                          ImageToSketchScreen(cameras: widget.cameras)),
                    ),
                    const SizedBox(height: 12),
                    _buildHorizontalBanner(
                      title: l10n.originalPhoto,
                      desc: l10n.originalDesc,
                      icon: Icons.photo_camera_back_rounded,
                      accentColor: Colors.blue,
                      onTap: () => _pickNormalPhoto(l10n.originalPhoto),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(l10n),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "${l10n.welcomeTitle}, ",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text:
                      "${l10n.rankArtist}!", // ✅ Hardcoded "Artist!" kaldırıldı
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isPro)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.amber, size: 28),
          ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String desc,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    bool isWhite = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          border: isWhite
              ? Border.all(color: Colors.grey.shade200, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: (isWhite ? Colors.black : gradient[0])
                  .withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Stack(
          children: [
            _buildCardCircles(isWhite),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  _buildIconBox(icon, isWhite),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.poppins(
                                color: isWhite
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(desc,
                            style: GoogleFonts.poppins(
                                color: isWhite
                                    ? Colors.grey.shade600
                                    : Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalBanner({
    required String title,
    required String desc,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: GoogleFonts.poppins(
                          color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, bool isWhite) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWhite
            ? const Color(0xFFF1F5F9)
            : Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isWhite ? Colors.orange : Colors.white,
        size: 34,
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _checkProStatus());
  }

  Widget _buildTopDecoration() {
    return Positioned(
      top: -100,
      right: -80,
      child: CircleAvatar(
          radius: 150,
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.04)),
    );
  }

  Widget _buildCardCircles(bool isWhite) {
    return Positioned(
      right: -20,
      top: -20,
      child: CircleAvatar(
        radius: 60,
        backgroundColor:
            (isWhite ? Colors.orange : Colors.white).withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: (i) {
        if (i == 0) {
          return;
        }
        Widget nextScreen;
        if (i == 1) {
          nextScreen = LearnScreen(cameras: widget.cameras);
        } else if (i == 2) {
          nextScreen = const SubscriptionScreen();
        } else {
          nextScreen = const ProfileScreen();
        }

        Navigator.push(context, MaterialPageRoute(builder: (_) => nextScreen))
            .then((_) => _checkProStatus());
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF6366F1),
      unselectedItemColor: Colors.grey.shade400,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 11),
      items: [
        _buildNavItem("assets/icons/menu.png", l10n.navHome, true),
        _buildNavItem("assets/icons/learn.png", l10n.navLearn, false),
        _buildNavItem("assets/icons/pro.png", l10n.navPro, false),
        _buildNavItem("assets/icons/profile.png", l10n.navProfile, false),
      ],
    );
  }

  BottomNavigationBarItem _buildNavItem(
      String path, String label, bool isSelected) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Opacity(
          opacity: isSelected ? 1.0 : 0.5,
          child: Image.asset(path, width: 24, height: 24),
        ),
      ),
      label: label,
    );
  }
}
