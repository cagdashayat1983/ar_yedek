import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          l10n.helpTitle,
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- BÖLÜM 1: SESLİ ASİSTAN ---
          _sectionTitle(l10n.magicAssistant),
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mic_rounded,
                    color: Colors.blueAccent, size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.voiceCommands,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.blue.shade900)),
                      const SizedBox(height: 8),
                      Text(l10n.voiceCommandsDesc,
                          style: GoogleFonts.poppins(
                              color: Colors.blue.shade800, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(l10n.voiceCommandsList,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                              fontSize: 12,
                              height: 1.5)),
                    ],
                  ),
                )
              ],
            ),
          ),

          // --- BÖLÜM 2: ARAÇLAR ---
          _sectionTitle(l10n.toolsLabel),
          _infoCard(Icons.camera_alt, l10n.toolArMode, l10n.toolArModeDesc),
          _infoCard(Icons.lock, l10n.toolLock, l10n.toolLockDesc),
          _infoCard(Icons.opacity, l10n.toolOpacity, l10n.toolOpacityDesc),
          _infoCard(Icons.grid_on, l10n.toolGrid, l10n.toolGridDesc),
          _infoCard(Icons.flip, l10n.toolMirror, l10n.toolMirrorDesc),
          _infoCard(Icons.flash_on, l10n.toolFlash, l10n.toolFlashDesc),

          const SizedBox(height: 20),

          // --- BÖLÜM 3: İÇERİK ---
          _sectionTitle(l10n.contentTemplatesLabel),
          _infoCard(Icons.image_search_rounded, l10n.drawYourPhoto,
              l10n.originalDesc), // originalDesc galeri kullanımı içindir
          _infoCard(Icons.category_rounded, l10n.categoriesLabel,
              l10n.categoriesDesc),

          const SizedBox(height: 20),

          // --- BÖLÜM 4: XP ---
          _sectionTitle(l10n.progressXpLabel),
          _infoCard(
              Icons.stars_rounded, l10n.howToEarnXp, l10n.howToEarnXpDesc),
          _infoCard(Icons.trending_up, l10n.levelSystem, l10n.levelSystemDesc),

          const SizedBox(height: 20),

          // --- BÖLÜM 5: PRO ÜYELİK ---
          _sectionTitle(l10n.proTitle),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Colors.orange, size: 32),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.proBenefits,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.orange.shade900)),
                      const SizedBox(height: 5),
                      Text(l10n.proBenefitsList,
                          style: GoogleFonts.poppins(
                              color: Colors.orange.shade800, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 30),
          Center(
            child: Text(l10n.appVersion,
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400, fontSize: 12)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
    );
  }

  Widget _infoCard(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black87, size: 26),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 5),
                Text(desc,
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
