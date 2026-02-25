// lib/screens/home_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'learn_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';
import 'categories_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _bottomIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // Süsleme Arka Plan
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 50), // Üst boşluk

                  // ✅ 1. BÜYÜK BUTON: ÇİZİM OKULU
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    LearnScreen(cameras: widget.cameras)));
                      },
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(35),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      const Color(0xFF2575FC).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10))
                            ]),
                        child: Stack(
                          children: [
                            // Kart İçi Süsleme Halkaları
                            Positioned(
                              top: -40,
                              right: -30,
                              child: CircleAvatar(
                                  radius: 80,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.08)),
                            ),
                            Positioned(
                              bottom: -40,
                              right: 50,
                              child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.08)),
                            ),

                            // Merkez İçerik (Yatay Düzen: Row)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // SOL TARAF: DAHA BÜYÜK İKON
                                  Container(
                                    padding: const EdgeInsets.all(
                                        12), // İkon büyüdüğü için iç boşluğu hafif kıstım
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.3),
                                            width: 2)),
                                    child: Image.asset(
                                      "assets/icons/okul_icon.png",
                                      width:
                                          95, // 🔴 BOYUT 75'ten 95'e ÇIKARILDI
                                      height:
                                          95, // 🔴 BOYUT 75'ten 95'e ÇIKARILDI
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.school_rounded,
                                                  color: Colors.white,
                                                  size: 60),
                                    ),
                                  ),

                                  const SizedBox(
                                      width:
                                          15), // İkon ile yazı arasındaki boşluk

                                  // SAĞ TARAF: YAZILAR
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Çizim Okulu",
                                            style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 24,
                                                letterSpacing: -0.5)),
                                        const SizedBox(height: 6),
                                        Text(
                                            "Adım adım çizim yeteneğini geliştir ve XP kazanarak seviye atla.",
                                            style: GoogleFonts.poppins(
                                                color: Colors.white
                                                    .withOpacity(0.85),
                                                fontWeight: FontWeight.w500,
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
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ✅ 2. BÜYÜK BUTON: SERBEST ATÖLYE
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    CategoriesScreen(cameras: widget.cameras)));
                      },
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(35),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10)),
                              const BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-10, -10),
                                  blurRadius: 20),
                            ],
                            border: Border.all(
                                color: Colors.grey.shade100, width: 2)),
                        child: Stack(
                          children: [
                            // Kart İçi Süsleme Halkaları
                            Positioned(
                              top: -20,
                              right: -40,
                              child: CircleAvatar(
                                  radius: 70,
                                  backgroundColor: const Color(0xFFFF7043)
                                      .withOpacity(0.05)),
                            ),
                            Positioned(
                              bottom: -30,
                              left: 40,
                              child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFFFF7043)
                                      .withOpacity(0.05)),
                            ),

                            // Merkez İçerik (Yatay Düzen: Row)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // SOL TARAF: DAHA BÜYÜK İKON
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFF7043)
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFFFF7043)
                                                .withOpacity(0.2),
                                            width: 2)),
                                    child: Image.asset(
                                      "assets/icons/atolye_icon.png",
                                      width:
                                          95, // 🔴 BOYUT 75'ten 95'e ÇIKARILDI
                                      height:
                                          95, // 🔴 BOYUT 75'ten 95'e ÇIKARILDI
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.palette_rounded,
                                                  color: Color(0xFFFF7043),
                                                  size: 60),
                                    ),
                                  ),

                                  const SizedBox(
                                      width:
                                          15), // İkon ile yazı arasındaki boşluk

                                  // SAĞ TARAF: YAZILAR
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Serbest Atölye",
                                            style: GoogleFonts.poppins(
                                                color: const Color(0xFF1E293B),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 24,
                                                letterSpacing: -0.5)),
                                        const SizedBox(height: 6),
                                        Text(
                                            "Hazır şablonları keşfet veya kendi galerinden resimler çiz.",
                                            style: GoogleFonts.poppins(
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
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
                    ),
                  ),

                  const SizedBox(
                      height: 40), // Alt menüye yapışmaması için boşluk
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: (i) {
        if (i == 1) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => LearnScreen(cameras: widget.cameras)));
        } else if (i == 2) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
        } else if (i == 3) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 10,
      selectedItemColor: Colors.blueAccent,
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
