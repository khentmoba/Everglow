import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_colors.dart';

/// Proxy URL for CORS-blocked anime thumbnail CDNs (Crunchyroll, etc.).
/// Fetches the image server-side and returns it with permissive CORS headers.
const proxyAnimeImageUrl =
    'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAnimeImage';

/// Strip trailing " Season X", " Season X Part Y", " 2nd Season", etc.
String cleanTitle(String title) {
  return title.replaceAll(
      RegExp(
          r'\s+(Season\s+\d+(\s+Part\s+\d+)?|\d+(st|nd|rd|th)\s+Season)$',
          caseSensitive: false),
      '');
}

String getInitial(String name) =>
    name.isNotEmpty ? name[0].toUpperCase() : '?';

Color avatarColor(String name) {
  final palette = [
    AppColors.deepRose,
    AppColors.warmAmber,
    AppColors.softLavender,
    AppColors.blushGold,
    AppColors.roseQuartz,
  ];
  if (name.isEmpty) return AppColors.deepRose;
  return palette[name.codeUnitAt(0) % palette.length];
}

Widget buildCastInitial(String name) {
  return Container(
    color: avatarColor(name).withValues(alpha: 0.25),
    alignment: Alignment.center,
    child: Text(
      getInitial(name),
      style: GoogleFonts.cormorantGaramond(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: avatarColor(name),
      ),
    ),
  );
}

Widget buildLoader() {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
            color: AppColors.deepRose, strokeWidth: 2),
      ),
    ),
  );
}

Widget buildEmptySection(String msg) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Text(
      msg,
      style: GoogleFonts.outfit(color: AppColors.mutedPurple, fontSize: 13),
    ),
  );
}

Widget buildDrawerSectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.deepRose, Color(0x44C2185B)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.petalWhite,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget dot() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.mutedPurple,
          shape: BoxShape.circle,
        ),
      ),
    );
