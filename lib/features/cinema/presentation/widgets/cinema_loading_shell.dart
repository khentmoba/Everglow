import 'package:flutter/material.dart';

import 'netflix/netflix_colors.dart';
import 'netflix/netflix_loading.dart';

class CinemaLoadingShell extends StatelessWidget {
  const CinemaLoadingShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NetflixColors.background,
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: const [
          NetflixLoadingBillboard(),
          NetflixLoadingRow(title: 'Trending Now'),
        ],
      ),
    );
  }
}
