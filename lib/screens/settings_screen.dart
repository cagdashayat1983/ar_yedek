import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text("Ayarlar",
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          ListTile(
              leading: const Icon(Icons.language),
              title: const Text("Dil"),
              trailing: const Text("Türkçe")),
          ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text("Tema"),
              trailing: const Text("Aydınlık")),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title:
                const Text("Hesabı Sil", style: TextStyle(color: Colors.red)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
