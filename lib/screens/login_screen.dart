import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'categories_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    // Basit kontrol: boş geçilmesin
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen e-posta ve şifre gir.")),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      // ✅ Kamera izni iste (AR + Camera için)
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kamera izni gerekli.")),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final cameras = await availableCameras();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CategoriesScreen(cameras: cameras),
          ),
        );
      }
    } catch (e) {
      debugPrint("Login/Kamera hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.poppins(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hoş geldin 👋", style: titleStyle),
              const SizedBox(height: 6),
              Text(
                "Devam etmek için giriş yap.",
                style: GoogleFonts.poppins(color: Colors.black54),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "E-posta",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: "Şifre",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          "Giriş Yap",
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const Spacer(),
              Text(
                "Giriş yaptıktan sonra: Kategoriler → Şablonlar → AR",
                style: GoogleFonts.poppins(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
