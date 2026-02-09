import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Ses için gerekli
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MainMenu(),
  ));
}

// --- 1. GİRİŞ EKRANI ---
class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("WORD",
                style: GoogleFonts.monoton(
                    fontSize: 60, color: Colors.greenAccent)),
            Text("RAIN",
                style: GoogleFonts.monoton(
                    fontSize: 60, color: Colors.blueAccent)),
            const SizedBox(height: 50),
            _menuButton(context, "HAYATTA KAL (TEK)", Colors.green, true),
            const SizedBox(height: 20),
            _menuButton(context, "BOT İLE YARIŞ", Colors.redAccent, false),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(
      BuildContext context, String text, Color color, bool isSolo) {
    return SizedBox(
      width: 280,
      height: 60,
      child: ElevatedButton(
        onPressed: () {
          // Oyuna girerken hafif bir titreşim verelim
          HapticFeedback.lightImpact();
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => WordRainGame(isSoloMode: isSolo)));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 10,
        ),
        child: Text(text,
            style: GoogleFonts.vt323(fontSize: 24, color: Colors.white)),
      ),
    );
  }
}

// --- 2. OYUN EKRANI ---
class WordRainGame extends StatefulWidget {
  final bool isSoloMode;
  const WordRainGame({super.key, required this.isSoloMode});

  @override
  State<WordRainGame> createState() => _WordRainGameState();
}

class _WordRainGameState extends State<WordRainGame> {
  // --- GENİŞLETİLMİŞ DATA (KELİME HAVUZU) ---
  final List<String> kelimeHavuzu = [
    // Kısa Kelimeler
    "KOD", "RAM", "CPU", "GPU", "BOT", "BUG", "NET", "API", "APP", "IOS", "MAC",
    "GIT", "RUN",
    // Orta Kelimeler
    "DATA", "WIFI", "JAVA", "DART", "TEST", "LOOP", "VOID", "MAIN", "USER",
    "HOST", "PING",
    "NODE", "RUBY", "PERL", "BASH", "ROOT", "SUDO", "LISP", "RUST", "VIEW",
    "PATH", "FILE",
    // Uzun Kelimeler
    "FLUTTER", "PYTHON", "ANDROID", "GOOGLE", "SERVER", "CLIENT", "SOCKET",
    "SYSTEM", "KERNEL",
    "SCRIPT", "DOCKER", "CLOUD", "AMAZON", "ORACLE", "ACCESS", "MEMORY",
    "OUTPUT", "INPUT",
    "STRING", "NUMBER", "OBJECT", "WIDGET", "LAYOUT", "DESIGN", "GITHUB",
    "GOLANG", "KOTLIN"
  ];

  final int hedefSkor = 500;

  // --- DEĞİŞKENLER ---
  List<WordObject> ekrandakiKelimeler = [];
  List<Particle> parcalanmaEfekti = [];

  int skorSen = 0;
  int skorRakip = 0;
  int can = 3;

  bool oyunBittiMi = false;
  String sonucMesaji = "";

  // Zorluk Ayarları
  double zorlukSeviyesi = 1.0;
  int spawnSayaci = 0; // Kelime üretme zamanlayıcısı
  int spawnLimiti = 60; // Ne kadar sürede bir kelime gelecek (Başlangıç: Yavaş)

  Timer? gameLoop;
  Timer? rakipLoop;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Random _random = Random();

  double gameAreaWidth = 0;
  double gameAreaHeight = 0;

  @override
  void initState() {
    super.initState();
    baslat();
  }

  @override
  void dispose() {
    gameLoop?.cancel();
    rakipLoop?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void baslat() {
    setState(() {
      skorSen = 0;
      skorRakip = 0;
      can = 3;
      zorlukSeviyesi = 1.0;
      spawnLimiti =
          50; // Başlangıçta kelimeler arası bekleme süresi (frame cinsinden)
      oyunBittiMi = false;
      ekrandakiKelimeler.clear();
      parcalanmaEfekti.clear();
      _controller.clear();
    });

    gameLoop = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      oyunDongusu();
    });

    if (!widget.isSoloMode) {
      rakipLoop = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
        if (!oyunBittiMi) {
          setState(() {
            skorRakip += _random.nextInt(15) + 5;
            kontrolEtBitis();
          });
        }
      });
    }
  }

  void oyunDongusu() {
    if (!mounted || oyunBittiMi) {
      gameLoop?.cancel();
      rakipLoop?.cancel();
      return;
    }

    setState(() {
      // --- 1. KELİME ÜRETME (DAHA DENGELİ) ---
      spawnSayaci++;

      // Süre dolduysa yeni kelime üret
      if (spawnSayaci > spawnLimiti) {
        _kelimeEkle();
        spawnSayaci = 0; // Sayacı sıfırla

        // Zorluk seviyesine göre bir sonraki kelime daha hızlı gelebilir
        // Ama asla 15 frame'den (yarım saniye) daha sık gelmesin
        if (spawnLimiti > 20) {
          // Rastgele küçük bir varyasyon ekle ki robotik olmasın
          spawnLimiti = (50 / zorlukSeviyesi).toInt() + _random.nextInt(10);
        }
      }

      // --- 2. HAREKET ---
      for (int i = ekrandakiKelimeler.length - 1; i >= 0; i--) {
        var kelime = ekrandakiKelimeler[i];
        kelime.y += kelime.hiz;

        // Kelime Kaçarsa
        if (gameAreaHeight > 0 && kelime.y > gameAreaHeight - 40) {
          ekrandakiKelimeler.removeAt(i);
          if (widget.isSoloMode) {
            can--;
            // Titreşim ver (Hata hissi)
            HapticFeedback.heavyImpact();
            if (can <= 0) {
              oyunBittiMi = true;
              sonucMesaji = "OYUN BİTTİ\nSKOR: $skorSen";
            }
          }
        }
      }

      // Parçacık Hareketi
      for (int i = parcalanmaEfekti.length - 1; i >= 0; i--) {
        var p = parcalanmaEfekti[i];
        p.x += p.vx;
        p.y += p.vy;
        p.omur -= 0.05;
        p.vy += 0.5;
        if (p.omur <= 0) parcalanmaEfekti.removeAt(i);
      }
    });
  }

  void _kelimeEkle() {
    if (gameAreaWidth == 0) return;

    String secilenMetin = kelimeHavuzu[_random.nextInt(kelimeHavuzu.length)];

    // ÇARPIŞMA ÖNLEME:
    // Rastgele bir yer seç ama eğer orada başka kelime varsa tekrar dene
    double xKonum = 10.0;
    bool uygunKonumBulundu = false;
    int denemeSayisi = 0;

    while (!uygunKonumBulundu && denemeSayisi < 10) {
      xKonum = _random.nextDouble() * (gameAreaWidth - 120) + 10;
      uygunKonumBulundu = true;

      // Diğer kelimelerle çakışıyor mu? (Sadece en üsttekilere bakmak yeterli)
      for (var k in ekrandakiKelimeler) {
        if (k.y < 100 && (k.x - xKonum).abs() < 100) {
          uygunKonumBulundu = false; // Çok yakın, başka yer dene
          break;
        }
      }
      denemeSayisi++;
    }

    // Başlangıç hızı daha düşük (1.5), zorluk arttıkça hızlanır
    double hiz = (1.5 + _random.nextDouble()) * zorlukSeviyesi;

    ekrandakiKelimeler.add(WordObject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: secilenMetin,
      x: xKonum,
      y: -60, // Ekranın biraz daha üstünden başlasın
      hiz: hiz,
      renk: Colors.primaries[_random.nextInt(Colors.primaries.length)],
    ));
  }

  void _patlamaOlustur(double x, double y, Color renk) {
    for (int i = 0; i < 15; i++) {
      parcalanmaEfekti.add(Particle(
          x: x + 20,
          y: y + 10,
          vx: (_random.nextDouble() - 0.5) * 10,
          vy: (_random.nextDouble() - 0.5) * 10,
          renk: renk,
          omur: 1.0));
    }
  }

  void _oyuncuKelimeVurdu(String yazilan) {
    if (oyunBittiMi) return;

    // Her tuş basımında 'tık' sesi (Geri bildirim)
    SystemSound.play(SystemSoundType.click);

    String giris = yazilan.toUpperCase().trim();
    int index = ekrandakiKelimeler.indexWhere((k) => k.text == giris);

    if (index != -1) {
      var vurulanKelime = ekrandakiKelimeler[index];
      setState(() {
        // Vurma sesi yerine hafif titreşim
        HapticFeedback.mediumImpact();

        _patlamaOlustur(vurulanKelime.x, vurulanKelime.y, vurulanKelime.renk);
        ekrandakiKelimeler.removeAt(index);

        int puan = widget.isSoloMode ? 10 : 25;
        skorSen += puan;

        // ZORLUK ARTIŞI (Daha kontrollü)
        // Her 50 puanda oyun %5 hızlanır
        if (widget.isSoloMode && skorSen % 50 == 0) {
          zorlukSeviyesi += 0.05;
        }

        _controller.clear();
        kontrolEtBitis();
      });
    }
  }

  void kontrolEtBitis() {
    if (!widget.isSoloMode) {
      if (skorSen >= hedefSkor) {
        oyunBittiMi = true;
        sonucMesaji = "KAZANDIN! 🏆";
      } else if (skorRakip >= hedefSkor) {
        oyunBittiMi = true;
        sonucMesaji = "KAYBETTİN... 💀";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: widget.isSoloMode ? 60 : 80,
        title: widget.isSoloMode ? _buildSoloAppBar() : _buildVsAppBar(),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                gameAreaWidth = constraints.maxWidth;
                gameAreaHeight = constraints.maxHeight;

                return Stack(
                  children: [
                    ...ekrandakiKelimeler.map((kelime) {
                      return Positioned(
                        left: kelime.x,
                        top: kelime.y,
                        child: Text(kelime.text,
                            style: GoogleFonts.vt323(
                                color: kelime.renk,
                                fontSize: 35,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  BoxShadow(
                                      color: kelime.renk.withOpacity(0.8),
                                      blurRadius: 15)
                                ])),
                      );
                    }).toList(),
                    ...parcalanmaEfekti
                        .map((p) => Positioned(
                            left: p.x,
                            top: p.y,
                            child: Opacity(
                                opacity: p.omur < 0 ? 0 : p.omur,
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: p.renk,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: p.renk, blurRadius: 5)
                                        ])))))
                        .toList(),
                    if (oyunBittiMi)
                      Container(
                        color: Colors.black87,
                        width: double.infinity,
                        height: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(sonucMesaji,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.pressStart2p(
                                    color: Colors.white, fontSize: 24)),
                            const SizedBox(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey),
                                    child: const Icon(Icons.home, size: 30)),
                                const SizedBox(width: 20),
                                ElevatedButton(
                                    onPressed: baslat,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green),
                                    child: const Icon(Icons.refresh, size: 30)),
                              ],
                            )
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: Color(0xFF111111),
                border: Border(
                    top: BorderSide(color: Colors.blueAccent, width: 2))),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              enabled: !oyunBittiMi,
              style: GoogleFonts.vt323(color: Colors.white, fontSize: 30),
              decoration: const InputDecoration(
                  hintText: ">> HEDEFİ GİR...",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 20),
                  border: InputBorder.none,
                  isDense: true),
              onChanged: (value) => _oyuncuKelimeVurdu(value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoloAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
            children: List.generate(
                3,
                (i) => Icon(i < can ? Icons.favorite : Icons.favorite_border,
                    color: Colors.redAccent))),
        Text("SKOR: $skorSen",
            style: GoogleFonts.pressStart2p(
                color: Colors.greenAccent, fontSize: 16)),
        Text("HIZ x${zorlukSeviyesi.toStringAsFixed(1)}",
            style: GoogleFonts.vt323(color: Colors.blueAccent, fontSize: 24)),
      ],
    );
  }

  Widget _buildVsAppBar() {
    return Column(
      children: [
        Text("HEDEF: $hedefSkor",
            style: GoogleFonts.vt323(color: Colors.grey, fontSize: 18)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: Column(children: [
              Text("SEN: $skorSen",
                  style: GoogleFonts.pressStart2p(
                      color: Colors.greenAccent, fontSize: 10)),
              LinearProgressIndicator(
                  value: skorSen / hedefSkor,
                  color: Colors.greenAccent,
                  backgroundColor: Colors.greenAccent.withOpacity(0.2),
                  minHeight: 8)
            ])),
            const SizedBox(width: 15),
            const Text("VS",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 15),
            Expanded(
                child: Column(children: [
              Text("BOT: $skorRakip",
                  style: GoogleFonts.pressStart2p(
                      color: Colors.redAccent, fontSize: 10)),
              LinearProgressIndicator(
                  value: skorRakip / hedefSkor,
                  color: Colors.redAccent,
                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                  minHeight: 8)
            ])),
          ],
        ),
      ],
    );
  }
}

class WordObject {
  String id;
  String text;
  double x;
  double y;
  double hiz;
  Color renk;
  WordObject(
      {required this.id,
      required this.text,
      required this.x,
      required this.y,
      required this.hiz,
      required this.renk});
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double omur;
  Color renk;
  Particle(
      {required this.x,
      required this.y,
      required this.vx,
      required this.vy,
      required this.omur,
      required this.renk});
}
