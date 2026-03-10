import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ✅ HATA BURADAYDI, DÜZELTİLDİ

class AdService {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoading = false;

  // Google'ın resmi Test ID'leri (Asla ban yedirtmez)
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return '';
  }

  // Arka planda reklamı yükler ve hazırda bekletir
  static void loadRewardedAd() {
    if (_isAdLoading) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Ödüllü Reklam Yüklendi');
          _rewardedAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Ödüllü Reklam Yüklenemedi: $error');
          _rewardedAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  // Kullanıcıya reklamı gösterir
  static void showRewardedAd({
    required VoidCallback onReward,
    required VoidCallback onFailed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('Reklam henüz hazır değil.');
      onFailed(); // Reklam yoksa hata döndür
      loadRewardedAd(); // Yeniden yüklemeye çalış
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Kapatılınca hemen yenisini depola
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        onFailed();
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      debugPrint('🎉 KULLANICI ÖDÜLÜ KAZANDI!');
      onReward(); // Kullanıcı videoyu tam izledi, enerjiyi ver!
    });
  }
}
