import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static Future<void> init() async {
    // Test aşamasında logları görmek için
    await Purchases.setLogLevel(LogLevel.debug);

    // 🍎 iOS ÇÖKME ENGELLEYİCİ: Apple anahtarımız olmadığı için
    // iOS'ta RevenueCat'i başlatmadan direkt çıkış yapıyoruz.
    if (Platform.isIOS) {
      debugPrint("iOS'ta abonelik sistemi şimdilik atlanıyor (Apple Key yok).");
      return;
    }

    // 🤖 Android için çalışmaya devam eder
    String apiKey = 'test_eBlwszDXXCqtZEBOiqkWtXKUpep';

    try {
      await Purchases.configure(PurchasesConfiguration(apiKey));
    } catch (e) {
      debugPrint("RevenueCat Başlatma Hatası: $e");
    }
  }

  /// Kullanıcının aktif bir PRO aboneliği olup olmadığını kontrol eder.
  static Future<bool> isProUser() async {
    if (Platform.isIOS) return false; // iOS'ta şimdilik PRO kapalı

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all["AR Draw Hayatify Pro"]?.isActive ??
          false;
    } catch (e) {
      debugPrint("Abonelik kontrolü hatası: $e");
      return false;
    }
  }

  /// Mevcut abonelik paketlerini getirmek için kullanılır.
  static Future<Offerings?> getOfferings() async {
    if (Platform.isIOS) return null; // iOS'ta paket yok

    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint("Paket getirme hatası: $e");
      return null;
    }
  }
}
