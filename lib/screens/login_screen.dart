import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Eklendi
import 'subscription_screen.dart'; // ✅ Eklendi
import 'categories_screen.dart';

class LoginScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LoginScreen({super.key, required this.cameras});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _goToApp() async {
    setState(() => _loading = true);
    try {
      // Kamera izni kontrolü
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Kamera izni gerekli. 📸"),
              backgroundColor: Colors.amber,
            ),
          );
        }
        return;
      }

      // ✅ KULLANICIYI GİRİŞ YAPTI OLARAK İŞARETLE
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      if (!mounted) return;

      // ✅ DİREKT ANA SAYFAYA DEĞİL, İLK SATIŞ TEKLİFİNE (SUBSCRIPTION) YOLLA
      // Giderken de "Bu ilk açılış teklifi, çarpıya basarsan ana sayfaya git" demek için
      // isFirstOffer parametresini true yolluyoruz.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriptionScreen(
            cameras: widget.cameras,
            isFirstOffer: true, // İlk teklif olduğunu belirtiyoruz
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // --- ARKA PLAN SÜSLEMELERİ ---
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.05),
              ),
            ),
          ),

          // --- ANA İÇERİK ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LOGO / ICON
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 50, color: Colors.amber),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      "Hoş Geldin!",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Hayatify ile çizmeye hazır mısın?",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- GİRİŞ FORMU ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputLabel("Email Adresi"),
                        _CleanInput(
                          controller: _email,
                          hint: "email@adres.com",
                          prefix: Icons.alternate_email_rounded,
                        ),
                        const SizedBox(height: 20),

                        _inputLabel("Şifre"),
                        _CleanInput(
                          controller: _pass,
                          hint: "••••••••",
                          prefix: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: Colors.grey.shade400),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              "Şifremi Unuttum",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade400,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // GİRİŞ YAP BUTONU
                        GestureDetector(
                          onTap: _loading ? null : _goToApp,
                          child: Container(
                            height: 60,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 3))
                                  : Text(
                                      "GİRİŞ YAP",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // --- SOSYAL GİRİŞ ---
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade200)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Text(
                            "Veya",
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade200)),
                      ],
                    ),
                    const SizedBox(height: 25),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocialBtn(
                            icon: Icons.g_mobiledata_rounded,
                            color: Colors.redAccent,
                            onTap: _goToApp),
                        const SizedBox(width: 20),
                        _SocialBtn(
                            icon: Icons.apple_rounded,
                            color: Colors.black,
                            onTap: _goToApp),
                        const SizedBox(width: 20),
                        _SocialBtn(
                            icon: Icons.facebook_rounded,
                            color: const Color(0xFF1877F2),
                            onTap: _goToApp),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // KAYIT OL LİNKİ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Hesabın yok mu? ",
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.grey.shade600)),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            "Kayıt Ol",
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.orange.shade500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155)),
      ),
    );
  }
}

class _CleanInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefix;
  final bool obscureText;
  final Widget? suffix;

  const _CleanInput({
    required this.controller,
    required this.hint,
    required this.prefix,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400),
          prefixIcon: Icon(prefix, color: Colors.grey.shade400, size: 22),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
