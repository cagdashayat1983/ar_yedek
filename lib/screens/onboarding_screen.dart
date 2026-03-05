// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';

import '../l10n/app_localizations.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const OnboardingScreen({super.key, required this.cameras});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ✅ Sadece görsel ve renk verilerini tutuyoruz, metinler l10n'dan gelecek
  final List<Map<String, dynamic>> _pages = [
    {
      "image": "assets/icons/onb_robot.png",
      "color": const Color(0xFFE91E63),
    },
    {
      "image": "assets/icons/onb_kapibara.png",
      "color": const Color(0xFF9C27B0),
    },
    {
      "image": "assets/icons/onb_lollipop.png",
      "color": const Color(0xFF42A5F5),
    },
    {
      "image": "assets/icons/onb_anime.png",
      "color": const Color(0xFFFFCA28),
    }
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(cameras: widget.cameras)),
    );
  }

  // ✅ Başlıkları index'e göre getiren temiz fonksiyon
  String _getTitle(int index, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return l10n.onb1Title;
      case 1:
        return l10n.onb2Title;
      case 2:
        return l10n.onb3Title;
      case 3:
        return l10n.onb4Title;
      default:
        return "";
    }
  }

  // ✅ Açıklamaları index'e göre getiren temiz fonksiyon
  String _getDesc(int index, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return l10n.onb1Desc;
      case 1:
        return l10n.onb2Desc;
      case 2:
        return l10n.onb3Desc;
      case 3:
        return l10n.onb4Desc;
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Kaydırılabilir İçerik
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() => _currentPage = page);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _pages[index]["image"],
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                        stops: const [0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _getTitle(index, l10n), // ✅ Dinamik Başlık
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 32,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getDesc(index, l10n), // ✅ Dinamik Açıklama
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 130),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. ATLA (SKIP) BUTONU
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 10),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    l10n.skip, // ✅ l10n kullanıldı (Skip / Geç)
                    style: GoogleFonts.montserrat(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. ALT KONTROLLER (Dots & Button)
          Positioned(
            bottom: 50,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => _buildDot(index),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_currentPage == _pages.length - 1) {
                      _completeOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 60,
                    width: _currentPage == _pages.length - 1 ? 160 : 60,
                    decoration: BoxDecoration(
                      color: _pages[_currentPage]["color"],
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: _pages[_currentPage]["color"]
                              .withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _currentPage == _pages.length - 1
                          ? Text(
                              l10n.getStarted, // ✅ l10n kullanıldı (START / BAŞLA)
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _currentPage == index
            ? _pages[_currentPage]["color"]
            : Colors.white.withValues(alpha: 0.4), // ✅ withValues uygulandı
      ),
    );
  }
}
