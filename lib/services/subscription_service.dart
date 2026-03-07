import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static Future<void> init() async {
    // Test aşamasında logları görmek için
    await Purchases.setLogLevel(LogLevel.debug);

    // 🍎 iOS ÇÖKME ENGELLEYİCİ
    if (Platform.isIOS) {
      debugPrint("iOS'ta abonelik sistemi şimdilik atlanıyor (Apple Key yok).");
      return;
    }

    // 🤖 Android için çalışmaya devam eder
    // ⚠️ NOT: Bu senin 'Test Store' anahtarın. Gerçek satış için RevenueCat'teki 'Google' anahtarını kullanmalısın.
    String apiKey = 'test_eBlwszDXXCqtZEBOiqkWtXKUpep';

    try {
      await Purchases.configure(PurchasesConfiguration(apiKey));
    } catch (e) {
      debugPrint("RevenueCat Başlatma Hatası: $e");
    }
  }

  /// 🔄 Satın Almaları Geri Yükle (Android için Hayati)
  static Future<bool> restorePurchases() async {
    if (Platform.isIOS) return false;

    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      // 'AR Draw Hayatify Pro' senin RevenueCat'teki Entitlement ID'n ile aynı olmalı!
      bool isActive =
          customerInfo.entitlements.all["AR Draw Hayatify Pro"]?.isActive ??
              false;
      return isActive;
    } catch (e) {
      debugPrint("Geri yükleme hatası: $e");
      return false;
    }
  }

  /// Kullanıcının aktif bir PRO aboneliği olup olmadığını kontrol eder.
  static Future<bool> isProUser() async {
    if (Platform.isIOS) return false;

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // ⚠️ DİKKAT: RevenueCat panelindeki Entitlement ID'nin tam olarak
      // "AR Draw Hayatify Pro" olduğundan emin ol (Boşluklara dikkat!)
      return customerInfo.entitlements.all["AR Draw Hayatify Pro"]?.isActive ??
          false;
    } catch (e) {
      debugPrint("Abonelik kontrolü hatası: $e");
      return false;
    }
  }

  /// Mevcut abonelik paketlerini getirmek için kullanılır.
  static Future<Offerings?> getOfferings() async {
    if (Platform.isIOS) return null;

    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint("Paket getirme hatası: $e");
      return null;
    }
  }
}
