import 'package:flutter/material.dart';

class SketchCard extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;

  const SketchCard({
    super.key,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Dosya adını temizle (.png ve yol kısmını kaldır)
    final filename = imagePath.split('/').last.replaceAll('.png', '');

    return Material(
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.3),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. Ana resim (karakalem)
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported,
                      size: 60, color: Colors.grey),
                ),
              ),
            ),

            // 2. Gradient overlay (Pinterest efekti)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),

            // 3. AR Badge (sağ üst)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'AR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Dosya adı (alt)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename, // ✅ Direkt dosya adı: "aslan", "fil", "animal_1"
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kağıda çizmek için hazır!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 5. İleri ok (sağ alt)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
