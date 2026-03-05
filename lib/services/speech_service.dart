import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speech = SpeechToText();

  bool _isAvailable = false;
  bool _isListening = false;
  bool _starting = false;
  bool _wantListen = false;

  Function(String)? _onFinalResult;

  final List<String> _preferredLocales = const [
    "tr_TR",
    "tr-TR",
    "en_US",
    "en-US"
  ];
  String? _activeLocale;

  Timer? _restartTimer;

  Future<bool> initSpeech() async {
    if (_isAvailable) return true;

    try {
      _isAvailable = await _speech.initialize(
        onError: (val) async {
          debugPrint('❌ [SPEECH] Error: ${val.errorMsg}');

          _isListening = false;
          // 🧹 ANDROID'İ KENDİNE GETİREN TOKAT: Hata anında motoru zorla sustur ve temizle
          await _safeCancel();

          // ⏳ 900ms çok hızlıydı, motorun nefes alması için 1500ms (1.5 sn) bekliyoruz
          _scheduleRestart(delayMs: 1500);
        },
        onStatus: (val) {
          debugPrint('ℹ️ [SPEECH] Status: $val');

          if (val == "done" || val == "notListening") {
            _isListening = false;
            // Kapanma durumunda da 1.5 saniye mola veriyoruz
            _scheduleRestart(delayMs: 1500);
          }
        },
      );

      if (!_isAvailable) return false;

      final locales = await _speech.locales();
      final localeIds = locales.map((e) => e.localeId).toSet();

      _activeLocale = _preferredLocales.firstWhere(
        (id) => localeIds.contains(id),
        orElse: () => (locales.isNotEmpty ? locales.first.localeId : "tr_TR"),
      );

      debugPrint("✅ [SPEECH] Active locale: $_activeLocale");
      return true;
    } catch (e) {
      debugPrint('❌ [SPEECH] Init exception: $e');
      return false;
    }
  }

  Future<void> startListening(Function(String) onFinalResult) async {
    _onFinalResult = onFinalResult;
    _wantListen = true;

    if (!_isAvailable) {
      final ok = await initSpeech();
      if (!ok) return;
    }

    if (_starting) return;
    if (_speech.isListening) return;
    if (_isListening) return;

    _restartTimer?.cancel();
    _starting = true;

    // 🧹 KRİTİK DOKUNUŞ: Başlamadan önce önceki kalıntıları kesin olarak temizle
    await _safeCancel();
    await Future.delayed(const Duration(milliseconds: 300));

    _isListening = true;

    try {
      await _speech.listen(
        localeId: _activeLocale,
        listenMode: ListenMode
            .dictation, // confirmation yerine dictation sürekli dinleme için daha iyidir
        cancelOnError: false,
        partialResults: true,
        pauseFor: const Duration(
            seconds: 4), // 2 saniye yerine 4 saniye sessizliğe izin ver
        listenFor: const Duration(
            seconds: 15), // Tek seferde daha uzun dinle (Motoru yormamak için)
        onResult: (result) {
          // O meşhur DARBOĞAZI kaldırdık, duyduğu an fırlatacak
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            _onFinalResult?.call(text);
          }
        },
      );
    } catch (e) {
      debugPrint('❌ [SPEECH] listen exception: $e');
      _isListening = false;
      await _safeCancel();
      _scheduleRestart(delayMs: 1500);
    } finally {
      _starting = false;
    }
  }

  void _scheduleRestart({int delayMs = 1500}) {
    if (!_isAvailable) return;
    if (!_wantListen) return;
    if (_onFinalResult == null) return;

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!_speech.isListening && !_starting) {
        // Döngü tetiklenirken de temizlik yapalım
        await _safeCancel();
        startListening(_onFinalResult!);
      }
    });
  }

  Future<void> stopListening() async {
    _wantListen = false;
    _restartTimer?.cancel();
    _restartTimer = null;

    _isListening = false;
    _onFinalResult = null;

    await _safeCancel();
  }

  Future<void> _safeCancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
