import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
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

  // ✅ PROGRAMIN ÖZELLİKLERİNİ ANLATAN YENİ İÇERİK
  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Sihirli AR Çizim",
      "desc":
          "Telefonunu bir bardağa veya standa sabitle, kameradan bak ve ekrandaki çizgileri kağıdına kolayca aktar.",
      "icon": Icons.view_in_ar_rounded,
      "color": const Color(0xFFFF7043), // Turuncu/Mercan
    },
    {
      "title": "Adım Adım Öğren",
      "desc":
          "Kolaydan zora yüzlerce şablon ile yeteneklerini geliştir. İstediğin kategoriyi seç ve sanatını konuştur.",
      "icon": Icons.auto_stories_rounded,
      "color": const Color(0xFF42A5F5), // Mavi
    },
    {
      "title": "Galerini Şablona Çevir",
      "desc":
          "Sadece bizim şablonlarımızla sınırlı kalma. Galerinden dilediğin fotoğrafı seç ve anında çizime başla.",
      "icon": Icons.add_photo_alternate_rounded,
      "color": const Color(0xFFAB47BC), // Mor
    },
    {
      "title": "Çizdikçe Seviye Atla",
      "desc":
          "Tamamladığın her çizimde XP kazan, seviyeleri geç ve 'Çaylak'lıktan usta bir 'Çizimci'ye dönüş!",
      "icon": Icons.emoji_events_rounded,
      "color": const Color(0xFFFFCA28), // Altın/Sarı
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // --- ARKA PLAN SÜSLEMELERİ (Login ekranı ile uyumlu) ---
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage]["color"].withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage]["color"].withOpacity(0.05),
              ),
            ),
          ),

          // --- ATLA BUTONU ---
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  "Geç",
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // --- KAYDIRILABİLİR İÇERİK ---
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) => _buildPage(index),
          ),

          // --- ALT KONTROLLER (Noktalar ve Buton) ---
          Positioned(
            bottom: 50,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Noktalar
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => _buildDot(index),
                  ),
                ),

                // İleri / Başla Butonu
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
                    width: _currentPage == _pages.length - 1 ? 150 : 60,
                    decoration: BoxDecoration(
                      color: _pages[_currentPage]["color"],
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: _pages[_currentPage]["color"].withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _currentPage == _pages.length - 1
                          ? Text(
                              "BAŞLA",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 1,
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

  Widget _buildPage(int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // İkon / Görsel Alanı
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: _pages[i]["color"].withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _pages[i]["icon"],
              size: 100,
              color: _pages[i]["color"],
            ),
          ),
          const SizedBox(height: 60),

          // Başlık
          Text(
            _pages[i]["title"],
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E293B),
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),

          // Açıklama
          Text(
            _pages[i]["desc"],
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 80), // Alt bar için boşluk
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
            : Colors.grey.shade300,
      ),
    );
  }
}
