import 'dart:io'; // ✅ SSL hatasını çözmek için şart!
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ✅ Proje yolların:
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/splash_screen.dart';

// 🛠️ SSL/TLS Sürüm Hatalarını Esneten Güçlendirilmiş Sınıf
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // ✅ Hatalı olan kısmı bu şekilde ayırarak düzelttik:
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    client.connectionTimeout = const Duration(seconds: 15);

    return client;
  }
}

void main() {
  // 1. ✅ Her şeyden önce SSL Override ayarını aktif et
  HttpOverrides.global = MyHttpOverrides();

  // 2. Flutter motorunu hazırla
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // 3. Native Splash ekranını hazırla
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Performans uyarısını 'const' ekleyerek çözdük
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hayatify AR Drawing',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'),
        Locale('tr'),
      ],
      home: SplashScreen(),
    );
  }
}
