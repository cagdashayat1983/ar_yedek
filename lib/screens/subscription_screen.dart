import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  Future<void> _activatePro(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_user', true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Artık PRO Üyesiniz!"), backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context))),
            const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            Text("PRO ÜYE OL",
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const Padding(
                padding: EdgeInsets.all(30.0),
                child: Text(
                    "Tüm taçlı tasarımlara erişim ve sınırsız kayıt hakkı kazanın.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70))),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _activatePro(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  minimumSize: const Size(250, 60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
              child: const Text("AYLIK ₺99.99'A KATIL",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
