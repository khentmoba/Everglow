import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'media_poster_card.dart';

class TMDBSearchModal extends StatefulWidget {
  const TMDBSearchModal({Key? key}) : super(key: key);

  @override
  State<TMDBSearchModal> createState() => _TMDBSearchModalState();
}

class _TMDBSearchModalState extends State<TMDBSearchModal> {
  final TMDBService _tmdbService = TMDBService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<MediaItem> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    final results = await _tmdbService.searchMedia(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _showAddDialog(MediaItem item) {
    String status = 'to-watch';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Text(
            'Add to Everglow?',
            style: TextStyle(color: Colors.pink.shade700, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.posterPath.isNotEmpty
                    ? Image.network(item.posterPath, height: 150, fit: BoxFit.cover)
                    : Container(height: 150, color: Colors.pink.shade50),
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('To Watch'),
                    selected: status == 'to-watch',
                    onSelected: (selected) {
                      if (selected) setDialogState(() => status = 'to-watch');
                    },
                    selectedColor: Colors.pink.shade100,
                    labelStyle: TextStyle(color: status == 'to-watch' ? Colors.pink.shade700 : Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Watched'),
                    selected: status == 'watched',
                    onSelected: (selected) {
                      if (selected) setDialogState(() => status = 'watched');
                    },
                    selectedColor: Colors.pink.shade100,
                    labelStyle: TextStyle(color: status == 'watched' ? Colors.pink.shade700 : Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _tmdbService.saveToWatchList(item, status);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🌸 ${item.title} added to Everglow!'),
                      backgroundColor: Colors.pink.shade400,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context); // Close search modal
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            'Find Your Next Cinema Moment 🍿',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade700,
            ),
          ),
          const SizedBox(height: 20),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search for a movie or show...',
              prefixIcon: Icon(Icons.search, color: Colors.pink.shade300),
              filled: true,
              fillColor: Colors.pink.shade50.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
          const SizedBox(height: 20),

          // Results Area
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.pink.shade300))
                : _results.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        itemCount: _results.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemBuilder: (context, index) {
                          return MediaPosterCard(
                            item: _results[index],
                            onTap: () => _showAddDialog(_results[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeIn(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_outlined, size: 60, color: Colors.pink.shade100),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'Start typing to find magic...' : 'No movies found! 🌸',
            style: TextStyle(color: Colors.pink.shade200, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
