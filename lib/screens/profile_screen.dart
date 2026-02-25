// lib/screens/profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'progress_roadmap_screen.dart';
import 'history_screen.dart';
import 'subscription_screen.dart';
import 'favorites_screen.dart'; // ✅ BEĞENDİKLERİM SAYFASI EKLENDİ

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _userXp = 0;
  String _rank = "Çaylak";
  bool _isPro = false;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? imagePath = prefs.getString('profile_image_path');
    setState(() {
      _userXp = prefs.getInt('total_xp') ?? 0;
      _rank = _userXp >= 2000 ? "Çizimci" : "Çaylak";
      _isPro = prefs.getBool('is_pro_user') ?? false;
      if (imagePath != null && File(imagePath).existsSync()) {
        _profileImage = File(imagePath);
      }
    });
  }

  // ✅ RESİM SEÇME VE KAYDETME
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File savedImage =
          await File(image.path).copy('${directory.path}/$fileName');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', savedImage.path);

      setState(() {
        _profileImage = savedImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ✅ ÜST KISIM: RESİM VE BAŞLIK BURADA
          _buildSliverAppBar(),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProgressCard(),
                const SizedBox(height: 16),
                _buildPremiumButton(),
                const SizedBox(height: 25),

                _buildMenuTitle("ETKİNLİKLER"),

                // ✅ YENİ EKLENEN BEĞENDİKLERİM BUTONU
                _menuItem(Icons.favorite_rounded, "Beğendiklerim", () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FavoritesScreen()));
                }),

                _menuItem(Icons.history_edu_rounded, "Çizim Geçmişim", () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()));
                }),

                _buildMenuTitle("DESTEK"),
                _menuItem(Icons.help_outline_rounded, "Yardım Merkezi", () {}),
                _menuItem(Icons.info_outline_rounded, "Hakkımızda", () {}),
                const SizedBox(height: 50),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      title: Text(
        "PROFİLİM",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: Colors.white,
          shadows: [const Shadow(color: Colors.black54, blurRadius: 10)],
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF334155)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white24,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : null,
                      child: _profileImage == null
                          ? const Icon(Icons.person,
                              size: 50, color: Colors.white54)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.amber, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Ressam Çağdaş",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              Text(
                "Rütbe: $_rank",
                style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    double progress = (_userXp % 2000) / 2000;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ProgressRoadmapScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph_rounded, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Text("GELİŞİM SEVİYEM",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.blue.withOpacity(0.05),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$_userXp XP",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.blueAccent)),
                Text("Hedefe ${2000 - (_userXp % 2000)} XP kaldı",
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.amber.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: Colors.amber, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("HAYATIFY PRO",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                  const Text("Tüm kilitleri aç ve sınırsız çiz",
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.amber, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 10, left: 5),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 1.5)),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF1E293B), size: 22),
        title: Text(title,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right_rounded,
            size: 20, color: Colors.grey),
      ),
    );
  }
}
