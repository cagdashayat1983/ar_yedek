import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'ios_ar_sayfasi.dart';
import 'ar_mini_test_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<String> _favoritePaths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // ✅ HAFIZADAKİ BEĞENİLENLERİ TARAYIP BULAN SİHİRLİ FONKSİYON
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    List<String> favs = [];

    for (String key in keys) {
      // Şablon ekranında beğenileri 'liked_assets/...' şeklinde kaydetmiştik
      if (key.startsWith('liked_') && prefs.getBool(key) == true) {
        // 'liked_' kısmını atıp sadece dosya yolunu alıyoruz
        favs.add(key.replaceFirst('liked_', ''));
      }
    }

    setState(() {
      _favoritePaths = favs;
      _isLoading = false;
    });
  }

  // ✅ BEĞENİYİ KALDIRMA
  Future<void> _removeFavorite(String path) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();

    // Hafızadan beğeniyi geri çek
    await prefs.setBool('liked_$path', false);

    // Toplam beğeni sayısını da 1 azaltalım ki veriler bozulmasın
    int currentLikes = prefs.getInt('likes_$path') ?? 1;
    if (currentLikes > 0) {
      await prefs.setInt('likes_$path', currentLikes - 1);
    }

    // Ekranda anında yok et
    setState(() {
      _favoritePaths.remove(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Açık ferah arka plan
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Beğendiklerim",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoritePaths.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: _favoritePaths.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 22,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final path = _favoritePaths[index];
                    return _buildFavoriteCard(path);
                  },
                ),
    );
  }

  Widget _buildFavoriteCard(String path) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          const BoxShadow(
              color: Colors.white, offset: Offset(-5, -5), blurRadius: 8),
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(5, 5),
              blurRadius: 8)
        ],
      ),
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
                  // Çizime Git (Tıpkı şablonlardaki gibi)
                  if (Platform.isIOS) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IosArSayfasi(imagePath: path),
                      ),
                    );
                  } else {
                    String glbPath = path
                        .replaceAll('assets/templates/', 'assets/models/')
                        .replaceAll('.png', '.glb')
                        .replaceAll('.jpg', '.glb')
                        .replaceAll('.webp', '.glb');

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ARMiniTestScreen(glbAssetPath: glbPath),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Hero(
                    tag: "fav_$path",
                    child: Image.asset(path, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration:
                  BoxDecoration(color: Colors.redAccent.withOpacity(0.08)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _removeFavorite(path), // Kalbe basınca silinir
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 24,
                      color: Colors.redAccent,
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

  // EĞER HİÇ BEĞENİLMİŞ RESİM YOKSA ÇIKACAK EKRAN
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border_rounded,
                size: 80, color: Colors.redAccent),
          ),
          const SizedBox(height: 30),
          Text(
            "Henüz Bir Şey Beğenmedin",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Şablonlarda gezerken favori\ntasarımlarına kalp bırak!",
            textAlign: TextAlign.center,
            style:
                GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
