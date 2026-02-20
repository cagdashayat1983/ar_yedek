import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressRoadmapScreen extends StatefulWidget {
  const ProgressRoadmapScreen({super.key});

  @override
  State<ProgressRoadmapScreen> createState() => _ProgressRoadmapScreenState();
}

class _ProgressRoadmapScreenState extends State<ProgressRoadmapScreen> {
  int _totalXp = 0;

  @override
  void initState() {
    super.initState();
    _loadXp();
  }

  // ✅ SharedPreferences'tan TutorialScreen'in kaydettiği XP'yi çekiyoruz
  Future<void> _loadXp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalXp = prefs.getInt('total_xp') ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ PUANLAMA VE SEVİYE EŞİKLERİ
    // Senin istediğin gibi: 2000 XP'de Çizimci olunuyor.
    final List<Map<String, dynamic>> levels = [
      {"xp": 0, "icon": Icons.star_border_rounded, "title": "Çaylak"},
      {"xp": 2000, "icon": Icons.brush_rounded, "title": "Çizimci"},
      {"xp": 5000, "icon": Icons.military_tech_rounded, "title": "Usta Çırak"},
      {
        "xp": 10000,
        "icon": Icons.emoji_events_rounded,
        "title": "Sanat Kaşifi"
      },
      {"xp": 20000, "icon": Icons.castle_rounded, "title": "Efsane Ressam"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Modern Karanlık Tema
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text("GELİŞİM YOLCULUĞUM",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 16)),
            Text("$_totalXp TOPLAM XP",
                style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            // Yol Haritası Düğümleri
            for (int i = 0; i < levels.length; i++) ...[
              _buildRoadmapNode(levels[i], i),
              if (i != levels.length - 1)
                _buildPathConnector(i, _totalXp >= levels[i + 1]['xp']),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ✅ ZİKZAK ÇİZEN DÜĞÜM TASARIMI
  Widget _buildRoadmapNode(Map<String, dynamic> data, int index) {
    bool isUnlocked = _totalXp >= data['xp'];

    // S Şeklinde kıvrılma mantığı
    Alignment alignment = Alignment.center;
    if (index % 3 == 1)
      alignment = Alignment.centerLeft;
    else if (index % 3 == 2) alignment = Alignment.centerRight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Align(
        alignment: alignment,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Arka Plan Parlama Efekti (Sadece açılanlarda)
                if (isUnlocked)
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.amber.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5)
                      ],
                    ),
                  ),
                // Ana Daire
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked ? Colors.white : Colors.white10,
                    border: Border.all(
                        color: isUnlocked ? Colors.amber : Colors.white24,
                        width: 3),
                  ),
                  child: Icon(data['icon'],
                      color:
                          isUnlocked ? const Color(0xFF0F172A) : Colors.white24,
                      size: 35),
                ),
                // Eğer bir sonraki seviyeye çok yakınsa kilit ikonu (opsiyonel)
                if (!isUnlocked)
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(Icons.lock, color: Colors.white54, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['title'].toUpperCase(),
              style: GoogleFonts.poppins(
                  color: isUnlocked ? Colors.white : Colors.white24,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1),
            ),
            if (!isUnlocked)
              Text(
                "${data['xp']} XP GEREKLİ",
                style: GoogleFonts.poppins(
                    color: Colors.amber.withOpacity(0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ KIVRIMLI YOL ÇİZGİSİ
  Widget _buildPathConnector(int index, bool isPathActive) {
    return Container(
      height: 80,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: CustomPaint(
        painter: RoadmapPathPainter(index: index, isActive: isPathActive),
      ),
    );
  }
}

// ✅ S ŞEKLİNDE YOL ÇİZEN ÖZEL SINIF
class RoadmapPathPainter extends CustomPainter {
  final int index;
  final bool isActive;

  RoadmapPathPainter({required this.index, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? Colors.amber.withOpacity(0.6) : Colors.white10
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Zikzak Mantığı
    if (index % 3 == 0) {
      // Orta -> Sol
      path.moveTo(size.width / 2, 0);
      path.quadraticBezierTo(
          size.width / 2, size.height / 2, size.width * 0.15, size.height);
    } else if (index % 3 == 1) {
      // Sol -> Sağ
      path.moveTo(size.width * 0.15, 0);
      path.quadraticBezierTo(
          size.width / 2, size.height / 2, size.width * 0.85, size.height);
    } else {
      // Sağ -> Orta
      path.moveTo(size.width * 0.85, 0);
      path.quadraticBezierTo(
          size.width / 2, size.height / 2, size.width / 2, size.height);
    }

    // Kesik Çizgi (Dashed Line) Efekti
    double dashWidth = 10, dashSpace = 8, distance = 0;
    for (var i in path.computeMetrics()) {
      while (distance < i.length) {
        canvas.drawPath(i.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
