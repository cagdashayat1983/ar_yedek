// lib/widgets/category_card.dart - Pİnterest STYLE
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../screens/drawing_screen.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  const CategoryCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => DrawingScreen(category: category)),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [category.color, category.color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              // Karakalem önizleme (1_sketch.png)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'assets/templates/${category.id}_sketch.png'),
                      fit: BoxFit.cover,
                      opacity: 0.15, // Hafif görünüm
                    ),
                  ),
                ),
              ),

              // İçerik
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // AR Badge
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_enhance,
                              size: 16, color: Colors.white),
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

                    // Başlık
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Karakalem şablonu',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),

                    // Alt ikon
                    Icon(Icons.arrow_forward_ios,
                        color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
