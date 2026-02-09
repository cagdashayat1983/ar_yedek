import 'package:flutter/material.dart';

class CategoryModel {
  final String id; // Kategori ID'si (dosya yolları için önemli)
  final String title; // Ekranda görünen isim
  final String? imagePath; // Kapak resmi yolu
  final Color color; // Kategori rengi
  final bool isPro; // Kilitli içerik mi?
  final int itemCount; // İçinde kaç resim var?

  CategoryModel({
    required this.id,
    required this.title,
    this.imagePath,
    required this.color,
    this.isPro = false, // Varsayılan: Ücretsiz
    this.itemCount = 10, // Varsayılan: 10 Resim
  });
}

// --- KATEGORİ LİSTESİ ---
final List<CategoryModel> categories = [
  CategoryModel(
    id: "animals",
    title: "Hayvanlar",
    imagePath: "assets/categories/animals.png",
    color: Colors.greenAccent,
    itemCount: 24,
    isPro: false,
  ),
  CategoryModel(
    id: "cars",
    title: "Arabalar",
    imagePath: "assets/categories/cars.png",
    color: Colors.redAccent,
    itemCount: 15,
    isPro: true, // 🔒 Kilitli
  ),
  CategoryModel(
    id: "anime",
    title: "Anime",
    imagePath: "assets/categories/anime.png",
    color: Colors.purpleAccent,
    itemCount: 30,
    isPro: true, // 🔒 Kilitli
  ),
  CategoryModel(
    id: "cartoon",
    title: "Çizgi Film",
    imagePath: "assets/categories/cartoon.png",
    color: Colors.orangeAccent,
    itemCount: 18,
    isPro: false,
  ),
  CategoryModel(
    id: "flowers",
    title: "Çiçekler",
    imagePath: "assets/categories/flowers.png",
    color: Colors.pinkAccent,
    itemCount: 12,
    isPro: false,
  ),
  CategoryModel(
    id: "human",
    title: "İnsan Figürleri",
    imagePath: "assets/categories/human.png",
    color: Colors.blueAccent,
    itemCount: 20,
    isPro: true, // 🔒 Kilitli
  ),
  CategoryModel(
    id: "nature",
    title: "Doğa",
    imagePath: "assets/categories/nature.png",
    color: Colors.tealAccent,
    itemCount: 10,
    isPro: false,
  ),
];
