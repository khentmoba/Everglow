import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One browsable book category: display name, Open Library subject
/// query, icon, and accent color.
class BookCategory {
  final String name;
  final String query;
  final IconData icon;
  final Color color;

  const BookCategory({
    required this.name,
    required this.query,
    required this.icon,
    required this.color,
  });
}

/// The single source of truth for the Z-Lib style category set.
/// Used by the home chips, the categories grid, and the category
/// list pages (via [BookCatalogService.byCategory]).
const List<BookCategory> bookCategories = [
  BookCategory(
    name: 'Romance',
    query: 'romance',
    icon: Icons.favorite_rounded,
    color: AppColors.accentPink,
  ),
  BookCategory(
    name: 'Mystery',
    query: 'mystery',
    icon: Icons.search_rounded,
    color: Color(0xFF7B1FA2),
  ),
  BookCategory(
    name: 'Science Fiction',
    query: 'science fiction',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.animeCyan,
  ),
  BookCategory(
    name: 'Fantasy',
    query: 'fantasy',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF3949AB),
  ),
  BookCategory(
    name: 'Classics',
    query: 'classics',
    icon: Icons.menu_book_rounded,
    color: AppColors.animeGold,
  ),
  BookCategory(
    name: 'Adventure',
    query: 'adventure',
    icon: Icons.explore_rounded,
    color: Color(0xFFEF6C00),
  ),
  BookCategory(
    name: 'Horror',
    query: 'horror',
    icon: Icons.brightness_3_rounded,
    color: AppColors.twilight,
  ),
  BookCategory(
    name: 'Poetry',
    query: 'poetry',
    icon: Icons.auto_awesome_motion_outlined,
    color: AppColors.softLavender,
  ),
  BookCategory(
    name: 'History',
    query: 'history',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF5D4037),
  ),
  BookCategory(
    name: 'Biography',
    query: 'biography',
    icon: Icons.person_rounded,
    color: AppColors.cinemaBlue,
  ),
  BookCategory(
    name: 'Children',
    query: 'children',
    icon: Icons.child_care_rounded,
    color: AppColors.cinemaGreen,
  ),
  BookCategory(
    name: 'Cooking',
    query: 'cooking',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFE65100),
  ),
];
