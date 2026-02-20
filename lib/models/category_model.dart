// lib/models/category_model.dart

import 'package:flutter/material.dart';

class CategoryModel {
  final String title;
  final Color color;
  final String templateFolder; // Şablonların olduğu klasör adı
  final String imagePath; // Kategori kartındaki kapak resmi

  CategoryModel({
    required this.title,
    required this.color,
    required this.templateFolder,
    required this.imagePath,
  });
}

// Uygulamada Kullanılacak Kategoriler Listesi
final List<CategoryModel> categories = [
  CategoryModel(
    title: "Hayvanlar",
    color: const Color(0xFFFF8A65), // Turuncu
    templateFolder: "animals",
    imagePath: "assets/categories/animals.png",
  ),
  CategoryModel(
    title: "Arabalar",
    color: const Color(0xFF4FC3F7), // Mavi
    templateFolder: "cars",
    imagePath: "assets/categories/cars.png",
  ),
  CategoryModel(
    title: "Anime",
    color: const Color(0xFF9575CD), // Mor
    templateFolder: "anime",
    imagePath: "assets/categories/anime.png",
  ),
  CategoryModel(
    title: "Çizgi Film",
    color: const Color(0xFFFFD54F), // Sarı
    templateFolder: "cartoon",
    imagePath: "assets/categories/cartoon.png",
  ),
  CategoryModel(
    title: "Çiçekler",
    color: const Color(0xFFF06292), // Pembe
    templateFolder: "flowers",
    imagePath: "assets/categories/flowers.png",
  ),
  CategoryModel(
    title: "İnsanlar",
    color: const Color(0xFFA1887F), // Kahve
    templateFolder: "human",
    imagePath: "assets/categories/human.png",
  ),
  CategoryModel(
    title: "Doğa",
    color: const Color(0xFF81C784), // Yeşil
    templateFolder: "nature",
    imagePath: "assets/categories/nature.png",
  ),

  // --- ÖZEL MENÜLER ---
  CategoryModel(
    title: "Pro Üyelik",
    color: const Color(0xFFFFD700), // Altın
    templateFolder: "",
    imagePath: "assets/categories/premium.png",
  ),
  CategoryModel(
    title: "Profil",
    color: const Color(0xFF64B5F6), // Açık Mavi
    templateFolder: "",
    imagePath: "assets/categories/profile.png",
  ),
];
