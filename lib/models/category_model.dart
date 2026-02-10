import 'package:flutter/material.dart';

class CategoryModel {
  final String id; // assets/templates/<id>/ klasör adı
  final String title; // UI başlık
  final String subtitle; // UI alt yazı
  final Color color;
  final String coverAsset; // assets/categories/<id>.png

  const CategoryModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.coverAsset,
  });
}

// ✅ Kapaklar: assets/categories/*.png (senin klasörle birebir)
const List<CategoryModel> categories = [
  CategoryModel(
    id: 'animals',
    title: 'Hayvanlar',
    subtitle: 'Hızlı çizim şablonları',
    color: Color(0xFF3FB984),
    coverAsset: 'assets/categories/animals.png',
  ),
  CategoryModel(
    id: 'anime',
    title: 'Anime',
    subtitle: 'Karakter şablonları',
    color: Color(0xFFFF5A7A),
    coverAsset: 'assets/categories/anime.png',
  ),
  CategoryModel(
    id: 'cars',
    title: 'Arabalar',
    subtitle: 'Detaylı araç çizimleri',
    color: Color(0xFF5B7CFA),
    coverAsset: 'assets/categories/cars.png',
  ),
  CategoryModel(
    id: 'cartoon',
    title: 'Cartoon',
    subtitle: 'Eğlenceli çizimler',
    color: Color(0xFFFFB020),
    coverAsset: 'assets/categories/cartoon.png',
  ),
  CategoryModel(
    id: 'flowers',
    title: 'Çiçekler',
    subtitle: 'Doğa & bitki',
    color: Color(0xFF8E5BFF),
    coverAsset: 'assets/categories/flowers.png',
  ),
  CategoryModel(
    id: 'human',
    title: 'İnsan',
    subtitle: 'Poz & anatomi',
    color: Color(0xFF2DB7C6),
    coverAsset: 'assets/categories/human.png',
  ),
  CategoryModel(
    id: 'nature',
    title: 'Doğa',
    subtitle: 'Manzara şablonları',
    color: Color(0xFF2E7D32),
    coverAsset: 'assets/categories/nature.png',
  ),
];
