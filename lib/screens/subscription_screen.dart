// lib/screens/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:camera/camera.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Link açmak için

// ✅ Servis ve l10n Importları
import '../l10n/app_localizations.dart';
import '../services/subscription_service.dart';
import 'home_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool isFirstOffer;
  final List<CameraDescription>? cameras;

  const SubscriptionScreen(
      {super.key, this.isFirstOffer = false, this.cameras});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Offering? _currentOffering;
  Package? _selectedPackage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  // 📦 Paketleri Yükle
  Future<void> _loadOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        setState(() {
          _currentOffering = offerings.current;
          _selectedPackage = offerings.current!.annual ??
              offerings.current!.availablePackages.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Abonelik hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  // 💰 Satın Alımı Yönet
  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) return;
    setState(() => _isLoading = true);

    try {
      final purchaseResult = await Purchases.purchasePackage(_selectedPackage!);
      final customerInfo = purchaseResult.customerInfo;

      // 'AR Draw Hayatify Pro' ID'sinin RevenueCat ile aynı olduğundan emin olun
      if (customerInfo.entitlements.all["AR Draw Hayatify Pro"]?.isActive ??
          false) {
        _onSuccess();
      }
    } catch (e) {
      debugPrint("Satın alım hatası: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔄 Satın Almaları Geri Yükle (Android/iOS Market Şartı)
  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    bool restored = await SubscriptionService.restorePurchases();
    setState(() => _isLoading = false);

    if (mounted) {
      if (restored) {
        _onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aktif bir abonelik bulunamadı.")),
        );
      }
    }
  }

  void _onSuccess() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.congratsPro), backgroundColor: Colors.amber),
    );
    _closeOrGoHome();
  }

  void _closeOrGoHome() {
    if (widget.isFirstOffer && widget.cameras != null) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => HomeScreen(cameras: widget.cameras!)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Stack(
              children: [
                _buildDecoration(),
                SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      _buildHeader(l10n),
                      const SizedBox(height: 30),
                      _buildFeaturesList(l10n),
                      const Spacer(),
                      _buildOfferingsList(l10n),
                      const SizedBox(height: 20),
                      _buildBuyButton(l10n),
                      _buildLegalLinks(), // ✅ Restore ve Gizlilik Linkleri
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- WIDGET PARÇALARI ---

  Widget _buildTopBar() {
    return Align(
      alignment: Alignment.topLeft,
      child: IconButton(
        icon: const Icon(Icons.close_rounded, size: 30),
        onPressed: _closeOrGoHome,
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
        const Icon(Icons.workspace_premium_rounded,
            size: 70, color: Colors.amber),
        const SizedBox(height: 10),
        Text(l10n.proTitle,
            style:
                GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w900)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(l10n.proDesc,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildFeaturesList(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Column(
        children: [
          _featureRow(l10n.feature1),
          _featureRow(l10n.feature2),
          _featureRow(l10n.feature3),
          _featureRow(l10n.feature4),
        ],
      ),
    );
  }

  Widget _featureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        const Icon(Icons.check, color: Colors.green, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 14))),
      ]),
    );
  }

  Widget _buildOfferingsList(AppLocalizations l10n) {
    if (_currentOffering == null) return const SizedBox();

    return Column(
      children: _currentOffering!.availablePackages.map((package) {
        bool isSelected = _selectedPackage == package;
        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = package),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: isSelected ? Colors.amber : Colors.grey.shade300,
                  width: 2),
              color: isSelected ? Colors.amber.withOpacity(0.05) : Colors.white,
            ),
            child: Row(
              children: [
                Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: Colors.amber),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    package.packageType == PackageType.annual
                        ? l10n.proYearly
                        : l10n.proMonthly,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(package.storeProduct.priceString,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBuyButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _handlePurchase,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        height: 60,
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Center(
          child: Text(l10n.getStarted,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      ),
    );
  }

  // ✅ YASAL LİNKLER: Geri Yükle ve Gizlilik Politikası
  Widget _buildLegalLinks() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: _handleRestore,
            child: Text(
              "Restore",
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                  decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(width: 10),
          Text("|", style: TextStyle(color: Colors.grey.shade300)),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () async {
              final url = Uri.parse(
                  'https://cagdashayat1983.github.io/privacy-policy/');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              "Privacy Policy",
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecoration() {
    return Positioned(
      top: -50,
      right: -50,
      child: CircleAvatar(
          radius: 100, backgroundColor: Colors.amber.withOpacity(0.05)),
    );
  }
}
