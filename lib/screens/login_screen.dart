import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'categories_screen.dart'; // ✅ DÜZELTME: Artık burayı çağırıyoruz

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Test için hazır giriş bilgileri
  final _emailController = TextEditingController(text: "admin");
  final _passwordController = TextEditingController(text: "123456");

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    // Yapay bekleme süresi (Giriş yapılıyor efekti)
    await Future.delayed(const Duration(seconds: 1));

    // Basit Giriş Kontrolü
    if (_emailController.text == "admin" &&
        _passwordController.text == "123456") {
      try {
        // 1. Kameraları al
        final cameras = await availableCameras();

        if (mounted) {
          // 2. ✅ DÜZELTME: MainPage yerine CategoriesScreen'e git
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CategoriesScreen(cameras: cameras),
            ),
          );
        }
      } catch (e) {
        debugPrint("Kamera hatası: $e");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hatalı giriş! (admin / 123456)',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final inputBg = const Color(0xFFF9FAFB);
    final borderColor = const Color(0xFFE5E7EB);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Arka Plan Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF1EB), // Açık Şeftali
                  Color(0xFFACE0F9), // Açık Bebek Mavisi
                ],
              ),
            ),
          ),

          // 2. Merkez Kart (Form)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(23),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Giriş Yap",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 35),

                            // Email
                            Text("Email",
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF374151),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              style: GoogleFonts.poppins(color: Colors.black),
                              decoration: _inputDecoration("Email adresiniz",
                                  inputBg, borderColor, Icons.email_outlined),
                              validator: (val) =>
                                  val!.isEmpty ? "Email gerekli" : null,
                            ),
                            const SizedBox(height: 20),

                            // Şifre
                            Text("Şifre",
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF374151),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.poppins(color: Colors.black),
                              decoration: _inputDecoration("Şifreniz", inputBg,
                                  borderColor, Icons.lock_outline),
                              validator: (val) =>
                                  val!.isEmpty ? "Şifre gerekli" : null,
                            ),

                            const SizedBox(height: 25),

                            // Giriş Butonu
                            Container(
                              height: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFFA855F7)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6)
                                        .withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text("GİRİŞ YAP",
                                              style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white)),
                                          const SizedBox(width: 10),
                                          const Icon(Icons.login_rounded,
                                              color: Colors.white, size: 22),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      String hint, Color fillColor, Color borderColor, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey.shade400),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
    );
  }
}
