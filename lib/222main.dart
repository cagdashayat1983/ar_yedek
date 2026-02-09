import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0F0F16),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RetroBlastGame(),
  ));
}

// --- RENK SİSTEMİ ---
final List<Color> shapeColors = [
  const Color(0xFFD32F2F), // Kırmızı
  const Color(0xFFFFB300), // Sarı
  const Color(0xFF388E3C), // Yeşil
  const Color(0xFF1976D2), // Mavi
  const Color(0xFFE64A19), // Turuncu
  const Color(0xFF512DA8), // Mor
];

// SimpleCubePainter (CANLI + KABARTMALI)
class SimpleCubePainter extends CustomPainter {
  final Color color;
  final bool isGhost;
  final bool isChest;

  SimpleCubePainter({
    required this.color,
    this.isGhost = false,
    this.isChest = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    // GHOST PREVIEW
    if (isGhost) {
      final fillPaint = Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rRect, fillPaint);

      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      Path path = Path()..addRRect(rRect);
      Path dashPath = Path();
      double dashWidth = 5.0;
      double dashSpace = 3.0;
      double distance = 0.0;

      for (ui.PathMetric pathMetric in path.computeMetrics()) {
        while (distance < pathMetric.length) {
          dashPath.addPath(
              pathMetric.extractPath(distance, distance + dashWidth),
              Offset.zero);
          distance += dashWidth + dashSpace;
        }
      }
      canvas.drawPath(dashPath, borderPaint);
      return;
    }

    // === CANLI KÜP TASARIMI ===

    // 1. ALT GÖLGE
    final shadowPath = Path()..addRRect(rRect.shift(const Offset(5, 5)));
    canvas.drawShadow(
      shadowPath,
      Colors.black.withOpacity(0.5),
      8.0,
      false,
    );

    // 2. RENK PALETI
    final HSLColor hslColor = HSLColor.fromColor(color);

    // Saturation boost
    final boostedHsl =
        hslColor.withSaturation((hslColor.saturation * 1.2).clamp(0.0, 1.0));

    final Color topColor = boostedHsl
        .withLightness((boostedHsl.lightness + 0.25).clamp(0.0, 0.95))
        .toColor();
    final Color midColor = boostedHsl.toColor();
    final Color bottomColor = boostedHsl
        .withLightness((boostedHsl.lightness - 0.15).clamp(0.05, 1.0))
        .toColor();

    // 3. ANA GÖVDE
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [topColor, midColor, bottomColor],
        [0.0, 0.5, 1.0],
      );

    canvas.drawRRect(rRect, bodyPaint);

    // 4. İÇ PARLAMA
    final glossPath = Path()
      ..moveTo(rect.left + 6, rect.top)
      ..lineTo(rect.right - 6, rect.top)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top + size.height * 0.35,
        rect.left + 6,
        rect.top + size.height * 0.3,
      )
      ..close();

    final glossPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.top + size.height * 0.3),
        [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.0),
        ],
      );
    canvas.drawPath(glossPath, glossPaint);

    // 5. KABARTMA EFEKTİ
    final bevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Üst kenar
    bevelPaint.color = Colors.white.withOpacity(0.6);
    canvas.drawLine(
      Offset(rect.left + 6, rect.top + 1),
      Offset(rect.right - 6, rect.top + 1),
      bevelPaint,
    );

    // Sol kenar
    bevelPaint.color = Colors.white.withOpacity(0.25);
    canvas.drawLine(
      Offset(rect.left + 1, rect.top + 6),
      Offset(rect.left + 1, rect.bottom - 6),
      bevelPaint,
    );

    // Alt kenar
    bevelPaint.color = Colors.black.withOpacity(0.4);
    canvas.drawLine(
      Offset(rect.left + 6, rect.bottom - 1),
      Offset(rect.right - 6, rect.bottom - 1),
      bevelPaint,
    );

    // Sağ kenar
    bevelPaint.color = Colors.black.withOpacity(0.5);
    canvas.drawLine(
      Offset(rect.right - 1, rect.top + 6),
      Offset(rect.right - 1, rect.bottom - 6),
      bevelPaint,
    );

    // 6. DIŞ BORDER
    final mainBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rRect, mainBorderPaint);

    // 7. HIGHLIGHT NOKTALAR
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawCircle(
      Offset(rect.left + 8, rect.top + 8),
      2.5,
      highlightPaint,
    );

    highlightPaint.color = Colors.white.withOpacity(0.5);
    canvas.drawCircle(
      Offset(rect.right - 10, rect.top + 10),
      1.5,
      highlightPaint,
    );

    // 8. HAZİNE SANDIĞI ÖZEL EFEKT
    if (isChest) {
      final chestBorderPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawRRect(rRect.deflate(5), chestBorderPaint);

      final shimmerPaint = Paint()
        ..color = const Color(0xFFFFE082)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(
        Offset(rect.center.dx - 8, rect.center.dy - 8),
        2,
        shimmerPaint,
      );
      canvas.drawCircle(
        Offset(rect.center.dx + 8, rect.center.dy + 8),
        1.5,
        shimmerPaint,
      );
    }

    // 9. ALT KÖŞE DERINLIK GÖLGESI
    final innerShadowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(rect.right - 8, rect.bottom - 8),
        size.width * 0.4,
        [
          Colors.black.withOpacity(0.3),
          Colors.transparent,
        ],
      );
    canvas.drawRRect(rRect, innerShadowPaint);
  }

  @override
  bool shouldRepaint(covariant SimpleCubePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isGhost != isGhost ||
        oldDelegate.isChest != isChest;
  }
}

// --- ARKA PLAN IZGARASI ---
class RetroGridPainter extends CustomPainter {
  final double scrollValue;
  final Color gridColor = const Color(0xFF1a1a2e);

  RetroGridPainter(this.scrollValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withOpacity(0.15)
      ..strokeWidth = 1.5;

    final horizonY = size.height * 0.3;
    final centerX = size.width / 2;

    for (int i = -8; i <= 8; i++) {
      double startX = centerX + i * size.width * 0.18;
      double endX = centerX + i * size.width * 0.05;
      canvas.drawLine(
          Offset(startX, size.height), Offset(endX, horizonY), paint);
    }

    for (double i = 0; i < 1.0; i += 0.08) {
      double t = (i + scrollValue) % 1.0;
      double y = horizonY + (size.height - horizonY) * (t * t);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY),
        paint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant RetroGridPainter oldDelegate) =>
      oldDelegate.scrollValue != scrollValue;
}

// --- VERİ YAPILARI ---
class CellData {
  final Color color;
  final bool isChest;

  CellData({required this.color, this.isChest = false});

  Map<String, dynamic> toJson() => {
        'color': color.value,
        'isChest': isChest,
      };

  factory CellData.fromJson(Map<String, dynamic> json) {
    return CellData(
      color: Color(json['color']),
      isChest: json['isChest'] ?? false,
    );
  }
}

class ShapeData {
  List<List<int>> points;
  final Color color;
  bool isUsed;

  ShapeData({
    required this.points,
    required this.color,
    this.isUsed = false,
  });

  void rotate() {
    List<List<int>> newPoints = points.map((p) => [-p[1], p[0]]).toList();
    int minX = newPoints.map((p) => p[0]).reduce(math.min);
    int minY = newPoints.map((p) => p[1]).reduce(math.min);
    points = newPoints.map((p) => [p[0] - minX, p[1] - minY]).toList();
  }

  Map<String, dynamic> toJson() => {
        'points': points,
        'color': color.value,
        'isUsed': isUsed,
      };

  factory ShapeData.fromJson(Map<String, dynamic> json) {
    List<List<int>> p = (json['points'] as List)
        .map((e) => (e as List).map((i) => i as int).toList())
        .toList();
    return ShapeData(
      points: p,
      color: Color(json['color']),
      isUsed: json['isUsed'],
    );
  }
}

// --- GÜNCELLENMİŞ PARTİKÜL SİSTEMİ ---

enum ParticleType { debris, spark, ring }

class Particle {
  double x, y, vx, vy, opacity, size;
  Color color;
  bool isIntroParticle;
  double rotation;
  double rotationSpeed;

  // Yeni özellikler
  ParticleType type;
  double life; // Ömür (0.0 - 1.0 arası)
  double decayRate; // Ne kadar hızlı yok olacağı

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    this.opacity = 1.0,
    this.size = 10.0,
    this.isIntroParticle = false,
    this.rotation = 0.0,
    this.rotationSpeed = 0.0,
    this.type = ParticleType.debris,
    this.life = 1.0,
    this.decayRate = 0.02,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()..color = p.color.withOpacity(p.opacity * p.life);

      canvas.save();
      canvas.translate(p.x, p.y);

      if (p.type == ParticleType.spark) {
        // Kıvılcımlar (Daha parlak, dairesel)
        paint.blendMode = BlendMode.srcOver;
        canvas.drawCircle(Offset.zero, p.size, paint);

        // Parlama efekti için dış halka
        final glowPaint = Paint()
          ..color = p.color.withOpacity(p.opacity * 0.5 * p.life)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(Offset.zero, p.size * 2, glowPaint);
      } else if (p.type == ParticleType.debris) {
        // Blok parçaları (Dönen kareler)
        canvas.rotate(p.rotation);

        // Hafif gölgeli parça
        final rRect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            const Radius.circular(2));

        canvas.drawRRect(rRect, paint);
      } else if (p.type == ParticleType.ring) {
        // Genişleyen halka efekti (Şok dalgası)
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.size * 0.2
          ..color = p.color.withOpacity(p.opacity * p.life);
        canvas.drawCircle(Offset.zero, p.size, ringPaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

BoxDecoration getEmptySlotDecoration() {
  return BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: const Color(0xFF1a1a2e),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(2, 2),
            blurRadius: 3,
            spreadRadius: -1),
      ],
      border: Border.all(color: Colors.white.withOpacity(0.05), width: 1));
}

// --- ŞEKİL HAVUZU ---
final Map<String, List<List<int>>> allShapes = {
  'ikili_yatay': [
    [0, 0],
    [1, 0]
  ],
  'ikili_dikey': [
    [0, 0],
    [0, 1]
  ],
  'uclu_yatay': [
    [0, 0],
    [1, 0],
    [2, 0]
  ],
  'uclu_dikey': [
    [0, 0],
    [0, 1],
    [0, 2]
  ],
  'kare_kucuk': [
    [0, 0],
    [1, 0],
    [0, 1],
    [1, 1]
  ],
  'merdiven_2': [
    [0, 1],
    [1, 1],
    [1, 0],
    [2, 0]
  ],
  'L_normal': [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2]
  ],
  'L_ters': [
    [1, 0],
    [1, 1],
    [1, 2],
    [0, 2]
  ],
  'J_normal': [
    [1, 0],
    [1, 1],
    [1, 2],
    [0, 0]
  ],
  'T_sekli': [
    [0, 0],
    [1, 0],
    [2, 0],
    [1, 1]
  ],
  'Z_sekli': [
    [0, 0],
    [1, 0],
    [1, 1],
    [2, 1]
  ],
  'S_sekli': [
    [1, 0],
    [2, 0],
    [0, 1],
    [1, 1]
  ],
  'dortlu_yatay': [
    [0, 0],
    [1, 0],
    [2, 0],
    [3, 0]
  ],
  'dortlu_dikey': [
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 3]
  ],
  'besli_yatay': [
    [0, 0],
    [1, 0],
    [2, 0],
    [3, 0],
    [4, 0]
  ],
  'besli_dikey': [
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 3],
    [0, 4]
  ],
  'kare_buyuk': [
    [0, 0],
    [1, 0],
    [2, 0],
    [0, 1],
    [1, 1],
    [2, 1],
    [0, 2],
    [1, 2],
    [2, 2]
  ],
  'arti_sekli': [
    [1, 0],
    [0, 1],
    [1, 1],
    [2, 1],
    [1, 2]
  ],
  'L_buyuk': [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
    [2, 2]
  ],
  'U_sekli': [
    [0, 0],
    [2, 0],
    [0, 1],
    [2, 1],
    [0, 2],
    [1, 2],
    [2, 2]
  ],
  'kose_buyuk': [
    [0, 0],
    [1, 0],
    [2, 0],
    [0, 1],
    [0, 2]
  ],
  'tekli': [
    [0, 0]
  ],
};

final List<String> easyShapes = ['ikili_yatay', 'ikili_dikey'];
final List<String> mediumShapes = [
  'uclu_yatay',
  'uclu_dikey',
  'kare_kucuk',
  'merdiven_2'
];
final List<String> hardShapes = [
  'L_normal',
  'L_ters',
  'J_normal',
  'T_sekli',
  'Z_sekli',
  'S_sekli',
  'dortlu_yatay',
  'dortlu_dikey'
];
final List<String> expertShapes = [
  'besli_yatay',
  'besli_dikey',
  'kare_buyuk',
  'arti_sekli',
  'L_buyuk',
  'U_sekli',
  'kose_buyuk'
];

// --- OYUN EKRANI ---
class RetroBlastGame extends StatefulWidget {
  const RetroBlastGame({super.key});
  @override
  State<RetroBlastGame> createState() => _RetroBlastGameState();
}

class _RetroBlastGameState extends State<RetroBlastGame>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey(); // STACK KEY EKLENDİ
  int rowSize = 8;
  late List<CellData?> grid;
  int score = 0;
  int displayScore = 0;
  int bestScore = 0;
  int coins = 0;
  int displayCoins = 0;

  int currentBlocksPopped = 0;
  int currentRowsCleared = 0;
  int currentColsCleared = 0;
  int currentMaxCombo = 0;
  int currentCoinsEarned = 0;
  Stopwatch gameStopwatch = Stopwatch();

  int statsTotalGames = 0;
  int statsTotalBlocks = 0;
  int statsTotalRows = 0;
  int statsTotalCols = 0;
  int statsTotalTimeSeconds = 0;
  int statsTotalScoreSum = 0;
  int statsHighestCombo = 0;

  List<ShapeData> availableShapes = [];
  double cellSize = 0;
  List<int> previewIndices = [];
  Color? previewColor;
  bool isGameOver = false;
  bool isGameOverAnimating = false;
  final List<AudioPlayer> _audioPool = [];
  bool _showIntro = true;
  Timer? _gameOverAnimTimer;
  List<Particle> particles = [];
  late Ticker _gameTicker;
  bool _introParticlesInitialized = false;

  int rotateCount = 3;
  int refreshCount = 1;
  int hammerCount = 3;
  bool isHammerActive = false;

  double shakeOffsetX = 0;
  double shakeOffsetY = 0;
  String? comboMessage;
  double comboOpacity = 0.0;
  int comboMultiplier = 1;
  int comboTimeLeft = 0;
  Timer? _comboCountdownTimer;

  List<String> _lastGeneratedShapeKeys = [];
  List<int> pulsingCells = [];
  Map<int, double> cellScales = {};

  late AnimationController _scoreAnimController;
  late Animation<double> _scoreScaleAnim;
  late AnimationController _gridScrollController;

  bool isPaused = false;
  bool isSoundOn = true;
  bool isHapticOn = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    grid = List.generate(rowSize * rowSize, (index) => null);
    for (int i = 0; i < 5; i++) _audioPool.add(AudioPlayer());

    _gameTicker = createTicker(_onGameTick);

    _scoreAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _scoreScaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOut));

    _gridScrollController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

    _initGame();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showIntro = false;
          particles.removeWhere((p) => p.isIntroParticle);
          if (!isPaused && !isGameOver) {
            if (!_gameTicker.isTicking) _gameTicker.start();
            gameStopwatch.start();
          }
        });
      }
    });

    if (_showIntro) _gameTicker.start();
  }

  Future<void> _initGame() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadSettings();
      bool loaded = _loadGameState();
      if (mounted) {
        if (loaded) {
          setState(() {});
        } else {
          generateNewShapes();
        }
      }
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
      if (mounted && availableShapes.isEmpty) generateNewShapes();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      gameStopwatch.stop();
      _saveGameState();
      setState(() => isPaused = true);
    } else if (state == AppLifecycleState.resumed && !isPaused && !isGameOver) {
      gameStopwatch.start();
    }
  }

  void _loadSettings() {
    setState(() {
      isSoundOn = _prefs?.getBool('sound') ?? true;
      isHapticOn = _prefs?.getBool('haptic') ?? true;
      bestScore = _prefs?.getInt('bestScore') ?? 0;
      coins = _prefs?.getInt('coins') ?? 0;
      displayCoins = coins;

      statsTotalGames = _prefs?.getInt('stats_games') ?? 0;
      statsTotalBlocks = _prefs?.getInt('stats_blocks') ?? 0;
      statsTotalRows = _prefs?.getInt('stats_rows') ?? 0;
      statsTotalCols = _prefs?.getInt('stats_cols') ?? 0;
      statsTotalTimeSeconds = _prefs?.getInt('stats_time') ?? 0;
      statsTotalScoreSum = _prefs?.getInt('stats_score_sum') ?? 0;
      statsHighestCombo = _prefs?.getInt('stats_high_combo') ?? 0;
    });
  }

  void _saveGameState() {
    if (_prefs == null || isGameOver) {
      if (isGameOver) {
        _prefs?.remove('grid');
        _prefs?.remove('score');
        _prefs?.remove('shapes');
        _prefs?.remove('powerups');
      }
      _prefs?.setInt('bestScore', bestScore);
      _prefs?.setInt('coins', coins);
      return;
    }
    List<String> gridData =
        grid.map((c) => c != null ? jsonEncode(c.toJson()) : "").toList();
    List<String> shapesData =
        availableShapes.map((s) => jsonEncode(s.toJson())).toList();
    List<String> powerUps = [
      rotateCount.toString(),
      refreshCount.toString(),
      hammerCount.toString()
    ];
    _prefs?.setStringList('grid', gridData);
    _prefs?.setInt('score', score);
    _prefs?.setStringList('shapes', shapesData);
    _prefs?.setStringList('powerups', powerUps);
    _prefs?.setInt('bestScore', bestScore);
    _prefs?.setInt('coins', coins);
  }

  bool _loadGameState() {
    if (_prefs == null) return false;
    if (!_prefs!.containsKey('grid')) return false;
    try {
      List<String>? gridData = _prefs?.getStringList('grid');
      if (gridData != null) {
        grid = gridData.map((s) {
          if (s.isEmpty) return null;
          return CellData.fromJson(jsonDecode(s));
        }).toList();
      }
      score = _prefs?.getInt('score') ?? 0;
      displayScore = score;
      coins = _prefs?.getInt('coins') ?? 0;
      displayCoins = coins;
      List<String>? shapesData = _prefs?.getStringList('shapes');
      if (shapesData != null) {
        availableShapes =
            shapesData.map((s) => ShapeData.fromJson(jsonDecode(s))).toList();
      }
      List<String>? powerData = _prefs?.getStringList('powerups');
      if (powerData != null) {
        rotateCount = int.parse(powerData[0]);
        refreshCount = int.parse(powerData[1]);
        hammerCount = int.parse(powerData[2]);
      }
      return true;
    } catch (e) {
      debugPrint("Kayıt yükleme hatası: $e");
      return false;
    }
  }

  void _togglePause() {
    if (isGameOver) return;
    setState(() {
      isPaused = !isPaused;
      if (isPaused) {
        gameStopwatch.stop();
        _comboCountdownTimer?.cancel();
      } else {
        gameStopwatch.start();
        if (comboTimeLeft > 0) activateCombo(0);
      }
    });
  }

  void _toggleSound() {
    setState(() {
      isSoundOn = !isSoundOn;
      _prefs?.setBool('sound', isSoundOn);
    });
  }

  void _toggleHaptic() {
    setState(() {
      isHapticOn = !isHapticOn;
      _prefs?.setBool('haptic', isHapticOn);
    });
  }

  void _showShopDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateShop) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161621),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side:
                    BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("SHOP",
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Color(0xFFFFB300), size: 20),
                    const SizedBox(width: 5),
                    Text(coins.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                )
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildShopItem(Icons.rotate_right, "3x Rotate", 50, Colors.blue,
                    () {
                  if (coins >= 50) {
                    setState(() {
                      coins -= 50;
                      rotateCount += 3;
                    });
                    setStateShop(() {});
                    _saveGameState();
                    playSound('place.wav', pitch: 1.5);
                  }
                }),
                const SizedBox(height: 10),
                _buildShopItem(Icons.refresh, "1x Refresh", 100, Colors.green,
                    () {
                  if (coins >= 100) {
                    setState(() {
                      coins -= 100;
                      refreshCount += 1;
                    });
                    setStateShop(() {});
                    _saveGameState();
                    playSound('place.wav', pitch: 1.5);
                  }
                }),
                const SizedBox(height: 10),
                _buildShopItem(Icons.gavel, "1x Hammer", 200, Colors.red, () {
                  if (coins >= 200) {
                    setState(() {
                      coins -= 200;
                      hammerCount += 1;
                    });
                    setStateShop(() {});
                    _saveGameState();
                    playSound('place.wav', pitch: 1.5);
                  }
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE",
                    style: TextStyle(color: Colors.white70)),
              )
            ],
          );
        });
      },
    );
  }

  Widget _buildShopItem(IconData icon, String title, int price, Color neonColor,
      VoidCallback onBuy) {
    bool canAfford = coins >= price;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
                offset: const Offset(2, 2))
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: Colors.black26, shape: BoxShape.circle),
            child: Icon(icon, color: neonColor, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? Colors.green : Colors.grey,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              elevation: canAfford ? 5 : 0,
            ),
            onPressed: canAfford ? onBuy : null,
            child: Row(
              children: [
                const Icon(Icons.monetization_on,
                    size: 14, color: Colors.black),
                const SizedBox(width: 4),
                Text(price.toString(),
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_introParticlesInitialized && _showIntro) {
      _spawnIntroParticles();
      _introParticlesInitialized = true;
    }
  }

  void _updateBestScore() {
    if (score > bestScore) {
      setState(() {
        bestScore = score;
        _prefs?.setInt('bestScore', bestScore);
      });
    }
  }

  void _spawnIntroParticles() {
    final random = math.Random();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    for (int i = 0; i < 12; i++) {
      particles.add(Particle(
        x: random.nextDouble() * screenWidth,
        y: random.nextDouble() * screenHeight,
        vx: (random.nextDouble() - 0.5) * 2,
        vy: (random.nextDouble() - 0.5) * 2,
        color: shapeColors[random.nextInt(shapeColors.length)],
        size: random.nextDouble() * 20 + 10,
        opacity: random.nextDouble() * 0.5 + 0.2,
        isIntroParticle: true,
        rotation: random.nextDouble() * math.pi * 2,
        rotationSpeed: (random.nextDouble() - 0.5) * 0.05,
      ));
    }
  }

  void generateNewShapes() {
    final random = math.Random();
    List<ShapeData> newShapes = [];
    List<String> pool = [];
    if (score < 500) {
      pool.addAll(List.filled(10, easyShapes).expand((i) => i));
      pool.addAll(List.filled(3, mediumShapes).expand((i) => i));
      pool.add('tekli');
    } else if (score < 1500) {
      pool.addAll(List.filled(5, easyShapes).expand((i) => i));
      pool.addAll(List.filled(5, mediumShapes).expand((i) => i));
      pool.addAll(List.filled(2, hardShapes).expand((i) => i));
      pool.add('tekli');
    } else if (score < 3000) {
      pool.addAll(List.filled(3, easyShapes).expand((i) => i));
      pool.addAll(List.filled(5, mediumShapes).expand((i) => i));
      pool.addAll(List.filled(4, hardShapes).expand((i) => i));
      pool.addAll(List.filled(1, expertShapes).expand((i) => i));
      pool.add('tekli');
    } else {
      pool.addAll(List.filled(2, easyShapes).expand((i) => i));
      pool.addAll(List.filled(4, mediumShapes).expand((i) => i));
      pool.addAll(List.filled(5, hardShapes).expand((i) => i));
      pool.addAll(List.filled(3, expertShapes).expand((i) => i));
      pool.addAll(List.filled(2, 'tekli'));
    }

    for (int i = 0; i < 3; i++) {
      List<String> tempPool = List.from(pool);
      tempPool.shuffle();
      String selectedKey = tempPool.first;
      for (var key in tempPool) {
        if (!_lastGeneratedShapeKeys.contains(key)) {
          selectedKey = key;
          break;
        }
      }
      _lastGeneratedShapeKeys.add(selectedKey);
      if (_lastGeneratedShapeKeys.length > 3) {
        _lastGeneratedShapeKeys.removeAt(0);
      }
      Color randomColor = shapeColors[random.nextInt(shapeColors.length)];

      newShapes
          .add(ShapeData(points: allShapes[selectedKey]!, color: randomColor));
    }
    setState(() {
      availableShapes = newShapes;
      checkGameOverCondition();
      _saveGameState();
    });
  }

  void activateCombo(int lines) {
    if (_comboCountdownTimer != null) _comboCountdownTimer!.cancel();
    setState(() {
      if (lines >= 2) {
        comboMultiplier = (comboMultiplier == 1) ? 2 : 4;
        comboTimeLeft = 10;
        if (comboMultiplier > currentMaxCombo)
          currentMaxCombo = comboMultiplier;
      }
    });
    _comboCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !isPaused) {
        setState(() {
          comboTimeLeft--;
          if (comboTimeLeft <= 0) {
            comboMultiplier = 1;
            timer.cancel();
          }
        });
      }
    });
  }

  void showFloatingMessage(String message) {
    setState(() {
      comboMessage = message;
      comboOpacity = 1.0;
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => comboOpacity = 0.0);
    });
  }

  void triggerShake() {
    if (isHapticOn) HapticFeedback.heavyImpact();
    int steps = 0;
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      steps++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (steps >= 6) {
          shakeOffsetX = 0;
          shakeOffsetY = 0;
          timer.cancel();
        } else {
          shakeOffsetX = (math.Random().nextDouble() - 0.5) * 8;
          shakeOffsetY = (math.Random().nextDouble() - 0.5) * 8;
        }
      });
    });
  }

  void useRotate() {
    if (isPaused) return;
    if (rotateCount > 0) {
      setState(() {
        playSound('place.wav', varyPitch: true);
        if (isHapticOn) HapticFeedback.selectionClick();
        for (var shape in availableShapes) {
          if (!shape.isUsed) shape.rotate();
        }
        rotateCount--;
        _saveGameState();
      });
    }
  }

  void useRefresh() {
    if (isPaused) return;
    if (refreshCount > 0) {
      setState(() {
        playSound('place.wav', varyPitch: true);
        if (isHapticOn) HapticFeedback.mediumImpact();
        generateNewShapes();
        refreshCount--;
        _saveGameState();
      });
    }
  }

  void toggleHammer() {
    if (isPaused) return;
    if (hammerCount > 0) {
      setState(() => isHammerActive = !isHammerActive);
      if (isHapticOn) HapticFeedback.selectionClick();
    }
  }

  void useHammer(int index) {
    if (isPaused) return;
    if (isHammerActive && grid[index] != null) {
      setState(() {
        spawnExplosion(index, grid[index]!.color);
        grid[index] = null;
        hammerCount--;
        isHammerActive = false;
        playSound('explode.wav', varyPitch: true);
        if (isHapticOn) HapticFeedback.heavyImpact();
        checkLinesAndClear();
        _saveGameState();
      });
    }
  }

  void playSound(String fileName,
      {double pitch = 1.0, bool varyPitch = false}) async {
    if (!isSoundOn) return;
    try {
      final player = _audioPool.firstWhere(
          (p) => p.state != PlayerState.playing,
          orElse: () => _audioPool[0]);
      await player.stop();
      if (varyPitch) {
        double newPitch = 0.8 + math.Random().nextDouble() * 0.4;
        await player.setPlaybackRate(newPitch);
      } else {
        await player.setPlaybackRate(pitch);
      }
      await player.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint("Ses hatası: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameOverAnimTimer?.cancel();
    _comboCountdownTimer?.cancel();
    _gameTicker.dispose();
    _scoreAnimController.dispose();
    _gridScrollController.dispose();
    gameStopwatch.stop();
    for (var p in _audioPool) p.dispose();
    super.dispose();
  }

  void _onGameTick(Duration elapsed) {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    setState(() {
      if (displayScore < score) {
        int diff = score - displayScore;
        displayScore += math.max(1, (diff / 10).ceil());
        if (displayScore > score) displayScore = score;
      }
      if (displayCoins < coins) {
        int diff = coins - displayCoins;
        displayCoins += math.max(1, (diff / 10).ceil());
        if (displayCoins > coins) displayCoins = coins;
      } else if (displayCoins > coins) {
        int diff = displayCoins - coins;
        displayCoins -= math.max(1, (diff / 10).ceil());
        if (displayCoins < coins) displayCoins = coins;
      }

      cellScales.forEach((key, value) {
        cellScales[key] = value * 0.9;
        if (cellScales[key]! < 1.0) cellScales[key] = 1.0;
      });
      cellScales.removeWhere((key, value) => value <= 1.0);

      // --- PARTİKÜL GÜNCELLEME (HIZLANDIRILMIŞ FİZİK) ---
      if (particles.isNotEmpty) {
        for (int i = particles.length - 1; i >= 0; i--) {
          var p = particles[i];

          if (p.isIntroParticle) {
            // Intro mantığı (aynı)
            p.x += p.vx;
            p.y += p.vy;
            p.rotation += p.rotationSpeed;
            if (p.x < -p.size) p.x = screenWidth + p.size;
            if (p.x > screenWidth + p.size) p.x = -p.size;
            if (p.y < -p.size) p.y = screenHeight + p.size;
            if (p.y > screenHeight + p.size) p.y = -p.size;
          } else {
            // --- HIZLANDIRILMIŞ PATLAMA FİZİĞİ ---

            p.life -= p.decayRate; // Ömürden ye

            if (p.type == ParticleType.debris) {
              // Debris fizikleri: Yerçekimi + Sürtünme
              p.x += p.vx;
              p.y += p.vy;
              p.vy += 1.2; // GÜÇLENDİRİLMİŞ YERÇEKİMİ (Daha hızlı düşüş)
              p.vx *= 0.96;
              p.rotation += p.rotationSpeed;
              p.size *= 0.98;
            } else if (p.type == ParticleType.spark) {
              // Kıvılcım fizikleri
              p.x += p.vx;
              p.y += p.vy;
              p.vx *= 0.90;
              p.vy *= 0.90;
              p.vy += 0.2;
              p.size *= 0.92;
            } else if (p.type == ParticleType.ring) {
              // Halka fizikleri
              p.size += 5.0;
            }

            // Ekrandan çıkma veya ömrü bitme kontrolü
            if (p.life <= 0 || p.size < 0.5 || p.y > screenHeight + 50) {
              particles.removeAt(i);
            }
          }
        }
      }
    });
  }

  void spawnExplosion(int gridIndex, Color color) {
    int col = gridIndex % rowSize;
    int row = gridIndex ~/ rowSize;
    double stride = cellSize + 2.0;

    final RenderBox? renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // YENİ KOORDİNAT HESAPLAMA (Stack referanslı)
    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    // Grid'in Stack içindeki konumunu al
    Offset gridOffset =
        renderBox.localToGlobal(Offset.zero, ancestor: stackBox);

    // Bloğun merkezi
    double centerX = gridOffset.dx + col * stride + (cellSize / 2);
    double centerY = gridOffset.dy + row * stride + (cellSize / 2);

    final random = math.Random();

    // 1. BLOK PARÇALARI (DEBRIS) - HIZLANDIRILMIŞ
    int debrisCount = 6 + random.nextInt(4);
    for (int i = 0; i < debrisCount; i++) {
      double angle = random.nextDouble() * 2 * math.pi;
      double speed = random.nextDouble() * 8 + 4;

      final HSLColor hsl = HSLColor.fromColor(color);
      final Color variedColor = hsl
          .withLightness((hsl.lightness + (random.nextDouble() * 0.2 - 0.1))
              .clamp(0.0, 1.0))
          .toColor();

      particles.add(Particle(
        x: centerX + (random.nextDouble() - 0.5) * cellSize * 0.5,
        y: centerY + (random.nextDouble() - 0.5) * cellSize * 0.5,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 5,
        color: variedColor,
        size: cellSize / 4 + random.nextDouble() * (cellSize / 4),
        type: ParticleType.debris,
        rotation: random.nextDouble() * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 0.2,
        decayRate: 0.01 + random.nextDouble() * 0.02,
      ));
    }

    // 2. KIVILCIMLAR (SPARKS)
    int sparkCount = 8 + random.nextInt(5);
    for (int i = 0; i < sparkCount; i++) {
      double angle = random.nextDouble() * 2 * math.pi;
      double speed = random.nextDouble() * 10 + 5;

      particles.add(Particle(
        x: centerX,
        y: centerY,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: Colors.white,
        size: 3 + random.nextDouble() * 3,
        type: ParticleType.spark,
        decayRate: 0.03 + random.nextDouble() * 0.03,
      ));
    }

    // 3. ŞOK DALGASI (RING)
    particles.add(Particle(
      x: centerX,
      y: centerY,
      vx: 0,
      vy: 0,
      color: color.withOpacity(0.8),
      size: cellSize / 2,
      type: ParticleType.ring,
      decayRate: 0.05,
    ));
  }

  void resetGame() {
    if (isHapticOn) HapticFeedback.mediumImpact();
    _prefs?.remove('grid');
    setState(() {
      grid = List.generate(rowSize * rowSize, (index) => null);
      score = 0;
      displayScore = 0;
      rotateCount = 3;
      refreshCount = 1;
      hammerCount = 3;
      isGameOver = false;
      isGameOverAnimating = false;
      isPaused = false;
      particles.clear();
      comboMultiplier = 1;
      comboTimeLeft = 0;
      pulsingCells.clear();
      cellScales.clear();
      _lastGeneratedShapeKeys.clear();
      currentBlocksPopped = 0;
      currentRowsCleared = 0;
      currentColsCleared = 0;
      currentMaxCombo = 0;
      currentCoinsEarned = 0;
      gameStopwatch.reset();
      gameStopwatch.start();
      generateNewShapes();
    });
  }

  void checkGameOverCondition() {
    List<ShapeData> unused = availableShapes.where((s) => !s.isUsed).toList();
    if (unused.isEmpty) return;
    bool atLeastOneMovePossible = false;
    for (var shape in unused) {
      for (int i = 0; i < rowSize * rowSize; i++) {
        if (canPlace(i, shape.points)) {
          atLeastOneMovePossible = true;
          break;
        }
      }
      if (atLeastOneMovePossible) break;
    }
    if (!atLeastOneMovePossible) startGameOverSequence();
  }

  void _processGameOverStats() {
    gameStopwatch.stop();
    int elapsedSeconds = gameStopwatch.elapsed.inSeconds;
    setState(() {
      statsTotalGames++;
      statsTotalBlocks += currentBlocksPopped;
      statsTotalRows += currentRowsCleared;
      statsTotalCols += currentColsCleared;
      statsTotalTimeSeconds += elapsedSeconds;
      statsTotalScoreSum += score;
      if (currentMaxCombo > statsHighestCombo)
        statsHighestCombo = currentMaxCombo;
    });
    _prefs?.setInt('stats_games', statsTotalGames);
    _prefs?.setInt('stats_blocks', statsTotalBlocks);
    _prefs?.setInt('stats_rows', statsTotalRows);
    _prefs?.setInt('stats_cols', statsTotalCols);
    _prefs?.setInt('stats_time', statsTotalTimeSeconds);
    _prefs?.setInt('stats_score_sum', statsTotalScoreSum);
    _prefs?.setInt('stats_high_combo', statsHighestCombo);
  }

  void startGameOverSequence() {
    setState(() => isGameOverAnimating = true);
    int currentIndex = 0;
    if (isHapticOn) HapticFeedback.heavyImpact();
    _processGameOverStats();
    _gameOverAnimTimer =
        Timer.periodic(const Duration(milliseconds: 5), (timer) {
      if (currentIndex >= rowSize * rowSize) {
        timer.cancel();
        setState(() {
          isGameOverAnimating = false;
          isGameOver = true;
        });
        _saveGameState();
        return;
      }
      if (grid[currentIndex] != null) {
        grid[currentIndex] = CellData(color: Colors.grey[900]!, isChest: false);
      }
      currentIndex++;
    });
  }

  int? getIndexFromGlobalPosition(Offset globalPosition) {
    final RenderBox? renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    Offset localPosition = renderBox.globalToLocal(globalPosition);
    double stride = cellSize + 2.0;
    double adjustedX = localPosition.dx - (cellSize / 2);
    double adjustedY = localPosition.dy - (cellSize / 2);
    int col = (adjustedX / stride).round();
    int row = (adjustedY / stride).round();
    if (col < 0 || col >= rowSize || row < 0 || row >= rowSize) return null;
    return row * rowSize + col;
  }

  void onDragUpdate(Offset globalPosition, ShapeData shape) {
    if (isGameOver || isGameOverAnimating || isHammerActive || isPaused) return;
    int? index = getIndexFromGlobalPosition(globalPosition);
    if (index != null && canPlace(index, shape.points)) {
      if (previewIndices.isEmpty || !previewIndices.contains(index)) {
        if (isHapticOn) HapticFeedback.selectionClick();
      }
      setState(() {
        previewIndices = calculateShapeIndices(index, shape.points);
        previewColor = shape.color;
      });
    } else {
      setState(() => previewIndices.clear());
    }
  }

  void onDragStarted() {
    if (isGameOver || isGameOverAnimating || isHammerActive || isPaused) return;
    if (isHapticOn) HapticFeedback.selectionClick();
    playSound('click.mp3', varyPitch: true);
  }

  void onDragEnd(Offset globalPosition, ShapeData shape, int shapeIndex) {
    if (isGameOver || isGameOverAnimating || isHammerActive || isPaused) return;
    int? index = getIndexFromGlobalPosition(globalPosition);
    if (index != null && canPlace(index, shape.points)) {
      placeShape(index, shape, shapeIndex);
    }
    setState(() => previewIndices.clear());
  }

  List<int> calculateShapeIndices(int targetIndex, List<List<int>> shape) {
    List<int> indices = [];
    int targetRow = targetIndex ~/ rowSize;
    int targetCol = targetIndex % rowSize;
    for (var point in shape) {
      int r = targetRow + point[1];
      int c = targetCol + point[0];
      if (r < 0 || r >= rowSize || c < 0 || c >= rowSize) return [];
      indices.add(r * rowSize + c);
    }
    return indices;
  }

  bool canPlace(int targetIndex, List<List<int>> shape) {
    List<int> indices = calculateShapeIndices(targetIndex, shape);
    if (indices.isEmpty) return false;
    for (int idx in indices) {
      if (grid[idx] != null) return false;
    }
    return true;
  }

  void placeShape(int targetIndex, ShapeData shapeData, int shapeIndex) {
    setState(() {
      playSound('place.wav', varyPitch: true);
      if (isHapticOn) HapticFeedback.mediumImpact();
      List<int> indices = calculateShapeIndices(targetIndex, shapeData.points);
      for (int idx in indices) {
        bool isChest = math.Random().nextDouble() < 0.05;
        grid[idx] = CellData(color: shapeData.color, isChest: isChest);
        cellScales[idx] = 1.2;
      }
      score += indices.length * comboMultiplier;
      _scoreAnimController.forward(from: 0);
      _updateBestScore();
      availableShapes[shapeIndex].isUsed = true;
      checkLinesAndClear();
      if (availableShapes.every((s) => s.isUsed)) {
        generateNewShapes();
      } else {
        checkGameOverCondition();
        _saveGameState();
      }
    });
  }

  void checkLinesAndClear() {
    List<int> rowsToClear = [];
    List<int> colsToClear = [];
    for (int r = 0; r < rowSize; r++) {
      bool isFull = true;
      for (int c = 0; c < rowSize; c++) {
        if (grid[r * rowSize + c] == null) {
          isFull = false;
          break;
        }
      }
      if (isFull) rowsToClear.add(r);
    }
    for (int c = 0; c < rowSize; c++) {
      bool isFull = true;
      for (int r = 0; r < rowSize; r++) {
        if (grid[r * rowSize + c] == null) {
          isFull = false;
          break;
        }
      }
      if (isFull) colsToClear.add(c);
    }
    int totalLines = rowsToClear.length + colsToClear.length;

    if (totalLines > 0) {
      currentRowsCleared += rowsToClear.length;
      currentColsCleared += colsToClear.length;
    }

    if (totalLines > 0) {
      if (totalLines >= 3) {
        playSound('4block.mp3');
        if (isHapticOn) HapticFeedback.heavyImpact();
      } else {
        playSound('explode.wav', varyPitch: true);
        if (isHapticOn) HapticFeedback.lightImpact();
      }

      if (totalLines >= 3) {
        triggerShake();
      }

      if (totalLines >= 2) {
        String msg = totalLines == 2
            ? "DOUBLE!"
            : totalLines == 3
                ? "GREAT!"
                : "AMAZING!";
        if (comboMultiplier > 1) msg += "\n${comboMultiplier}X";
        showFloatingMessage(msg);
      }
      activateCombo(totalLines);

      setState(() {
        pulsingCells.clear();
        for (int r in rowsToClear) {
          for (int c = 0; c < rowSize; c++) {
            pulsingCells.add(r * rowSize + c);
          }
        }
        for (int c in colsToClear) {
          for (int r = 0; r < rowSize; r++) {
            int idx = r * rowSize + c;
            if (!pulsingCells.contains(idx)) pulsingCells.add(idx);
          }
        }
      });

      // --- GECİKME MİNİMİZE EDİLDİ ---
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        setState(() {
          int coinsEarned = 0;
          Set<int> cellsToClear = {};
          for (int r in rowsToClear) {
            for (int c = 0; c < rowSize; c++) cellsToClear.add(r * rowSize + c);
            score += 100 * comboMultiplier;
          }
          for (int c in colsToClear) {
            for (int r = 0; r < rowSize; r++) cellsToClear.add(r * rowSize + c);
            score += 100 * comboMultiplier;
          }

          currentBlocksPopped += cellsToClear.length;

          for (int idx in cellsToClear) {
            if (grid[idx] != null) {
              spawnExplosion(idx, grid[idx]!.color);
              coinsEarned += 1;
              if (grid[idx]!.isChest) {
                coinsEarned += 50;
                showFloatingMessage("+50 COINS!");
                playSound('place.wav', pitch: 2.0);
              }
              grid[idx] = null;
            }
          }
          if (comboMultiplier > 1) {
            coinsEarned += 10 * comboMultiplier;
          }
          coins += coinsEarned;
          currentCoinsEarned += coinsEarned;

          pulsingCells.clear();
          _scoreAnimController.forward(from: 0);
          _updateBestScore();
          _saveGameState();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) return _buildIntroScreen();
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          double availableWidth = constraints.maxWidth - 20;
          cellSize = (availableWidth - (rowSize - 1) * 2) / rowSize;
          if (cellSize * rowSize > constraints.maxHeight - 250) {
            double availableHeight = constraints.maxHeight - 300;
            cellSize = (availableHeight - (rowSize - 1) * 2) / rowSize;
          }
          return Stack(
            key: _stackKey, // ANAHTAR ATANDI (Önemli)
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _gridScrollController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RetroGridPainter(_gridScrollController.value),
                    );
                  },
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14141F),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                    offset: const Offset(2, 2))
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events,
                                    color: Color(0xFFFFB300), size: 20),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("BEST",
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1)),
                                    Text(bestScore.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Courier')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFFFB300)
                                            .withOpacity(0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(2, 2))
                                    ]),
                                child: Row(
                                  children: [
                                    const Icon(Icons.monetization_on,
                                        color: Color(0xFFFFB300), size: 16),
                                    const SizedBox(width: 5),
                                    Text(displayCoins.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              BouncingScaleButton(
                                onTap: _showShopDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF2D2D44),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.1)),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            blurRadius: 4,
                                            offset: const Offset(2, 2))
                                      ]),
                                  child: const Icon(Icons.shopping_cart,
                                      color: Colors.greenAccent, size: 20),
                                ),
                              ),
                              const SizedBox(width: 10),
                              BouncingScaleButton(
                                onTap: _togglePause,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF2D2D44),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.1)),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            blurRadius: 4,
                                            offset: const Offset(2, 2))
                                      ]),
                                  child: const Icon(Icons.pause,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _scoreScaleAnim,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scoreScaleAnim.value,
                              child: Text(displayScore.toString(),
                                  style: const TextStyle(
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontSize: 40,
                                      shadows: [
                                        Shadow(
                                            color: Colors.black,
                                            blurRadius: 0,
                                            offset: Offset(2, 2))
                                      ])),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Transform.translate(
                          offset: Offset(shakeOffsetX, shakeOffsetY),
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                                color: const Color(0xFF14141F),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                    width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5))
                                ]),
                            child: Container(
                              key: _gridKey,
                              width: cellSize * rowSize + (rowSize - 1) * 2,
                              height: cellSize * rowSize + (rowSize - 1) * 2,
                              color: Colors.transparent,
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: rowSize * rowSize,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: rowSize,
                                        mainAxisSpacing: 2,
                                        crossAxisSpacing: 2,
                                        childAspectRatio: 1.0),
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () => useHammer(index),
                                    child: Builder(builder: (context) {
                                      CellData? cellData = grid[index];
                                      bool isPulsing =
                                          pulsingCells.contains(index);
                                      double scale = cellScales[index] ?? 1.0;

                                      Widget cell;

                                      if (previewIndices.contains(index)) {
                                        cell = CustomPaint(
                                          painter: SimpleCubePainter(
                                              color:
                                                  previewColor ?? Colors.white,
                                              isGhost: true),
                                        );
                                      } else if (cellData == null) {
                                        cell = Container(
                                            decoration:
                                                getEmptySlotDecoration());
                                      } else {
                                        cell = CustomPaint(
                                          painter: SimpleCubePainter(
                                            color: cellData.color,
                                            isChest: cellData.isChest,
                                          ),
                                          child: cellData.isChest
                                              ? const Center(
                                                  child: Icon(
                                                      Icons.diamond_outlined,
                                                      color: Colors.white,
                                                      size: 18))
                                              : null,
                                        );
                                      }

                                      if (scale != 1.0 || isPulsing) {
                                        double finalScale =
                                            isPulsing ? 0.0 : scale;
                                        cell = Transform.scale(
                                            scale: finalScale, child: cell);
                                      }

                                      return cell;
                                    }),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BouncingScaleButton(
                          onTap: useRotate,
                          child: _buildPowerUpBtn(
                              Icons.rotate_right, rotateCount, Colors.blue,
                              isActive: false),
                        ),
                        const SizedBox(width: 15),
                        BouncingScaleButton(
                          onTap: useRefresh,
                          child: _buildPowerUpBtn(
                              Icons.refresh, refreshCount, Colors.green,
                              isActive: false),
                        ),
                        const SizedBox(width: 15),
                        BouncingScaleButton(
                          onTap: toggleHammer,
                          child: _buildPowerUpBtn(
                              Icons.gavel, hammerCount, Colors.red,
                              isActive: isHammerActive),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: const Color(0xFF14141F),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: availableShapes.asMap().entries.map((entry) {
                        int index = entry.key;
                        ShapeData shape = entry.value;
                        Widget slotContent = Container(
                          width: cellSize * 3,
                          height: cellSize * 3,
                          alignment: Alignment.center,
                          child: shape.isUsed
                              ? null
                              : DraggableShape(
                                  shapeData: shape,
                                  shapeIndex: index,
                                  baseCellSize: cellSize,
                                  onDragStarted: onDragStarted,
                                  onDragUpdate: (pos) =>
                                      onDragUpdate(pos, shape),
                                  onDragEnd: (pos) =>
                                      onDragEnd(pos, shape, index)),
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: slotContent,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              // 3. KATMAN: Patlama Efektleri (En Üstte ve FİLTRESİZ)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: ParticlePainter(particles)),
                ),
              ),

              if (comboMultiplier > 1)
                Positioned(
                  right: 10,
                  top: MediaQuery.of(context).size.height * 0.3,
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 200,
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFFFB300), width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2))
                            ]),
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(seconds: 1),
                          width: 30,
                          height: (comboTimeLeft / 10) * 200,
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFB300),
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text("${comboMultiplier}X",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFB300),
                              fontSize: 20,
                              shadows: [
                                Shadow(
                                    color: Colors.black, offset: Offset(1, 1))
                              ])),
                    ],
                  ),
                ),
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: comboOpacity,
                  child: Text(comboMessage ?? "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 50,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: Colors.blueAccent,
                                blurRadius: 0,
                                offset: Offset(4, 4))
                          ])),
                ),
              ),
              if (isPaused)
                Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                          color: const Color(0xFF14141F),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(4, 4))
                          ]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("PAUSED",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSettingsBtn(
                                  isSoundOn
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                  isSoundOn ? Colors.green : Colors.grey,
                                  _toggleSound),
                              const SizedBox(width: 20),
                              _buildSettingsBtn(
                                  isHapticOn
                                      ? Icons.vibration
                                      : Icons.smartphone,
                                  isHapticOn ? Colors.blue : Colors.grey,
                                  _toggleHaptic),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF388E3C),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6))),
                              onPressed: _togglePause,
                              child: const Text("RESUME",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6))),
                              onPressed: () {
                                resetGame();
                              },
                              child: const Text("RESTART",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (isGameOver)
                Container(
                  color: Colors.black.withOpacity(0.9),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("MISSION REPORT",
                              style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 40,
                                  color: Color(0xFFD32F2F),
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black,
                                        offset: Offset(2, 2))
                                  ])),
                          const SizedBox(height: 10),
                          Text("SCORE: $score",
                              style: const TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: const Color(0xFF14141F),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(4, 4))
                                ]),
                            child: Column(
                              children: [
                                const Text("CURRENT MISSION",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        letterSpacing: 2)),
                                const Divider(color: Colors.white24),
                                _buildStatRow(
                                    "Blocks Popped",
                                    "$currentBlocksPopped",
                                    const Color(0xFF1976D2)),
                                _buildStatRow(
                                    "Max Combo",
                                    "${currentMaxCombo}x",
                                    const Color(0xFFFFB300)),
                                _buildStatRow(
                                    "Lines Cleared",
                                    "${currentRowsCleared}R / ${currentColsCleared}C",
                                    const Color(0xFF388E3C)),
                                _buildStatRow(
                                    "Coins Looted",
                                    "$currentCoinsEarned",
                                    const Color(0xFFFFB300)),
                                _buildStatRow(
                                    "Time",
                                    "${gameStopwatch.elapsed.inMinutes}:${(gameStopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}",
                                    Colors.white),
                                const SizedBox(height: 20),
                                const Text("LIFETIME STATS",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        letterSpacing: 2)),
                                const Divider(color: Colors.white24),
                                _buildStatRow("Total Games", "$statsTotalGames",
                                    Colors.white70),
                                _buildStatRow("Total Blocks",
                                    "$statsTotalBlocks", Colors.white70),
                                _buildStatRow(
                                    "Best Combo",
                                    "${statsHighestCombo}x",
                                    const Color(0xFFFFB300).withOpacity(0.7)),
                                _buildStatRow("Total Coins", "$coins",
                                    const Color(0xFFFFB300).withOpacity(0.7)),
                                _buildStatRow(
                                    "Avg Score",
                                    "${statsTotalGames > 0 ? (statsTotalScoreSum / statsTotalGames).toStringAsFixed(0) : 0}",
                                    Colors.white70),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF388E3C),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6))),
                            onPressed: resetGame,
                            child: const Text("PLAY AGAIN",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier')),
        ],
      ),
    );
  }

  Widget _buildSettingsBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: const Color(0xFF2D2D44),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2))
            ]),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildPowerUpBtn(IconData icon, int count, Color color,
      {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isActive ? color : const Color(0xFF2D2D44),
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? Colors.white : color, width: 2),
          boxShadow: [
            if (isActive)
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2))
          ]),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: isActive ? Colors.white : color, size: 24),
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Text(count.toString(),
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildIntroScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
              child: CustomPaint(painter: ParticlePainter(particles))),
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("RETRO",
                      style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w900,
                          fontSize: 80,
                          color: Color(0xFF9D8FFF),
                          shadows: [
                            Shadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
                                blurRadius: 0)
                          ])),
                  const SizedBox(height: 10),
                  const Text("BLAST",
                      style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w900,
                          fontSize: 80,
                          color: Color(0xFFFFB300),
                          shadows: [
                            Shadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
                                blurRadius: 0)
                          ])),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 15),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        border: Border.all(
                            color: const Color(0xFF7FD687), width: 3),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          const BoxShadow(
                              color: Colors.black,
                              offset: Offset(4, 4),
                              blurRadius: 0)
                        ]),
                    child: Text("BEST SCORE: $bestScore",
                        style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 22,
                            color: Color(0xFF7FD687),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 0)
                            ])),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DraggableShape extends StatelessWidget {
  final ShapeData shapeData;
  final int shapeIndex;
  final double baseCellSize;
  final VoidCallback onDragStarted;
  final Function(Offset) onDragUpdate;
  final Function(Offset) onDragEnd;

  const DraggableShape(
      {super.key,
      required this.shapeData,
      required this.shapeIndex,
      required this.baseCellSize,
      required this.onDragStarted,
      required this.onDragUpdate,
      required this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    int maxX = 0, maxY = 0;
    for (var p in shapeData.points) {
      if (p[0] > maxX) maxX = p[0];
      if (p[1] > maxY) maxY = p[1];
    }
    double displayScale = 0.6;
    double displayCellSize = baseCellSize * displayScale;
    if (displayCellSize < 15) displayCellSize = 15;

    Widget buildShape(double size, double gap) {
      return SizedBox(
        width: (maxX + 1) * size + (maxX * gap),
        height: (maxY + 1) * size + (maxY * gap),
        child: Stack(
          children: shapeData.points.map((point) {
            return Positioned(
              left: point[0] * (size + gap),
              top: point[1] * (size + gap),
              child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                      painter: SimpleCubePainter(
                    color: shapeData.color,
                  ))),
            );
          }).toList(),
        ),
      );
    }

    return Draggable<Map<String, dynamic>>(
      data: {'shape': shapeData, 'index': shapeIndex},
      onDragStarted: onDragStarted,
      onDragUpdate: (details) => onDragUpdate(details.globalPosition),
      onDragEnd: (details) => onDragEnd(details.offset),
      feedback: Transform.translate(
        offset: Offset(-baseCellSize / 2, -baseCellSize / 2),
        child: Material(
          color: Colors.transparent,
          child: Container(
              decoration: BoxDecoration(boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 10))
              ]),
              child: buildShape(baseCellSize, 2.0)),
        ),
      ),
      child: buildShape(displayCellSize, 1),
      childWhenDragging:
          Opacity(opacity: 0.0, child: buildShape(displayCellSize, 1)),
    );
  }
}

class BouncingScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const BouncingScaleButton(
      {super.key, required this.child, required this.onTap});
  @override
  State<BouncingScaleButton> createState() => _BouncingScaleButtonState();
}

class _BouncingScaleButtonState extends State<BouncingScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: widget.child,
      ),
    );
  }
}
