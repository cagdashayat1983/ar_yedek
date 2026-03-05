import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static Future<void> init() async {
    // Test aşamasında logları görmek için
    await Purchases.setLogLevel(LogLevel.debug);

    String apiKey;
    if (Platform.isIOS) {
      apiKey = 'test_eBlwszDXXCqtZEBOiqkWtXKUpep';
    } else {
      apiKey = 'test_eBlwszDXXCqtZEBOiqkWtXKUpep';
    }

    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Kullanıcının aktif bir PRO aboneliği olup olmadığını kontrol eder.
  /// Uygulama içindeki kilitleri açmak için bu metodu kullanabilirsin.
  static Future<bool> isProUser() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // "AR Draw Hayatify Pro" ifadesi RevenueCat panelindeki Entitlement ID ile birebir aynı olmalıdır.
      return customerInfo.entitlements.all["AR Draw Hayatify Pro"]?.isActive ??
          false;
    } catch (e) {
      debugPrint("Abonelik kontrolü hatası: $e");
      return false;
    }
  }

  /// Mevcut abonelik paketlerini getirmek için kullanılır.
  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint("Paket getirme hatası: $e");
      return null;
    }
  }
}
