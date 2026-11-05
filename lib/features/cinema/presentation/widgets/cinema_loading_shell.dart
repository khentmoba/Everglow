import 'package:flutter/material.dart';

import 'netflix/netflix_colors.dart';
import 'netflix/netflix_loading.dart';

/// First paint for `/cinema` while its code chunk downloads. It shows the
/// same placeholders the Home tab shows while its feeds load, so handing off
/// to the live screen does not jump.
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
