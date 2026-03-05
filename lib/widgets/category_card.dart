// lib/widgets/category_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import '../models/category_model.dart';
import '../screens/templates_screen.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final List<CameraDescription> cameras;

  const CategoryCard({
    super.key,
    required this.category,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TemplatesScreen(
              category: category,
              cameras: cameras,
            ),
          ),
        );
      },
      child: Container(
        // ✅ Hata 48 & 49: 'const' ekleyerek performans uyarısını çözdük
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              // ✅ Hero tag için benzersiz olan 'titleKey' kullanıyoruz
              tag: "cat_${category.titleKey}",
              child: Icon(
                category.icon,
                size: 40,
                color: category.color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              // ✅ Hata 108: 'title' yerine 'getLocalizedTitle(context)' metodunu çağırdık
              category.getLocalizedTitle(context),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            if (category.isPremium)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.workspace_premium,
                    color: Colors.amber, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
