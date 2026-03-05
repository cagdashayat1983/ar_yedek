// lib/screens/about_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart'; // ✅ Import eklendi

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // ✅ l10n Tanımlandı

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          l10n.aboutUs, // ✅ Localized
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- LOGO & UYGULAMA İSMİ ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15), // ✅ withValues
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 60, color: Colors.amber),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.appTitle, // ✅ Localized
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.aboutSlogan, // ✅ Localized
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 30),

            // --- HİKAYEMİZ ---
            _buildSectionHeader(Icons.auto_stories_rounded, l10n.ourStoryTitle),
            const SizedBox(height: 12),
            Text(
              l10n.ourStoryDesc, // ✅ Localized
              textAlign: TextAlign.justify,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // --- MİSYONUMUZ ---
            _buildSectionHeader(Icons.visibility_rounded, l10n.ourMissionTitle),
            const SizedBox(height: 12),
            Text(
              l10n.ourMissionDesc, // ✅ Localized
              textAlign: TextAlign.justify,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 30),

            // --- İLETİŞİM & LİNKLER ---
            _buildSectionHeader(
                Icons.connect_without_contact_rounded, l10n.stayConnected),
            const SizedBox(height: 16),
            _buildLinkButton(Icons.language_rounded, l10n.visitWebsite, () {}),
            const SizedBox(height: 10),
            _buildLinkButton(
                Icons.camera_alt_rounded, l10n.followInstagram, () {}),
            const SizedBox(height: 10),
            _buildLinkButton(Icons.mail_rounded, l10n.contactSupport, () {}),

            const SizedBox(height: 40),

            // --- ALT BİLGİ (FOOTER) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFooterLink(l10n.privacyPolicy, () {}),
                Text(" • ", style: TextStyle(color: Colors.grey.shade400)),
                _buildFooterLink(l10n.termsOfUse, () {}),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Made with ❤️ & Flutter",
              style: GoogleFonts.poppins(
                color: Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkButton(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.black26, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.grey.shade500,
          fontSize: 11,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
