// lib/screens/templates_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../services/subscription_service.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';

import 'profile_screen.dart';
import 'subscription_screen.dart';
import 'learn_screen.dart';
import 'home_screen.dart';
import 'ios_ar_sayfasi.dart';
import 'ar_mini_test_screen.dart';
import 'image_to_sketch_screen.dart';
import 'tutorial_screen.dart';

class DesignItem {
  final String path;
  final String difficultyKey;
  int likes;
  bool isLiked;
  bool isSaved;
  bool isPremium;

  DesignItem({
    required this.path,
    required this.difficultyKey,
    this.likes = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isPremium = false,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'difficultyKey': difficultyKey,
        'isPremium': isPremium,
      };

  factory DesignItem.fromJson(
    Map<String, dynamic> json,
    SharedPreferences prefs,
    int index,
  ) {
    final String p = json['path']?.toString() ?? '';
    return DesignItem(
      path: p,
      difficultyKey: json['difficultyKey']?.toString() ?? 'easy',
      isPremium: json['isPremium'] == true,
      likes: prefs.getInt('likes_$p') ?? (index * 2 + 10),
      isLiked: prefs.getBool('liked_$p') ?? false,
      isSaved: prefs.getBool('saved_$p') ?? false,
    );
  }
}

class TemplatesScreen extends StatefulWidget {
  final CategoryModel category;
  final List<CameraDescription> cameras;

  const TemplatesScreen({
    super.key,
    required this.category,
    required this.cameras,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  late SharedPreferences _prefs;

  bool _prefsReady = false;
  bool _isProUser = false;
  bool _loading = true;
  bool _usingCachedData = false;
  String? _errorMessage;
  int? _lastSyncedAtMs;

  int _currentEnergy = 0;
  final int _bottomIndex = 0;

  String _selectedTabKey = 'all';
  String _selectedSortKey = 'newest';

  List<DesignItem> _all = [];
  List<DesignItem> _shown = [];

  final String workerUrl = 'https://hayatify-api.cagdasyucedag.workers.dev';

  String get _folder => widget.category.templateFolder.toLowerCase().trim();

  // ✅ Cache versiyonu artırıldı ki eski yanlış premium/free kayıtları silinsin
  String get _cacheKey => 'cache_templates_v4_$_folder';
  String get _cacheSyncKey => 'cache_templates_sync_v4_$_folder';

  @override
  void initState() {
    super.initState();
    _init();
  }

  bool _isTurkish(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'tr';
  }

  String _txt(BuildContext context, String tr, String en) {
    return _isTurkish(context) ? tr : en;
  }

  Future<void> _init() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      _prefs = await SharedPreferences.getInstance();
      _prefsReady = true;
      _lastSyncedAtMs = _prefs.getInt(_cacheSyncKey);
      _isProUser = await SubscriptionService.isProUser();

      _currentEnergy = await EnergyService.getEnergy();

      await _loadAssetsFromCloud();
    } catch (e, st) {
      debugPrint('❌ Init error: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _txt(
          context,
          'Bir şeyler ters gitti.',
          'Something went wrong.',
        );
      });
    }
  }

  Future<void> _refreshAll() async {
    HapticFeedback.lightImpact();
    await _checkSubscriptionStatus();
    await _loadAssetsFromCloud(forceRefresh: true);
  }

  Future<void> _checkSubscriptionStatus() async {
    final bool status = await SubscriptionService.isProUser();
    final int energy = await EnergyService.getEnergy();
    if (!mounted) return;
    setState(() {
      _isProUser = status;
      _currentEnergy = energy;
    });
    _apply();
  }

  Future<void> _handleTemplateTap(
    DesignItem item,
    AppLocalizations l10n,
  ) async {
    if (_isProUser) {
      _showDrawOptions(item, l10n);
      return;
    }

    // ✅ Ücretsizler enerji harcamaz
    if (!item.isPremium) {
      _showDrawOptions(item, l10n);
      return;
    }

    _showPremiumUpsellSheet(item, l10n);
  }

  void _showEnergyEmptyDialog(DesignItem item, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFD97706),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _txt(context, 'Enerjin Bitti!', 'Out of Energy!'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _txt(
                      context,
                      'Çizime devam etmek için kısa bir video izle ve 3 Enerji kazan.',
                      'Watch a short video to get 3 Energy and keep drawing.',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _playRewardedAdAndContinue(item, l10n);
                      },
                      icon: const Icon(Icons.play_circle_filled_rounded),
                      label: Text(
                        _txt(context, 'Video İzle (+3 ⚡)', 'Watch Ad (+3 ⚡)'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _openSubscriptionFlow();
                    },
                    child: Text(
                      _txt(context, 'Reklamları Kaldır (Pro)',
                          'Remove Ads (Pro)'),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playRewardedAdAndContinue(DesignItem item, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    AdService.showRewardedAd(
      onReward: () async {
        Navigator.pop(context);

        await EnergyService.rewardEnergy(3);
        final updatedEnergy = await EnergyService.getEnergy();

        if (!mounted) return;
        setState(() => _currentEnergy = updatedEnergy);

        await EnergyService.consumeEnergy();
        final afterConsumeEnergy = await EnergyService.getEnergy();

        if (!mounted) return;
        setState(() => _currentEnergy = afterConsumeEnergy);

        _showDrawOptions(item, l10n);
      },
      onFailed: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _txt(
                context,
                'Reklam şu an hazır değil, lütfen biraz bekle.',
                'Ad is not ready yet, please wait.',
              ),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      },
    );
  }

  Uri _buildListUri(String folder) {
    return Uri.parse(workerUrl).replace(
      queryParameters: {'folder': folder},
    );
  }

  Uri _buildImageUri({
    required String folder,
    required String fileName,
  }) {
    return Uri.parse(workerUrl).replace(
      path: '/image',
      queryParameters: {
        'folder': folder,
        'file': fileName,
      },
    );
  }

  String _difficultyFromFileName(String lowerName) {
    if (RegExp(r'(^|[_\-\s])hard([_\-\s.]|$)').hasMatch(lowerName)) {
      return 'hard';
    }
    if (RegExp(r'(^|[_\-\s])medium([_\-\s.]|$)').hasMatch(lowerName)) {
      return 'medium';
    }
    return 'easy';
  }

  // ✅ Premium algılama düzeltildi
  bool _isPremiumFromFileName(String fileName) {
    final String name =
        Uri.decodeComponent(fileName).split('/').last.toLowerCase().trim();

    // En güvenli kontrol: başta pro_/premium_ varsa direkt premium
    if (name.startsWith('pro_') ||
        name.startsWith('pro-') ||
        name.startsWith('premium_') ||
        name.startsWith('premium-')) {
      return true;
    }

    // Ek güvenlik: parça olarak geçiyorsa da premium say
    if (RegExp(r'(^|[_\-\s])pro([_\-\s.]|$)', caseSensitive: false)
            .hasMatch(name) ||
        RegExp(r'(^|[_\-\s])premium([_\-\s.]|$)', caseSensitive: false)
            .hasMatch(name)) {
      return true;
    }

    return false;
  }

  Future<void> _loadAssetsFromCloud({bool forceRefresh = false}) async {
    final bool hadVisibleData = _all.isNotEmpty;

    if (!forceRefresh) {
      await _loadFromCache();
    }

    try {
      final Uri requestUri = _buildListUri(_folder);
      final response = await http.get(requestUri).timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode != 200) {
        throw Exception('Unexpected status: ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) {
        throw Exception('Invalid response format');
      }

      final List<DesignItem> newItems = [];

      for (int i = 0; i < decoded.length; i++) {
        final String originalFileName = decoded[i].toString().trim();
        if (originalFileName.isEmpty) continue;

        final String lowerName = originalFileName.toLowerCase();

        final Uri fullUri = _buildImageUri(
          folder: _folder,
          fileName: originalFileName,
        );

        final String fullPath = fullUri.toString();

        // ✅ Artık pro_medium_humanp1_06.png gibi isimleri doğru yakalar
        final bool isProImage = _isPremiumFromFileName(originalFileName);

        newItems.add(
          DesignItem(
            path: fullPath,
            difficultyKey: _difficultyFromFileName(lowerName),
            likes: _prefs.getInt('likes_$fullPath') ?? (i * 2 + 10),
            isLiked: _prefs.getBool('liked_$fullPath') ?? false,
            isSaved: _prefs.getBool('saved_$fullPath') ?? false,
            isPremium: isProImage,
          ),
        );
      }

      await _prefs.setString(
        _cacheKey,
        json.encode(newItems.map((e) => e.toJson()).toList()),
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await _prefs.setInt(_cacheSyncKey, now);

      if (!mounted) return;
      setState(() {
        _all = newItems;
        _loading = false;
        _usingCachedData = false;
        _errorMessage = null;
        _lastSyncedAtMs = now;
      });
      _apply();
    } catch (e, st) {
      debugPrint('❌ Bulut Hatası: $e');
      debugPrint('$st');

      if (!mounted) return;

      if (_all.isNotEmpty) {
        setState(() {
          _loading = false;
          _usingCachedData = true;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _loading = false;
          _usingCachedData = false;
          _errorMessage = _txt(
            context,
            'Şablonlar yüklenemedi. İnternetini kontrol edip tekrar dene.',
            'Templates could not be loaded. Check your connection and try again.',
          );
        });
      }

      if (!hadVisibleData && _all.isNotEmpty) {
        _apply();
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final String? cachedData = _prefs.getString(_cacheKey);
      if (cachedData == null) return;

      final List decoded = json.decode(cachedData);
      final List<DesignItem> cachedItems = [];

      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] is Map<String, dynamic>) {
          cachedItems.add(DesignItem.fromJson(decoded[i], _prefs, i));
        } else if (decoded[i] is Map) {
          cachedItems.add(
            DesignItem.fromJson(
              Map<String, dynamic>.from(decoded[i]),
              _prefs,
              i,
            ),
          );
        }
      }

      if (!mounted || cachedItems.isEmpty) return;

      setState(() {
        _all = cachedItems;
        _loading = false;
        _usingCachedData = true;
      });
      _apply();
    } catch (e) {
      debugPrint('Cache okuma hatası: $e');
    }
  }

  void _apply() {
    if (!mounted) return;

    final List<DesignItem> filtered = _all.where((d) {
      return _selectedTabKey == 'all' || d.difficultyKey == _selectedTabKey;
    }).toList();

    filtered.sort((a, b) {
      if (a.isPremium != b.isPremium) {
        return a.isPremium ? 1 : -1;
      }

      if (_selectedSortKey == 'newest') {
        return _fileNameFromPath(b.path).compareTo(_fileNameFromPath(a.path));
      } else if (_selectedSortKey == 'oldest') {
        return _fileNameFromPath(a.path).compareTo(_fileNameFromPath(b.path));
      } else if (_selectedSortKey == 'popular') {
        return b.likes.compareTo(a.likes);
      }
      return 0;
    });

    setState(() => _shown = filtered);
  }

  Future<void> _toggleLike(DesignItem item) async {
    if (!_prefsReady) return;

    HapticFeedback.selectionClick();

    if (item.isLiked) {
      item.isLiked = false;
      item.likes = item.likes > 0 ? item.likes - 1 : 0;
    } else {
      item.isLiked = true;
      item.likes += 1;
    }

    await _prefs.setBool('liked_${item.path}', item.isLiked);
    await _prefs.setInt('likes_${item.path}', item.likes);

    _apply();
  }

  Future<void> _toggleSave(DesignItem item) async {
    if (!_prefsReady) return;

    HapticFeedback.selectionClick();

    item.isSaved = !item.isSaved;
    await _prefs.setBool('saved_${item.path}', item.isSaved);

    if (!mounted) return;
    setState(() {});
  }

  String _fileNameFromPath(String path) {
    try {
      final uri = Uri.parse(path);
      final file = uri.queryParameters['file'];
      if (file != null && file.isNotEmpty) return Uri.decodeComponent(file);
    } catch (_) {}
    return path.split('/').last;
  }

  String _beautifyFileName(String path) {
    String name = _fileNameFromPath(path);
    name = Uri.decodeComponent(name);
    name = name.replaceAll(RegExp(r'\.[^.]+$'), '');

    // baştaki pro_/premium_ temizle
    name = name.replaceFirst(
      RegExp(r'^(pro|premium)[_\-\s]+', caseSensitive: false),
      '',
    );

    // difficulty etiketlerini temizle
    name = name.replaceAll(
      RegExp(
        r'(^|[_\-\s])(easy|medium|hard)(?=[_\-\s]|$)',
        caseSensitive: false,
      ),
      ' ',
    );

    name = name.replaceAll(RegExp(r'[_\-]+'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (name.isEmpty) {
      return _txt(context, 'Çizim Şablonu', 'Drawing Template');
    }

    return name
        .split(' ')
        .where((e) => e.trim().isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _difficultyLabel(String key, AppLocalizations l10n) {
    final bool isTr = _isTurkish(context);
    switch (key) {
      case 'medium':
        return isTr ? 'ORTA' : 'MED';
      case 'hard':
        return isTr ? 'ZOR' : 'HARD';
      default:
        return isTr ? 'KOLAY' : 'EASY';
    }
  }

  Color _difficultyColor(String key) {
    switch (key) {
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _statusText() {
    if (_usingCachedData) {
      return _txt(
        context,
        'Çevrimdışı önbellek gösteriliyor',
        'Showing cached offline data',
      );
    }

    if (_lastSyncedAtMs == null) {
      return _txt(context, 'Yeni güncellendi', 'Updated recently');
    }

    final DateTime syncTime =
        DateTime.fromMillisecondsSinceEpoch(_lastSyncedAtMs!);
    final Duration diff = DateTime.now().difference(syncTime);

    if (diff.inMinutes < 1) {
      return _txt(context, 'Az önce güncellendi', 'Updated just now');
    }
    if (diff.inHours < 1) {
      return _txt(
        context,
        '${diff.inMinutes} dk önce güncellendi',
        'Updated ${diff.inMinutes} min ago',
      );
    }
    if (diff.inDays < 1) {
      return _txt(
        context,
        '${diff.inHours} saat önce güncellendi',
        'Updated ${diff.inHours} h ago',
      );
    }

    return _txt(
      context,
      '${diff.inDays} gün önce güncellendi',
      'Updated ${diff.inDays} d ago',
    );
  }

  Future<void> _openSubscriptionFlow() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    await _checkSubscriptionStatus();
  }

  void _pickFromGallery(AppLocalizations l10n) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                Text(
                  l10n.startDrawing,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _txt(
                    context,
                    'Kendi fotoğrafınla çizime başla',
                    'Start drawing with your own photo',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 22),
                _buildGalleryOptionTile(
                  icon: Icons.auto_fix_high_rounded,
                  color: const Color(0xFF3B82F6),
                  title: l10n.sketchTemplate,
                  subtitle: l10n.sketchDesc,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImageToSketchScreen(
                          cameras: widget.cameras,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildGalleryOptionTile(
                  icon: Icons.photo_rounded,
                  color: const Color(0xFFF59E0B),
                  title: l10n.originalPhoto,
                  subtitle: l10n.originalDesc,
                  onTap: () async {
                    Navigator.pop(context);

                    final XFile? image = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 95,
                    );

                    if (image != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TutorialScreen(
                            title: l10n.originalPhoto,
                            imagePaths: [image.path],
                            cameras: widget.cameras,
                            isLocalFile: true,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPremiumUpsellSheet(DesignItem item, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.grey,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: widget.category.color.withValues(alpha: 0.10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: CachedNetworkImage(
                    imageUrl: item.path,
                    fit: BoxFit.contain,
                    memCacheWidth: 220,
                    placeholder: (_, __) => Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.category.color,
                      ),
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      widget.category.icon,
                      color: widget.category.color,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _txt(context, 'Bu şablon Pro’ya özel',
                      'This template is Pro only'),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _txt(
                    context,
                    'Premium şablonları açmak için Pro\'ya geçebilir veya 1 Enerji harcayabilirsin.',
                    'Upgrade to Pro to unlock premium templates, or use 1 Energy.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (_currentEnergy > 0) {
                        await EnergyService.consumeEnergy();
                        final updatedEnergy = await EnergyService.getEnergy();
                        if (!mounted) return;
                        setState(() => _currentEnergy = updatedEnergy);
                        _showDrawOptions(item, l10n);
                      } else {
                        _showEnergyEmptyDialog(item, l10n);
                      }
                    },
                    icon: Icon(
                      _currentEnergy > 0
                          ? Icons.bolt_rounded
                          : Icons.play_circle_filled_rounded,
                    ),
                    label: Text(
                      _currentEnergy > 0
                          ? _txt(context, '⚡ 1 Enerji Harca ve Çiz',
                              '⚡ Use 1 Energy')
                          : _txt(context, '📺 Video İzle ve Aç',
                              '📺 Watch Ad to Unlock'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _openSubscriptionFlow();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _txt(context, '💎 Pro\'ya Geç (Sınırsız)',
                          '💎 Get Pro (Unlimited)'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDrawOptions(DesignItem item, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: widget.category.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: CachedNetworkImage(
                        imageUrl: item.path,
                        fit: BoxFit.contain,
                        memCacheWidth: 220,
                        placeholder: (_, __) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.category.color,
                          ),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          widget.category.icon,
                          color: widget.category.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _beautifyFileName(item.path),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _txt(
                              context,
                              'Nasıl başlamak istediğini seç',
                              'Choose how you want to start',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _buildGalleryOptionTile(
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF3B82F6),
                  title: _txt(context, 'Normal Mod', 'Normal Mode'),
                  subtitle: l10n.onb1Desc,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TutorialScreen(
                          title: widget.category.getLocalizedTitle(context),
                          imagePaths: [item.path],
                          cameras: widget.cameras,
                          isLocalFile: false,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildGalleryOptionTile(
                  icon: Icons.view_in_ar_rounded,
                  color: const Color(0xFF8B5CF6),
                  title: _txt(context, 'AR Mod', 'AR Mode'),
                  subtitle: _txt(
                    context,
                    'Kamerada artırılmış gerçeklik deneyimi',
                    'Augmented reality drawing experience',
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    final String targetGlbPath = item.path
                        .replaceFirst('/image?', '/model?')
                        .replaceAll('.png', '.glb')
                        .replaceAll('.jpg', '.glb')
                        .replaceAll('.jpeg', '.glb');

                    if (Platform.isIOS) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IosArSayfasi(imagePath: item.path),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ARMiniTestScreen(
                            glbAssetPath: targetGlbPath,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard(AppLocalizations l10n) {
    final int totalCount = _all.length;
    final int visibleCount = _shown.length;
    final int premiumCount = _all.where((e) => e.isPremium).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.category.color.withValues(alpha: 0.95),
              widget.category.color.withValues(alpha: 0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: widget.category.color.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                widget.category.icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category.getLocalizedTitle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _txt(
                      context,
                      'Şablon seç, modu belirle ve hemen çizmeye başla.',
                      'Pick a template, choose a mode and start drawing instantly.',
                    ),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoPill(
                        icon: Icons.grid_view_rounded,
                        label:
                            '$totalCount ${_txt(context, "şablon", "templates")}',
                      ),
                      _buildInfoPill(
                        icon: Icons.filter_alt_rounded,
                        label:
                            '$visibleCount ${_txt(context, "gösteriliyor", "showing")}',
                      ),
                      if (!_isProUser && premiumCount > 0)
                        _buildInfoPill(
                          icon: Icons.workspace_premium_rounded,
                          label: '$premiumCount PRO',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _usingCachedData
              ? const Color(0xFFFFFBEB)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _usingCachedData
                ? const Color(0xFFFCD34D)
                : const Color(0xFFBFDBFE),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _usingCachedData
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_done_rounded,
              color: _usingCachedData
                  ? const Color(0xFFD97706)
                  : const Color(0xFF2563EB),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _statusText(),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _txt(context, 'Zorluk Filtresi', 'Difficulty Filter'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          _buildTabs(l10n),
          const SizedBox(height: 16),
          Text(
            l10n.sort,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          _buildSortChips(l10n),
        ],
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l10n) {
    final Map<String, String> tabs = {
      'all': _txt(context, 'Tümü', 'All'),
      'easy': l10n.difficultyEasy,
      'medium': l10n.difficultyMedium,
      'hard': l10n.difficultyHard,
    };

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final entry = tabs.entries.elementAt(index);
          final bool isSelected = _selectedTabKey == entry.key;

          return ChoiceChip(
            label: Text(entry.value),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (selected) {
              if (!selected) return;
              HapticFeedback.selectionClick();
              setState(() => _selectedTabKey = entry.key);
              _apply();
            },
            selectedColor: widget.category.color,
            backgroundColor: Colors.white,
            side: BorderSide(
              color:
                  isSelected ? widget.category.color : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            labelStyle: GoogleFonts.poppins(
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortChips(AppLocalizations l10n) {
    final Map<String, String> sorts = {
      'newest': l10n.newest,
      'oldest': l10n.oldest,
      'popular': l10n.popular,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorts.entries.map((entry) {
        final bool isSelected = _selectedSortKey == entry.key;

        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (selected) {
            if (!selected) return;
            HapticFeedback.selectionClick();
            setState(() => _selectedSortKey = entry.key);
            _apply();
          },
          selectedColor: const Color(0xFF111827),
          backgroundColor: Colors.white,
          side: BorderSide(
            color:
                isSelected ? const Color(0xFF111827) : const Color(0xFFE2E8F0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          labelStyle: GoogleFonts.poppins(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResponsiveGrid(
    AppLocalizations l10n, {
    required bool loadingPlaceholders,
  }) {
    final int itemCount = loadingPlaceholders ? 6 : _shown.length;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.crossAxisExtent - 40;
        int crossAxisCount = 2;

        if (width >= 1100) {
          crossAxisCount = 5;
        } else if (width >= 800) {
          crossAxisCount = 4;
        } else if (width >= 560) {
          crossAxisCount = 3;
        }

        const spacing = 16.0;
        final double itemWidth =
            (width - ((crossAxisCount - 1) * spacing)) / crossAxisCount;
        final double childAspectRatio = itemWidth / (itemWidth + 78);

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 90),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (loadingPlaceholders) {
                  return _buildLoadingCard();
                }
                final item = _shown[index];
                return _buildGridCard(item, l10n);
              },
              childCount: itemCount,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridCard(DesignItem item, AppLocalizations l10n) {
    final bool locked = item.isPremium && !_isProUser;
    final Color diffColor = _difficultyColor(item.difficultyKey);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _handleTemplateTap(item, l10n),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: locked ? const Color(0xFFFFE7B0) : const Color(0xFFEAEFF6),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: item.path,
                            memCacheWidth: 500,
                            fadeInDuration: const Duration(milliseconds: 180),
                            imageBuilder: (context, imageProvider) => Image(
                              image: imageProvider,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.category.color,
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: widget.category.color,
                                  size: 26,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _buildRoundIconButton(
                        icon: item.isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        iconColor: item.isSaved
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                        onTap: () => _toggleSave(item),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: locked
                          ? _buildBadge(
                              text: 'PRO',
                              bg: const Color(0xFFFFFBEB),
                              fg: const Color(0xFFD97706),
                            )
                          : _buildBadge(
                              text: _difficultyLabel(item.difficultyKey, l10n),
                              bg: diffColor.withValues(alpha: 0.12),
                              fg: diffColor,
                            ),
                    ),
                    if (locked)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [
                                Colors.black.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike(item),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: item.isLiked
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 15,
                              color: item.isLiked
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${item.likes}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      locked
                          ? _txt(context, 'Pro ile aç', 'Unlock with Pro')
                          : _txt(context, 'Başlat', 'Start'),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: locked
                            ? const Color(0xFFD97706)
                            : widget.category.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      locked
                          ? Icons.lock_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: locked
                          ? const Color(0xFFD97706)
                          : widget.category.color,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAEFF6)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Center(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 28,
                width: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 46,
                color: widget.category.color,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage ??
                    _txt(context, 'Bir hata oluştu', 'Something went wrong'),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  _txt(context, 'Tekrar Dene', 'Try Again'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.category.icon,
                size: 44,
                color: widget.category.color,
              ),
              const SizedBox(height: 14),
              Text(
                _txt(
                  context,
                  'Bu kategoride henüz şablon yok',
                  'There are no templates in this category yet',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_alt_off_rounded,
                size: 44,
                color: widget.category.color,
              ),
              const SizedBox(height: 14),
              Text(
                _txt(
                  context,
                  'Bu filtrede sonuç bulunamadı',
                  'No results found for this filter',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: (i) async {
        if (i == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(cameras: widget.cameras),
            ),
          );
        } else if (i == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LearnScreen(cameras: widget.cameras),
            ),
          );
        } else if (i == 2) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SubscriptionScreen(),
            ),
          );
          await _checkSubscriptionStatus();
        } else if (i == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            ),
          );
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF6366F1),
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
      unselectedLabelStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
      items: [
        _buildNavItem('assets/icons/menu.png', l10n.navHome, 0),
        _buildNavItem('assets/icons/learn.png', l10n.navLearn, 1),
        _buildNavItem('assets/icons/pro.png', l10n.navPro, 2),
        _buildNavItem('assets/icons/profile.png', l10n.navProfile, 3),
      ],
    );
  }

  BottomNavigationBarItem _buildNavItem(String path, String label, int index) {
    final bool isSelected = _bottomIndex == index;

    return BottomNavigationBarItem(
      icon: Opacity(
        opacity: isSelected ? 1.0 : 0.5,
        child: Image.asset(path, width: 24, height: 24),
      ),
      label: label,
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildGalleryOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        height: 1.35,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8B5CF6)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundIconButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: fg,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FC),
        surfaceTintColor: const Color(0xFFF6F8FC),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: widget.category.color,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.getLocalizedTitle(context),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_isProUser)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFD97706),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_currentEnergy',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFD97706),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: _refreshAll,
            icon: Icon(
              Icons.refresh_rounded,
              color: widget.category.color,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickFromGallery(l10n),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: Text(
          l10n.drawYourPhoto,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: widget.category.color,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _buildOverviewCard(l10n),
            ),
            if (_usingCachedData ||
                (!_usingCachedData && _lastSyncedAtMs != null))
              SliverToBoxAdapter(
                child: _buildStatusBanner(),
              ),
            SliverToBoxAdapter(
              child: _buildControlsSection(l10n),
            ),
            if (_loading && _all.isEmpty)
              _buildResponsiveGrid(l10n, loadingPlaceholders: true)
            else if (_errorMessage != null && _all.isEmpty)
              _buildErrorState(l10n)
            else if (_all.isEmpty)
              _buildEmptyState()
            else if (_shown.isEmpty)
              _buildEmptyFilterState()
            else
              _buildResponsiveGrid(l10n, loadingPlaceholders: false),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(l10n),
    );
  }
}
