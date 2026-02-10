import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HayatifyApp());
}

class HayatifyApp extends StatelessWidget {
  const HayatifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hayatify',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      home: const LoginScreen(),
    );
  }
}
