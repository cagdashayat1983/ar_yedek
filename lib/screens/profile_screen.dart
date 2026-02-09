import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // AssetManifest için
import 'package:camera/camera.dart'; // Kamera için
import '../models/category_model.dart';
import 'drawing_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<String> _likedImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedImages();
  }

  // 💖 Beğenilen resimleri hafızadan TARAYIP getiren fonksiyon
  Future<void> _loadLikedImages() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // ✅ DÜZELTME BURADA: AssetManifest.json'ı string olarak yüklemeye çalışmayı kaldırdık.
      // Sadece Flutter'ın kendi güvenli fonksiyonunu kullanıyoruz.
      final manifest = await AssetManifest.loadFromAssetBundle(
          DefaultAssetBundle.of(context));
      final allAssets = manifest.listAssets();

      List<String> tempLiked = [];

      // 2. Her bir resim için "Bunu beğendi mi?" diye hafızaya sor
      for (String path in allAssets) {
        // Sadece 'assets/templates' içindekilere bak
        if (path.contains("assets/templates/")) {
          // Anahtarlar 'liked_dosyayolu' şeklinde kayıtlı
          bool isLiked = prefs.getBool('liked_$path') ?? false;

          if (isLiked) {
            tempLiked.add(path);
          }
        }
      }

      if (mounted) {
        setState(() {
          _likedImages = tempLiked;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Profil Yükleme Hatası: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Hesabım",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 👤 Profil Kartı
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Color(0xFF7B61FF),
                  child: Icon(Icons.person, color: Colors.white, size: 35),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Kullanıcı",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("Favori Koleksiyoncusu",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ❤️ Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.redAccent),
                const SizedBox(width: 10),
                Text(
                  "Beğendiğim Tasarımlar (${_likedImages.length})",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ],
            ),
          ),

          // 🖼️ Favori Tasarımlar Izgarası
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _likedImages.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // 3 Sütunlu görünüm
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _likedImages.length,
                        itemBuilder: (context, index) {
                          return _buildLikedItem(_likedImages[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            "Henüz hiç bir tasarımı beğenmedin.",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedItem(String path) {
    return GestureDetector(
      onTap: () async {
        // 📸 Kamera erişimi alıp DrawingScreen'e gönderiyoruz
        try {
          final cameras = await availableCameras();
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => DrawingScreen(
                  // Kategoriyi sahte oluşturuyoruz çünkü sadece resim önemli
                  category: CategoryModel(
                      id: "fav",
                      title: "Favorilerim",
                      color: Colors.redAccent,
                      isPro: false,
                      itemCount: 0),
                  cameras: cameras,
                  imagePath: path, // ✅ Beğenilen resmi aç
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint("Kamera hatası: $e");
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(path, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
