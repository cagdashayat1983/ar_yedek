import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart'; // ✅ Eklendi
import 'categories_screen.dart'; // ✅ Eklendi

class SubscriptionScreen extends StatelessWidget {
  // ✅ Akıllı yönlendirme için eklendi
  final bool isFirstOffer;
  final List<CameraDescription>? cameras;

  const SubscriptionScreen({
    super.key,
    this.isFirstOffer = false,
    this.cameras,
  });

  Future<void> _goPro(BuildContext context) async {
    // Pro üyeliği aktif et ve kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_user', true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tebrikler! Artık Hayatify PRO üyesisin! 👑"),
          backgroundColor: Colors.amber,
        ),
      );

      // ✅ BAŞARILI SATIN ALMADAN SONRA YÖNLENDİRME
      _closeOrGoHome(context);
    }
  }

  // ✅ ÇARPIYA BASINCA VEYA SATIN ALINCA ÇALIŞACAK MANTIK
  void _closeOrGoHome(BuildContext context) {
    if (isFirstOffer && cameras != null) {
      // Eğer loginden geldiyse ve çarpıya bastıysa (veya aldıysa) ana sayfaya geç
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(cameras: cameras!),
        ),
      );
    } else {
      // Zaten uygulamanın içindeyse sadece bu sayfayı kapat
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Arka plan süslemesi (Hafif gradient)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ AKILLI KAPAT BUTONU
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 30),
                    onPressed: () => _closeOrGoHome(context),
                  ),
                ),

                const SizedBox(height: 10),

                // Başlık ve İkon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      size: 60, color: Colors.amber),
                ),
                const SizedBox(height: 20),
                Text(
                  "Hayatify PRO'ya Geç",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  "Sınırları kaldır, sanatını özgür bırak!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 40),

                // Özellik Listesi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      _featureRow("Tüm Şablonlara Erişim", true),
                      _featureRow("Reklamsız Deneyim", true),
                      _featureRow("Sınırsız Çizim Süresi", true),
                      _featureRow("Özel Kalem Araçları", true),
                      _featureRow("Yeni Gelenlere Öncelik", true),
                    ],
                  ),
                ),

                const Spacer(),

                // Fiyat Kartı
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.5), width: 2),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("YILLIK PLAN",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber,
                                  fontSize: 12)),
                          Text("₺199.99 / Yıl",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  fontSize: 18)),
                        ],
                      ),
                      Text("7 Gün\nÜcretsiz",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                              fontSize: 12)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Satın Al Butonu
                GestureDetector(
                  onTap: () => _goPro(context),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 20),
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "PRO'YA GEÇ VE BAŞLA",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                Text(
                  "İstediğin zaman iptal edebilirsin.",
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(String text, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active ? Colors.green.shade100 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check,
                size: 16, color: active ? Colors.green : Colors.grey),
          ),
          const SizedBox(width: 15),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
