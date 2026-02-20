import 'package:flutter/material.dart';

class CategoryModel {
  final String title;
  final String templateFolder;
  final Color color;
  final IconData icon;

  const CategoryModel({
    required this.title,
    required this.templateFolder,
    required this.color,
    required this.icon,
  });
}
