import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'categories_screen.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  // ✅ 1. ADIM: Dışarıdan gelen kameraları kabul ediyoruz
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
  // ignore: unused_field
  bool _rememberMe = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // ✅ 2. ADIM: Uygulamaya Geçiş Fonksiyonu Güncellendi
  Future<void> _goToApp() async {
    setState(() => _loading = true);
    try {
      // Kamera izni kontrolü
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kamera izni gerekli. 📸")),
          );
        }
        return;
      }

      if (!mounted) return;

      // ✅ Kamerayı tekrar taramak yerine main'den gelen 'widget.cameras' kullanılıyor
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CategoriesScreen(cameras: widget.cameras),
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
    const Color bgColor = Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- LOGO / ICON ---
                _NeumorphicContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 20,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.pink,
                          AppColors.lilac,
                          AppColors.blue
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Hoş Geldin!",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  "Hayatify ile çizmeye hazır mısın?",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),

                // --- GİRİŞ KARTI ---
                _NeumorphicContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 30,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inputLabel("Email Adresi"),
                      _SoftInput(
                        controller: _email,
                        hint: "email@adres.com",
                        prefix: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 20),
                      _inputLabel("Şifre"),
                      _SoftInput(
                        controller: _pass,
                        hint: "••••••••",
                        prefix: Icons.lock_outline_rounded,
                        obscureText: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              "Şifremi Unuttum?",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.lilac.withBlue(150),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // GİRİŞ BUTONU
                      _GradientButton(
                        onPressed: _loading ? null : _goToApp,
                        loading: _loading,
                        text: "Giriş Yap",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // --- SOSYAL GİRİŞ ---
                Text(
                  "Veya şunlarla devam et",
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
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
                            color: const Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B)),
      ),
    );
  }
}

// --- YARDIMCI BİLEŞENLER ---

class _NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  const _NeumorphicContainer(
      {required this.child,
      this.borderRadius = 20,
      this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          const BoxShadow(
              color: Colors.white, offset: Offset(-6, -6), blurRadius: 12),
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(6, 6),
              blurRadius: 12),
        ],
      ),
      child: child,
    );
  }
}

class _SoftInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefix;
  final bool obscureText;
  final Widget? suffix;

  const _SoftInput(
      {required this.controller,
      required this.hint,
      required this.prefix,
      this.obscureText = false,
      this.suffix});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(prefix, color: Colors.grey.shade500, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool loading;

  const _GradientButton(
      {this.onPressed, required this.text, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.pink, AppColors.lilac]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.pink.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _NeumorphicContainer(
        borderRadius: 50,
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}

class AppColors {
  static const lilac = Color(0xFFE8C0FC);
  static const blue = Color(0xFFA8DEFA);
  static const pink = Color(0xFFFF99C8);
}
