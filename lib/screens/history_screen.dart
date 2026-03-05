// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart'; // ✅ Dil desteği için import

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('drawing_history') ?? [];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // ✅ l10n tanımlandı

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.historyTitle, // ✅ Localized
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyState(l10n) // ✅ l10n gönderildi
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    return _buildHistoryItem(
                        _history[index], l10n); // ✅ l10n gönderildi
                  },
                ),
    );
  }

  // EĞER GEÇMİŞ BOŞSA GÖSTERİLECEK EKRAN
  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.brush_outlined,
              size: 80,
              color: Colors.grey.withValues(alpha: 0.2)), // ✅ withValues
          const SizedBox(height: 20),
          Text(
            l10n.noHistoryDesc, // ✅ Localized
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // GEÇMİŞ ÖĞESİ TASARIMI
  Widget _buildHistoryItem(String title, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05), // ✅ withValues
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: Colors.grey.withValues(alpha: 0.1)), // ✅ withValues
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                Text(
                  l10n.historyCompleted, // ✅ Localized
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.image_outlined, color: Colors.blue),
        ],
      ),
    );
  }
}
