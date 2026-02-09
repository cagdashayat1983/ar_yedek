import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // AssetManifest için
import 'package:shared_preferences/shared_preferences.dart'; // Kayıt işlemleri
import 'package:camera/camera.dart'; // 📸 KAMERA KÜTÜPHANESİ
import 'package:google_fonts/google_fonts.dart';
import '../models/category_model.dart';
import 'drawing_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';

// ✅ Veri Modeli
class DesignItem {
  final String path;
  int likes;
  int saves;
  bool isLiked;
  bool isSaved;
  final DateTime date;
  final bool isPremium;

  DesignItem({
    required this.path,
    required this.likes,
    required this.saves,
    this.isLiked = false,
    this.isSaved = false,
    required this.date,
    required this.isPremium,
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
  List<DesignItem> _allDesignsSource = [];
  List<DesignItem> _filteredFullList = [];
  List<DesignItem> _displayedDesigns = [];

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _isProUser = false;
  String _searchQuery = "";
  String _selectedFilter = "Yeniler";

  int _selectedIndex = 0;
  int _currentLoadedCount = 0;
  static const int _loadIncrement = 12;
  late ScrollController _scrollController;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _initData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore &&
          _displayedDesigns.length < _filteredFullList.length) {
        _loadMoreData();
      }
    }
  }

  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isProUser = _prefs.getBool('is_pro_user') ?? false);
    }

    final manifest =
        await AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context));

    final String searchPath = "assets/templates/${widget.category.id}";

    final paths =
        manifest.listAssets().where((k) => k.contains(searchPath)).where((k) {
      final lower = k.toLowerCase();
      return lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.webp');
    }).toList();

    _allDesignsSource = paths.map((p) {
      bool liked = _prefs.getBool('liked_$p') ?? false;
      bool saved = _prefs.getBool('saved_$p') ?? false;
      int savedLikes =
          _prefs.getInt('count_like_$p') ?? ((p.hashCode % 150) + 10);
      int savedSaves =
          _prefs.getInt('count_save_$p') ?? ((p.hashCode % 80) + 5);
      bool isPro = p.toLowerCase().contains('pro');

      return DesignItem(
        path: p,
        likes: savedLikes,
        saves: savedSaves,
        isLiked: liked,
        isSaved: saved,
        date: DateTime.now().subtract(Duration(days: p.length % 30)),
        isPremium: isPro,
      );
    }).toList();

    _applyFilters(isReset: true);
  }

  Future<void> _toggleInteraction(DesignItem item, String type) async {
    setState(() {
      if (type == 'like') {
        item.isLiked = !item.isLiked;
        item.likes += item.isLiked ? 1 : -1;
        _prefs.setBool('liked_${item.path}', item.isLiked);
        _prefs.setInt('count_like_${item.path}', item.likes);
      } else {
        item.isSaved = !item.isSaved;
        item.saves += item.isSaved ? 1 : -1;
        _prefs.setBool('saved_${item.path}', item.isSaved);
        _prefs.setInt('count_save_${item.path}', item.saves);
      }
    });
  }

  void _applyFilters({bool isReset = false}) {
    if (!mounted) return;
    setState(() {
      if (isReset) _isInitialLoading = true;

      var temp = _allDesignsSource
          .where(
              (d) => d.path.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();

      temp.sort((a, b) {
        if (a.isPremium != b.isPremium) {
          return a.isPremium ? 1 : -1;
        }
        switch (_selectedFilter) {
          case "En Çok Sevilen":
            return b.likes.compareTo(a.likes);
          case "En Çok Kayıt Edilen":
            return b.saves.compareTo(a.saves);
          default:
            return b.date.compareTo(a.date);
        }
      });

      _filteredFullList = temp;

      if (isReset) {
        _currentLoadedCount = 0;
        _displayedDesigns = [];
        _loadNextBatch();
        _isInitialLoading = false;
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
    });
  }

  void _loadNextBatch() {
    final end = (_currentLoadedCount + _loadIncrement)
        .clamp(0, _filteredFullList.length);
    final nextBatch =
        _filteredFullList.getRange(_currentLoadedCount, end).toList();
    setState(() {
      _displayedDesigns.addAll(nextBatch);
      _currentLoadedCount = end;
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 300));
    _loadNextBatch();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  // ✅ GÜNCEL NAVİGASYON (PRO ALTA EKLENDİ)
  void _onBottomNavTapped(int index) {
    if (index == 3) {
      // 3 Numara = Hesabım
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      ).then((_) => _initData());
    } else if (index == 2) {
      // ✅ 2 Numara = PRO (Buraya taşındı)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
      ).then((_) => _initData());
    } else if (index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Video eğitimleri çok yakında!"),
          backgroundColor: widget.category.color,
        ),
      );
      setState(() => _selectedIndex = index);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = widget.category.color;

    return Scaffold(
      backgroundColor: Colors.white,

      // ❌ Sol alttaki FAB (Yuvarlak buton) kaldırıldı.

      appBar: AppBar(
        title: Text("${widget.category.title} (${_allDesignsSource.length})",
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: Colors.black)),
        elevation: 0,
        centerTitle: true,

        // ✅ GERİ TUŞU: Buraya manuel olarak eklendi
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),

        iconTheme: const IconThemeData(color: Colors.black),

        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                themeColor.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,

        // ❌ Sağ üstteki PRO butonu buradan kaldırıldı.
      ),

      // ✅ YENİ ALT MENÜ (4 SEÇENEK)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: themeColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // 4 tane olduğu için Fixed şart
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: "Tasarımlar"),
          BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_fill), label: "Video"),
          // ✅ PRO BURAYA GELDİ
          BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium), label: "PRO"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: "Hesabım"),
        ],
      ),

      body: _isInitialLoading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : Column(
              children: [
                _buildTopBar(themeColor),
                Expanded(
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount:
                        _displayedDesigns.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _displayedDesigns.length && _isLoadingMore) {
                        return Center(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: themeColor)));
                      }

                      final item = _displayedDesigns[index];
                      return _DesignCard(
                        design: item,
                        themeColor: themeColor,
                        onTap: () {
                          if (item.isPremium && !_isProUser) {
                            Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (c) =>
                                            const SubscriptionScreen()))
                                .then((_) => _initData());
                          } else {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) => DrawingScreen(
                                        category: widget.category,
                                        cameras: widget.cameras,
                                        imagePath: item.path)));
                          }
                        },
                        onLike: () => _toggleInteraction(item, 'like'),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopBar(Color color) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextField(
            onChanged: (v) {
              _searchQuery = v;
              _applyFilters(isReset: true);
            },
            decoration: InputDecoration(
              hintText: 'Tasarım ara...',
              prefixIcon: Icon(Icons.search_rounded, color: color),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              contentPadding: EdgeInsets.zero,
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: color.withOpacity(0.5))),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ["Yeniler", "En Çok Sevilen", "En Çok Kayıt Edilen"]
                .map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(filter, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (s) {
                    if (s) {
                      setState(() => _selectedFilter = filter);
                      _applyFilters(isReset: true);
                    }
                  },
                  selectedColor: color,
                  backgroundColor: const Color(0xFFF5F6FA),
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _DesignCard extends StatelessWidget {
  final DesignItem design;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final Color themeColor;

  const _DesignCard({
    required this.design,
    required this.onTap,
    required this.onLike,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: themeColor, width: 2.0),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Center(child: Image.asset(design.path)),
                  ),
                  if (design.isPremium)
                    Positioned(
                      top: 8,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.workspace_premium,
                            color: Colors.amber, size: 28),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Center(
                child: InkWell(
                  onTap: onLike,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          design.isLiked
                              ? Icons.favorite
                              : Icons.favorite_outline,
                          color: Colors.redAccent,
                          size: 32),
                      const SizedBox(width: 6),
                      Text(
                        "${design.likes}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
