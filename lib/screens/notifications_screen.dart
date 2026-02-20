import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _dailyReminder = true;
  bool _newTemplates = true;
  bool _updates = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text("Bildirimler",
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _switchTile("Günlük İlham", "Her sabah çizim hatırlatması al.",
                _dailyReminder, (v) => setState(() => _dailyReminder = v)),
            _switchTile(
                "Yeni Şablonlar",
                "Yeni çizimler eklendiğinde haber ver.",
                _newTemplates,
                (v) => setState(() => _newTemplates = v)),
            _switchTile(
                "Uygulama Güncellemeleri",
                "Yeni özelliklerden haberdar ol.",
                _updates,
                (v) => setState(() => _updates = v)),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: SwitchListTile(
        activeColor: Colors.black,
        title: Text(title,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
