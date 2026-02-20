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
import 'learn_screen.dart';

class DesignItem {
  final String path;
  final String difficulty;
  int likes;
  bool isLiked;
  bool isSaved;
  bool isPremium;

  DesignItem({
    required this.path,
    required this.difficulty,
    this.likes = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isPremium = false,
  });
}

class TemplatesScreen extends StatefulWidget {
  final CategoryModel category;
  final List<CameraDescription> cameras;

  const TemplatesScreen(
      {super.key, required this.category, required this.cameras});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  late SharedPreferences _prefs;
  final TextEditingController _search = TextEditingController();

  bool _isProUser = false;
  bool _loading = true;
  int _bottomIndex = 0;
  String _selectedTab = "Hepsi";

  // Level Sistemi
  int _userLevel = 1;
  int _currentXp = 0;
  int _requiredXp = 100;

  final List<String> _tabs = ["Hepsi", "Kolay", "Orta", "Zor"];
  List<DesignItem> _all = [];
  List<DesignItem> _shown = [];

  @override
  void initState() {
    super.initState();
    _init();
    _search.addListener(_apply);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      _prefs = await SharedPreferences.getInstance();
      _isProUser = _prefs.getBool('is_pro_user') ?? false;
      _userLevel = _prefs.getInt('user_level') ?? 1;
      _currentXp = _prefs.getInt('user_xp') ?? 0;
      _requiredXp = _userLevel * 100;
      await _loadAssetsAuto();
      _apply();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addXp() async {
    int gain = 20;
    int newXp = _currentXp + gain;
    if (newXp >= _requiredXp) {
      newXp = newXp - _requiredXp;
      _userLevel++;
      _requiredXp = _userLevel * 100;
      _showLevelUpDialog();
    }
    await _prefs.setInt('user_level', _userLevel);
    await _prefs.setInt('user_xp', newXp);
    if (mounted) setState(() => _currentXp = newXp);
  }

  void _showLevelUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, size: 60, color: Colors.amber),
              const SizedBox(height: 10),
              Text("TEBRİKLER!",
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text("Seviye $_userLevel oldun!",
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Harika!",
                    style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadAssetsAuto() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();
    final folder = widget.category.templateFolder.trim().toLowerCase();
    final folderPrefix = "assets/templates/$folder/";

    final paths = allAssets
        .where((p) => p.startsWith(folderPrefix))
        .where((p) =>
            p.endsWith(".png") || p.endsWith(".jpg") || p.endsWith(".webp"))
        .toList()
      ..sort();

    final List<DesignItem> items = [];
    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];
      final fileName = p.split('/').last.toLowerCase();
      String diff = "Kolay";
      if (fileName.contains("medium") || fileName.contains("orta"))
        diff = "Orta";
      else if (fileName.contains("hard") || fileName.contains("zor"))
        diff = "Zor";

      items.add(DesignItem(
        path: p,
        difficulty: diff,
        likes: _prefs.getInt('likes_$p') ?? (i * 3 + 5),
        isLiked: _prefs.getBool('liked_$p') ?? false,
        isSaved: _prefs.getBool('saved_$p') ?? false,
        isPremium: i >= 6,
      ));
    }
    _all = items;
  }

  void _apply() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _shown = _all.where((d) {
        final matchesSearch = d.path.split('/').last.toLowerCase().contains(q);
        final matchesTab =
            _selectedTab == "Hepsi" || d.difficulty == _selectedTab;
        return matchesSearch && matchesTab;
      }).toList();
    });
  }

  void _onBottomTap(int i) {
    if (i == 0) {
      Navigator.pop(context);
      return;
    }
    if (i == 1) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LearnScreen(cameras: widget.cameras)));
    } else if (i == 2) {
      Navigator.push(
              context, MaterialPageRoute(builder: (_) => SubscriptionScreen()))
          .then((_) => _init());
    } else if (i == 3) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ProfileScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: widget.category.color, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.category.title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                fontSize: 20)),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: widget.category.color))
          : Column(
              children: [
                // 1. LEVEL BAR
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
                  child: Column(
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Seviye $_userLevel",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.black)),
                            Text("$_currentXp / $_requiredXp XP",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.grey)),
                          ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                              value: _currentXp / _requiredXp,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  widget.category.color),
                              minHeight: 8)),
                    ],
                  ),
                ),

                // 2. SEARCH BAR
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
                    child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            const BoxShadow(
                                color: Colors.white,
                                offset: Offset(-5, -5),
                                blurRadius: 10),
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                offset: const Offset(5, 5),
                                blurRadius: 10),
                          ],
                        ),
                        child: TextField(
                            controller: _search,
                            decoration: InputDecoration(
                                hintText: "Şablonlarda ara...",
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: widget.category.color),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15))))),

                // 3. TABS (ListView)
                Container(
                  height: 45,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        final tab = _tabs[index];
                        return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: GestureDetector(
                                onTap: () {
                                  setState(() => _selectedTab = tab);
                                  _apply();
                                },
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    decoration: BoxDecoration(
                                        color: _selectedTab == tab
                                            ? widget.category.color
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: _selectedTab == tab
                                            ? []
                                            : [
                                                const BoxShadow(
                                                    color: Colors.white,
                                                    offset: Offset(-3, -3),
                                                    blurRadius: 5),
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.04),
                                                    offset: const Offset(3, 3),
                                                    blurRadius: 5)
                                              ]),
                                    child: Center(
                                        child: Text(tab,
                                            style: GoogleFonts.poppins(
                                                color: _selectedTab == tab
                                                    ? Colors.white
                                                    : Colors.grey.shade700,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13))))));
                      }),
                ),

                // 4. GRID ALANI (Expanded + GridView.builder)
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _shown.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 22,
                            childAspectRatio: 0.8),
                    itemBuilder: (_, i) {
                      final item = _shown[i];
                      final locked = item.isPremium;
                      return Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              const BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-5, -5),
                                  blurRadius: 8),
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  offset: const Offset(5, 5),
                                  blurRadius: 8)
                            ]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            children: [
                              // Resim Alanı
                              Expanded(
                                flex: 5,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (locked && !_isProUser) {
                                      Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      SubscriptionScreen()))
                                          .then((_) => _init());
                                      return;
                                    }
                                    final DateTime startTime = DateTime.now();
                                    Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => DrawingScreen(
                                                    category: widget.category,
                                                    cameras: widget.cameras,
                                                    imagePath: item.path)))
                                        .then((_) {
                                      final DateTime endTime = DateTime.now();
                                      if (endTime
                                              .difference(startTime)
                                              .inSeconds >=
                                          10) _addXp();
                                    });
                                  },
                                  child: Stack(
                                    children: [
                                      Center(
                                          child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Image.asset(item.path,
                                                  fit: BoxFit.contain))),
                                      Positioned(
                                          top: 0,
                                          left: 0,
                                          child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                  color: widget.category.color
                                                      .withOpacity(0.9),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                          bottomRight:
                                                              Radius.circular(
                                                                  15))),
                                              child: Text(
                                                  item.difficulty.toUpperCase(),
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white)))),
                                      if (locked)
                                        const Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Icon(
                                                Icons.workspace_premium_rounded,
                                                color: Colors.amber,
                                                size: 18)),
                                    ],
                                  ),
                                ),
                              ),
                              // Beğeni/Kaydet Paneli
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.06)),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                        onTap: () async {
                                          setState(() {
                                            item.isLiked = !item.isLiked;
                                            item.likes += item.isLiked ? 1 : -1;
                                          });
                                          await _prefs.setBool(
                                              'liked_${item.path}',
                                              item.isLiked);
                                          await _prefs.setInt(
                                              'likes_${item.path}', item.likes);
                                        },
                                        child: Row(children: [
                                          Icon(
                                              item.isLiked
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                      .favorite_border_rounded,
                                              size: 18,
                                              color: item.isLiked
                                                  ? Colors.redAccent
                                                  : Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text("${item.likes}",
                                              style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700))
                                        ])),
                                    GestureDetector(
                                        onTap: () async {
                                          setState(() =>
                                              item.isSaved = !item.isSaved);
                                          await _prefs.setBool(
                                              'saved_${item.path}',
                                              item.isSaved);
                                        },
                                        child: Icon(
                                            item.isSaved
                                                ? Icons.bookmark_rounded
                                                : Icons.bookmark_border_rounded,
                                            size: 18,
                                            color: item.isSaved
                                                ? widget.category.color
                                                : Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: _onBottomTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle:
            GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle:
            GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: "Şablonlar"),
          BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded), label: "Öğren"),
          BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_rounded), label: "PRO"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: "Hesabım")
        ],
      ),
    );
  }
}
