// lib/models/category_model.dart

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CategoryModel {
  final String titleKey;
  final Color color;
  final String templateFolder;
  final String imagePath;
  final IconData icon;
  final bool isPremium;

  const CategoryModel({
    required this.titleKey,
    required this.color,
    required this.templateFolder,
    required this.imagePath,
    this.icon = Icons.image,
    this.isPremium = false,
  });

  String getLocalizedTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (titleKey) {
      case 'animals':
        return l10n.animals;
      case 'cars':
        return l10n.cars;
      case 'anime':
        return l10n.anime;
      case 'cartoon':
        return l10n.cartoon;
      case 'flowers':
        return l10n.flowers;
      case 'human':
        return l10n.human;
      case 'nature':
        return l10n.nature;
      case 'tattoo':
        return l10n.tattoo; // ✅ Dövme eklendi
      case 'proMember':
        return l10n.proMember;
      case 'profile':
        return l10n.profile;
      default:
        return titleKey;
    }
  }
}

final List<CategoryModel> categories = [
  const CategoryModel(
    titleKey: "animals",
    color: Color(0xFFFF6B6B),
    templateFolder: "animals",
    imagePath: "assets/categories/animals.png",
    icon: Icons.pets,
    isPremium: false,
  ),
  const CategoryModel(
    titleKey: "cars",
    color: Color(0xFF4ECDC4),
    templateFolder: "cars",
    imagePath: "assets/categories/cars.png",
    icon: Icons.directions_car,
    isPremium: false,
  ),
  const CategoryModel(
    titleKey: "anime",
    color: Color(0xFFFFBE0B),
    templateFolder: "anime",
    imagePath: "assets/categories/anime.png",
    icon: Icons.brush,
    isPremium: true,
  ),
  const CategoryModel(
    titleKey: "cartoon",
    color: Color(0xFFFF006E),
    templateFolder: "cartoon",
    imagePath: "assets/categories/cartoon.png",
    icon: Icons.face,
    isPremium: true,
  ),
  const CategoryModel(
    titleKey: "flowers",
    color: Color(0xFF8338EC),
    templateFolder: "flowers",
    imagePath: "assets/categories/flowers.png",
    icon: Icons.local_florist,
    isPremium: true,
  ),
  const CategoryModel(
    titleKey: "human",
    color: Color(0xFF3A86FF),
    templateFolder: "human",
    imagePath: "assets/categories/human.png",
    icon: Icons.people,
    isPremium: true,
  ),
  const CategoryModel(
    titleKey: "tattoo", // ✅ Dövme kategorisi (templateFolder genelde nature'dı)
    color: Color(0xFFFB5607),
    templateFolder: "nature",
    imagePath: "assets/categories/nature.png",
    icon: Icons.edit_note_rounded,
    isPremium: true,
  ),
  const CategoryModel(
    titleKey: "proMember",
    color: Color(0xFFFFD700),
    templateFolder: "",
    imagePath: "assets/categories/premium.png",
    icon: Icons.workspace_premium,
  ),
  const CategoryModel(
    titleKey: "profile",
    color: Color(0xFF64B5F6),
    templateFolder: "",
    imagePath: "assets/categories/profile.png",
    icon: Icons.person,
  ),
];
