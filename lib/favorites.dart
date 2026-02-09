// lib/favorites.dart
// Bu dosya beğenilen resimlerin listesini tutar

class Favorites {
  // Beğenilen resimlerin yollarını (path) burada saklıyoruz
  static final Set<String> likedImages = {};

  // Beğenme/Vazgeçme işlemi
  static void toggleLike(String imagePath) {
    if (likedImages.contains(imagePath)) {
      likedImages.remove(imagePath); // Zaten varsa sil (Beğenmekten vazgeç)
    } else {
      likedImages.add(imagePath); // Yoksa ekle (Beğen)
    }
  }

  // Resim beğenilmiş mi kontrol et
  static bool isLiked(String imagePath) {
    return likedImages.contains(imagePath);
  }
}
