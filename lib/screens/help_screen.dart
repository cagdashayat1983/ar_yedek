// lib/screens/help_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Yardım ve Özellikler",
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- BÖLÜM 1: TEMEL ÖZELLİKLER ---
          _sectionTitle("ARAÇLAR"),
          _infoCard(Icons.camera_alt, "AR Modu",
              "Telefon kamerasını kullanarak şablonu kağıdın üzerine yansıtır. Telefonu bir bardağa sabitleyip üzerinden çizebilirsin."),
          _infoCard(Icons.lock, "Ekran Kilidi",
              "Çizim yaparken şablonun kaymasını engeller. Ekranı dondurur, böylece elin çarpsa bile görüntü bozulmaz."),
          _infoCard(Icons.grid_on, "Izgara (Grid)",
              "Kağıt üzerindeki oranları daha iyi tutturmak için ekrana yardımcı çizgiler ekler."),
          _infoCard(Icons.flip, "Ayna Modu",
              "Şablonu yatay olarak çevirir. Simetri çalışmaları veya dövme tasarımları için idealdir."),
          _infoCard(Icons.flash_on, "Flaş Desteği",
              "Karanlık ortamlarda kağıdı daha net görmek için telefonun fenerini açar."),

          const SizedBox(height: 20),

          // --- BÖLÜM 2: OYUNLAŞTIRMA (XP) ---
          _sectionTitle("GELİŞİM & XP"),
          _infoCard(Icons.stars_rounded, "XP Nasıl Kazanılır?",
              "Her çizim denemesi sana puan kazandırır! Bir şablonu açıp en az 10 saniye boyunca çizim ekranında kaldığında +20 XP kazanırsın."),
          _infoCard(Icons.trending_up, "Seviye Sistemi",
              "Kazandığın XP'ler birikir ve seviye atlamanı sağlar. Çaylak bir sanatçıdan usta bir ressama dönüşen yolculuğunu profilinden takip et."),

          const SizedBox(height: 20),

          // --- BÖLÜM 3: İÇERİK ---
          _sectionTitle("İÇERİK"),
          _infoCard(Icons.school_rounded, "Öğren Modu",
              "Çizime yeni başlayanlar için özel hazırlanmış rehberler. Kamerayı nasıl konumlandıracağını ve temel teknikleri buradan öğrenebilirsin."),

          const SizedBox(height: 20),

          // --- BÖLÜM 4: PRO ÜYELİK ---
          _sectionTitle("HAYATIFY PRO"),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)], // Hafif Altın
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Colors.orange, size: 32),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Pro Avantajları",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.orange.shade900)),
                      const SizedBox(height: 5),
                      Text(
                          "• Tüm kilitli şablonlara erişim\n• Reklamsız deneyim\n• Sınırsız çizim süresi\n• Yeni eklenenlere öncelikli erişim",
                          style: GoogleFonts.poppins(
                              color: Colors.orange.shade800, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 30),
          Center(
            child: Text("Sürüm 1.0.2 - Hayatify",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400, fontSize: 12)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Bölüm başlıkları için yardımcı widget
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(
        title,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey),
      ),
    );
  }

  // Bilgi kartları için yardımcı widget
  Widget _infoCard(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black87, size: 26),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 5),
                Text(desc,
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade700, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
