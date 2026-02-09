import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category_model.dart';
import 'templates_screen.dart';
import 'learn_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart'; // ✅ Abonelik ekranı eklendi

class CategoriesScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CategoriesScreen({super.key, required this.cameras});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _selectedIndex = 0;

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      setState(() => _selectedIndex = index);
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LearnScreen(cameras: widget.cameras),
        ),
      ).then((_) => setState(() => _selectedIndex = 0));
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      ).then((_) => setState(() => _selectedIndex = 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      // ✅ YENİ: SOL ALTA PRO BUTONU
      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat, // Sol Alt Konum
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Abonelik sayfasına git
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
          );
        },
        backgroundColor: Colors.amber[700], // Altın Sarısı
        icon: const Icon(Icons.workspace_premium, color: Colors.white),
        label: Text("PRO",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
      ),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "Kategoriler",
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.category_rounded),
            label: "Kategoriler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: "Eğitim",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: "Hesabım",
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            20, 10, 20, 80), // Fab için alt boşluk arttı
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryRow(context, category);
        },
      ),
    );
  }

  Widget _buildCategoryRow(BuildContext context, CategoryModel category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TemplatesScreen(
              category: category,
              cameras: widget.cameras,
            ),
          ),
        );
      },
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: category.color.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        category.color.withOpacity(0.05),
                        Colors.white,
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 140,
                    height: 150,
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.1),
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(28)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          right: -20,
                          bottom: -20,
                          child: Icon(
                            Icons.category_outlined,
                            size: 100,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        Image.asset(
                          category.imagePath ?? 'assets/placeholder.png',
                          fit: BoxFit.contain,
                          scale: 0.7,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: category.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${category.itemCount} Tasarım",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: category.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: category.color,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
