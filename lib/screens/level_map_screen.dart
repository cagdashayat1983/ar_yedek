import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressRoadmapScreen extends StatefulWidget {
  const ProgressRoadmapScreen({super.key});

  @override
  State<ProgressRoadmapScreen> createState() => _ProgressRoadmapScreenState();
}

class _ProgressRoadmapScreenState extends State<ProgressRoadmapScreen> {
  int _userLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userLevel = prefs.getInt('user_level') ?? 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> levels = [
      {"lvl": 1, "icon": Icons.star, "title": "Çaylak"},
      {"lvl": 2, "icon": Icons.brush, "title": "Çizimci"},
      {"lvl": 3, "icon": Icons.military_tech, "title": "Usta Çırak"},
      {"lvl": 4, "icon": Icons.emoji_events, "title": "Sanat Kaşifi"},
      {"lvl": 5, "icon": Icons.castle, "title": "Efsane"},
    ];

    return Scaffold(
      // İstediğin o koyu/modern arka plan
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Gelişim Yolculuğum",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            for (int i = 0; i < levels.length; i++) ...[
              _buildNode(levels[i], i),
              if (i != levels.length - 1) _buildConnector(i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNode(Map<String, dynamic> data, int index) {
    bool isReached = _userLevel >= data['lvl'];
    Alignment alignment = Alignment.center;
    if (index % 3 == 1)
      alignment = Alignment.centerLeft;
    else if (index % 3 == 2) alignment = Alignment.centerRight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Align(
        alignment: alignment,
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isReached ? Colors.amber : Colors.white10,
                border: Border.all(
                    color: isReached ? Colors.white : Colors.white24, width: 3),
                boxShadow: isReached
                    ? [
                        BoxShadow(
                            color: Colors.amber.withOpacity(0.4),
                            blurRadius: 15)
                      ]
                    : [],
              ),
              child: Icon(data['icon'],
                  color: isReached ? Colors.black : Colors.white24, size: 35),
            ),
            const SizedBox(height: 10),
            Text(data['title'],
                style: GoogleFonts.poppins(
                    color: isReached ? Colors.white : Colors.white24,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnector(int index) {
    return Container(
      height: 70,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: CustomPaint(painter: RoadmapPainter(index: index)),
    );
  }
}

class RoadmapPainter extends CustomPainter {
  final int index;
  RoadmapPainter({required this.index});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (index % 3 == 0) {
      path.moveTo(size.width / 2, 0);
      path.quadraticBezierTo(
          size.width / 2, size.height / 2, size.width * 0.15, size.height);
    } else if (index % 3 == 1) {
      path.moveTo(size.width * 0.15, 0);
      path.quadraticBezierTo(
          size.width / 2, size.height / 2, size.width * 0.85, size.height);
    } else {
      path.moveTo(size.width * 0.85, 0);
      path.quadraticBezierTo(
          size.width / 2, size.height / 2, size.width / 2, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
