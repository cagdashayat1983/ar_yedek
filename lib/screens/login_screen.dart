import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ l10n Importu (Dizine dikkat!)
import '../l10n/app_localizations.dart';

import 'subscription_screen.dart';

class LoginScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LoginScreen({super.key, required this.cameras});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  // ✅ Giriş ve İzin Yönetimi
  Future<void> _handleLogin(String provider) async {
    final l10n = AppLocalizations.of(context)!; // Hata mesajları için l10n

    setState(() => _loading = true);
    try {
      // 1. ✅ Kamera ve Mikrofon İzinlerini İste
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      // İzinlerden biri bile reddedildiyse durdur
      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.permissionError), // ✅ l10n kullanıldı
              backgroundColor: Colors.amber,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 2. Kullanıcıyı sisteme kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('login_provider', provider);

      if (!mounted) return;

      // 3. Abonelik (Subscription) Ekranına Yolla
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriptionScreen(
            cameras: widget.cameras,
            isFirstOffer: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ DİL DESTEĞİ TANIMLAMASI
    final l10n = AppLocalizations.of(context)!;

    // 📱 Platform kontrolü
    bool isAndroid = true;
    try {
      isAndroid = Platform.isAndroid;
    } catch (e) {
      isAndroid = true;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Arka Plan Süslemeleri
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ✅ withValues KULLANIMI (Yeni Standart)
                color: Colors.amber.withValues(alpha: 0.08),
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
                color: Colors.orange.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 50, color: Colors.amber),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      l10n.welcomeTitle, // ✅ "Hoş Geldin!"
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.welcomeSubtitle, // ✅ "Sihirli AR dünyasına katıl"
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 50),

                    if (_loading)
                      const CircularProgressIndicator(color: Colors.orange)
                    else ...[
                      // Platforma Özel Butonlar
                      if (isAndroid) ...[
                        _buildLoginBtn(
                          icon: Icons.g_mobiledata_rounded,
                          iconSize: 34,
                          text: l10n.googleLogin, // ✅ Google Dil Desteği
                          color: const Color(0xFFDB4437),
                          textColor: Colors.white,
                          onTap: () => _handleLogin("google"),
                        ),
                        const SizedBox(height: 16),
                        _buildLoginBtn(
                          icon: Icons.apple_rounded,
                          text: l10n.appleLogin, // ✅ Apple Dil Desteği
                          color: Colors.black,
                          textColor: Colors.white,
                          onTap: () => _handleLogin("apple"),
                        ),
                      ] else ...[
                        _buildLoginBtn(
                          icon: Icons.apple_rounded,
                          text: l10n.appleLogin,
                          color: Colors.black,
                          textColor: Colors.white,
                          onTap: () => _handleLogin("apple"),
                        ),
                        const SizedBox(height: 16),
                        _buildLoginBtn(
                          icon: Icons.g_mobiledata_rounded,
                          iconSize: 34,
                          text: l10n.googleLogin,
                          color: Colors.white,
                          textColor: Colors.black87,
                          borderColor: Colors.grey.shade300,
                          onTap: () => _handleLogin("google"),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // Ayırıcı
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Text(
                              l10n.or, // ✅ "Veya"
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Misafir Girişi
                      TextButton(
                        onPressed: () => _handleLogin("guest"),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          l10n.guestLogin, // ✅ "Misafir Olarak Başla"
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginBtn({
    required IconData icon,
    double iconSize = 24,
    required String text,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2), // ✅ withValues
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: iconSize),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
