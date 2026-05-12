import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/media_poster_card.dart';
import 'package:everglow/features/cinema/presentation/widgets/tmdb_search_modal.dart';

class CinemaScreen extends StatelessWidget {
  const CinemaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tmdbService = TMDBService();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5), // Everglow Pink
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.pink.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Our Cinema 🍿',
          style: GoogleFonts.poppins(
            color: Colors.pink.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: Colors.pink.shade700),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const TMDBSearchModal(),
            ),
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
      ),
      body: StreamBuilder<List<MediaItem>>(
        stream: tmdbService.getWatchListStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.pink.shade300));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return _buildEmptyState();
          }

          return _buildGrid(items, tmdbService);
        },
      ),
    );
  }

  Widget _buildGrid(List<MediaItem> items, TMDBService tmdbService) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Stack(
          children: [
            MediaPosterCard(
              item: item,
              onTap: () => _showStatusDialog(context, item, tmdbService),
            ),
            // Status Badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.status == 'watched' ? Colors.green.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.status == 'watched' ? 'WATCHED' : 'TO WATCH',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_filter_rounded, size: 80, color: Colors.pink.shade100),
          const SizedBox(height: 20),
          Text(
            'No movies yet! 🌸',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.pink.shade300,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start adding your favorite shows\nvia Creator Mode.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.pink.shade200,
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(BuildContext context, MediaItem item, TMDBService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Update Status',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.pink.shade700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Have we watched "${item.title}" yet?'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatusButton(
                  label: 'To Watch',
                  isSelected: item.status == 'to-watch',
                  onTap: () async {
                    Navigator.pop(context);
                    await service.saveToWatchList(item, 'to-watch');
                  },
                ),
                _StatusButton(
                  label: 'Watched',
                  isSelected: item.status == 'watched',
                  onTap: () async {
                    Navigator.pop(context);
                    await service.saveToWatchList(item, 'watched');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.pink.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.pink.shade100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.pink.shade700 : Colors.pink.shade300,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
