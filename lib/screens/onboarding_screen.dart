import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'categories_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const OnboardingScreen({super.key, required this.cameras});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Hayatify'a Hoş Geldin!",
      "desc":
          "Çizim yapmayı AR teknolojisiyle en eğlenceli şekilde öğrenmeye hazır mısın?",
      "icon": "🎨"
    },
    {
      "title": "Hazırlığını Yap",
      "desc":
          "Telefonunu bir su bardağına veya standa sabitle. Kağıdını kameranın göreceği şekilde yerleştir.",
      "icon": "📱"
    },
    {
      "title": "Çiz ve XP Kazan",
      "desc":
          "Ekrandaki çizgileri takip et, resmini tamamla ve puanları toplayarak seviye atla!",
      "icon": "🏆"
    }
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ Rehberin bir daha görünmemesi için işaret koyuyoruz
    await prefs.setBool('seen_onboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => CategoriesScreen(cameras: widget.cameras)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: _onboardingData.length,
            itemBuilder: (context, i) => _buildPage(i),
          ),

          // Alt Kontroller
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // İlerlemeyi gösteren noktalar
                Row(
                  children: List.generate(
                    _onboardingData.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 5),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.blueAccent
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                // İleri / Başla Butonu
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _onboardingData.length - 1) {
                      _finishOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    _currentPage == _onboardingData.length - 1
                        ? "BAŞLAYALIM"
                        : "İLERİ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_onboardingData[i]["icon"]!,
              style: const TextStyle(fontSize: 100)),
          const SizedBox(height: 40),
          Text(
            _onboardingData[i]["title"]!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _onboardingData[i]["desc"]!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
