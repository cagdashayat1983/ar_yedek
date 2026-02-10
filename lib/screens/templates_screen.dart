import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/category_model.dart';
import '../ar_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';

// ✅ Veri Modeli
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

  const TemplatesScreen({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  late SharedPreferences _prefs;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isProUser = false;

  int _selectedIndex = 0;
  int _pageSize = 18;
  int _currentPage = 1;

  List<DesignItem> _allDesignsSource = [];
  List<DesignItem> _filteredDesigns = [];

  @override
  void initState() {
    super.initState();
    _initData();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    _prefs = await SharedPreferences.getInstance();
    _isProUser = _prefs.getBool('is_pro_user') ?? false;

    await _loadDesignsFromAssets();
    _applyFilters();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDesignsFromAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(
      DefaultAssetBundle.of(context),
    );

    final searchPath = "assets/templates/${widget.category.id}";

    final paths =
        manifest.listAssets().where((k) => k.contains(searchPath)).where((k) {
      final lower = k.toLowerCase();
      return lower.endsWith('.webp') ||
          lower.endsWith('.png') ||
          lower.endsWith('.jpg');
    }).toList();

    _allDesignsSource = paths.map((p) {
      final liked = _prefs.getBool('liked_$p') ?? false;
      final saved = _prefs.getBool('saved_$p') ?? false;
      final savedLikes = _prefs.getInt('likes_$p') ?? 0;

      final index = paths.indexOf(p);
      final isPremium = index >= 6;

      return DesignItem(
        path: p,
        likes: savedLikes,
        isLiked: liked,
        isSaved: saved,
        isPremium: isPremium,
      );
    }).toList();

    _currentPage = 1;
    _filteredDesigns = _allDesignsSource.take(_pageSize).toList();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _allDesignsSource.where((d) {
      if (query.isEmpty) return true;
      return d.path.toLowerCase().contains(query);
    }).toList();

    final maxItems = _currentPage * _pageSize;
    setState(() {
      _filteredDesigns = filtered.take(maxItems).toList();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 250));
    _currentPage++;
    _applyFilters();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _onBottomNavTapped(int index) {
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ).then((_) => _initData());
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      ).then((_) => _initData());
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Color get themeColor => widget.category.color;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F8FA);

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
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
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredDesigns.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, i) {
                      final item = _filteredDesigns[i];
                      return _DesignCard(
                        design: item,
                        themeColor: themeColor,
                        isLocked: item.isPremium && !_isProUser,
                        onTap: () {
                          if (item.isPremium && !_isProUser) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SubscriptionScreen(),
                              ),
                            ).then((_) => _initData());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ARDrawingScreen(
                                  selectedCategory: widget.category.title,
                                  selectedImagePath: item.path,
                                ),
                              ),
                            );
                          }
                        },
                        onLike: () async {
                          setState(() {
                            item.isLiked = !item.isLiked;
                            item.likes += item.isLiked ? 1 : -1;
                          });
                          await _prefs.setBool(
                              'liked_${item.path}', item.isLiked);
                          await _prefs.setInt('likes_${item.path}', item.likes);
                        },
                        onSave: () async {
                          setState(() => item.isSaved = !item.isSaved);
                          await _prefs.setBool(
                              'saved_${item.path}', item.isSaved);
                        },
                      );
                    },
                  ),
                ),
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: themeColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: "Şablonlar"),
          BottomNavigationBarItem(
              icon: Icon(Icons.book_rounded), label: "Kayıtlar"),
          BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_rounded), label: "PRO"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: "Hesabım"),
        ],
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  final DesignItem design;
  final Color themeColor;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final bool isLocked;

  const _DesignCard({
    required this.design,
    required this.themeColor,
    required this.onTap,
    required this.onLike,
    required this.onSave,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
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
              Image.asset(
                design.path,
                fit: BoxFit.cover,
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    _Pill(
                      child: Row(
                        children: [
                          InkWell(
                            onTap: onLike,
                            child: Icon(
                              design.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: design.isLiked ? Colors.red : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${design.likes}",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      child: InkWell(
                        onTap: onSave,
                        child: Icon(
                          design.isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isLocked)
                      _Pill(
                        child: Row(
                          children: [
                            const Icon(Icons.lock_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              "PRO",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
