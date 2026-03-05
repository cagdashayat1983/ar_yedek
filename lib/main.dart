import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ✅ Proje adın 'flutter_application_1' olduğu için yollar bu şekilde:
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/splash_screen.dart';

void main() {
  // 1. Flutter motorunu hazırla
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // 2. Perdeyi (Native Splash) tut, biz kaldırana kadar bekle
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hayatify AR Drawing',

      // ✅ Dil Desteği
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('tr'),
      ],

      // ✅ SplashScreen artık parametre istemiyor, akıllı hale geldi.
      home: const SplashScreen(),
    );
  }
}
