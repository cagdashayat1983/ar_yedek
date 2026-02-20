// lib/screens/templates_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category_model.dart';
import 'drawing_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';

class DesignItem {
  final String path;
  int likes;
  bool isLiked;
  bool isSaved;
  bool isPremium;

  DesignItem({
    required this.path,
    this.likes = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isPremium = false,
  });
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

  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _isProUser = false;

  final int _pageSize = 18;
  int _page = 1;

  List<DesignItem> _all = [];
  List<DesignItem> _shown = [];

  static final RegExp _imgExt =
      RegExp(r'\.(webp|png|jpg|jpeg)$', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    _init();
    _scroll.addListener(_onScroll);
    _search.addListener(_apply);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      _prefs = await SharedPreferences.getInstance();
      _isProUser = _prefs.getBool('is_pro_user') ?? false;

      await _loadAssetsAuto();
      _apply();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAssetsAuto() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();

    final folder = widget.category.templateFolder.trim().toLowerCase();
    final folderPrefix = "assets/templates/$folder/";

    final paths = allAssets
        .where((p) => p.startsWith(folderPrefix))
        .where((p) => _imgExt.hasMatch(p))
        .toList()
      ..sort();

    final List<DesignItem> items = [];
    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];

      final liked = _prefs.getBool('liked_$p') ?? false;
      final saved = _prefs.getBool('saved_$p') ?? false;
      final likes = _prefs.getInt('likes_$p') ?? 0;

      final premium = i >= 6;

      items.add(
        DesignItem(
          path: p,
          likes: likes,
          isLiked: liked,
          isSaved: saved,
          isPremium: premium,
        ),
      );
    }

    _all = items;
    _page = 1;
    _shown = _all.take(_pageSize).toList();
  }

  void _apply() {
    final q = _search.text.trim().toLowerCase();

    final filtered = _all.where((d) {
      if (q.isEmpty) return true;
      final name = d.path.split('/').last.toLowerCase();
      return name.contains(q);
    }).toList();

    final max = _page * _pageSize;
    setState(() => _shown = filtered.take(max).toList());
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 250 &&
        !_loadingMore &&
        !_loading) {
      _more();
    }
  }

  Future<void> _more() async {
    setState(() => _loadingMore = true);
    await Future.delayed(const Duration(milliseconds: 200));
    _page++;
    _apply();
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F7FB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          widget.category.title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: "Şablon ara…",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _shown.isEmpty
                      ? Center(
                          child: Text(
                            "Bu kategoride şablon yok.",
                            style: GoogleFonts.poppins(color: Colors.black54),
                          ),
                        )
                      : GridView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _shown.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemBuilder: (_, i) {
                            final item = _shown[i];
                            final locked = item.isPremium && !_isProUser;

                            return InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                if (locked) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SubscriptionScreen(),
                                    ),
                                  ).then((_) => _init());
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DrawingScreen(
                                      category: widget.category,
                                      cameras: widget.cameras,
                                      imagePath: item.path,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  color: Colors.white,
                                  border: Border.all(
                                    color:
                                        widget.category.color.withOpacity(0.12),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    )
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Image.asset(
                                          item.path,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: widget.category.color
                                                .withOpacity(0.10),
                                            alignment: Alignment.center,
                                            child: const Icon(Icons
                                                .image_not_supported_outlined),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        // Kenar boşlukları (RenderFlex hatası için optimize edildi)
                                        left: 4,
                                        right: 4,
                                        bottom: 4,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // SOL TARAFTAKİ BUTONLAR (BEĞENİ + KAYDET)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _pill(
                                                  child: InkWell(
                                                    onTap: () async {
                                                      setState(() {
                                                        item.isLiked =
                                                            !item.isLiked;
                                                        item.likes +=
                                                            item.isLiked
                                                                ? 1
                                                                : -1;
                                                      });
                                                      await _prefs.setBool(
                                                          'liked_${item.path}',
                                                          item.isLiked);
                                                      await _prefs.setInt(
                                                          'likes_${item.path}',
                                                          item.likes);
                                                    },
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          item.isLiked
                                                              ? Icons.favorite
                                                              : Icons
                                                                  .favorite_border,
                                                          size: 14,
                                                          color: item.isLiked
                                                              ? Colors.red
                                                              : Colors.white,
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          "${item.likes}",
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                _pill(
                                                  child: InkWell(
                                                    onTap: () async {
                                                      setState(() =>
                                                          item.isSaved =
                                                              !item.isSaved);
                                                      await _prefs.setBool(
                                                          'saved_${item.path}',
                                                          item.isSaved);
                                                    },
                                                    child: Icon(
                                                      item.isSaved
                                                          ? Icons.bookmark
                                                          : Icons
                                                              .bookmark_border,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // --- DEĞİŞİKLİK BURADA ---
                                            // SAĞ TARAFTAKİ TAÇ (PRO) İŞARETİ
                                            if (locked)
                                              _pill(
                                                child: Row(
                                                  children: [
                                                    // Kilit yerine Taç (Premium) ikonu
                                                    const Icon(
                                                      Icons
                                                          .workspace_premium_rounded,
                                                      color: Colors
                                                          .amber, // Altın sarısı renk
                                                      size: 15,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "PRO",
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            // ---------------------------
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          } else if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: widget.category.color,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: "Şablonlar"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: "Hesabım"),
          BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_rounded), label: "PRO"),
          BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded), label: "Diğer"),
        ],
      ),
    );
  }

  Widget _pill({required Widget child}) {
    return Container(
      // Paddingler optimize edildi
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
