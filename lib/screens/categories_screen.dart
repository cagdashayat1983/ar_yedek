import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/category_model.dart';
import 'templates_screen.dart';
import 'learn_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CategoriesScreen({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _selectedIndex = 0;

  void _onBottomNavTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) {
      // ✅ LearnScreen hâlâ kamera istiyor
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LearnScreen(cameras: widget.cameras),
        ),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SubscriptionScreen(),
        ),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          "Kategoriler",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: GridView.builder(
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _CategoryTile(
              category: category,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // ✅ FIX: cameras kaldırıldı
                    builder: (_) => TemplatesScreen(
                      category: category,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: "Kategoriler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: "Öğren",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.workspace_premium_rounded),
            label: "PRO",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: "Hesabım",
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                category.coverAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: category.color.withOpacity(0.12),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 40,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.70),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      category.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
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
