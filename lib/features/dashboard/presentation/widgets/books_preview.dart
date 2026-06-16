import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/open_library_service.dart';
import 'package:everglow/features/books/presentation/screens/books_screen.dart';
import 'package:everglow/features/books/presentation/widgets/book_details_drawer.dart';
import 'package:everglow/services/auth_service.dart';
import 'shelf_widgets.dart';

/// "Our Books" shelf on the dashboard. Mirrors [CinemaPreview] /
/// [MangaPreview] visually so the four rails read as a family, but
/// pulls the user's read list from [OpenLibraryService] and uses the
/// warm amber accent.
class BooksPreview extends StatelessWidget {
  const BooksPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = OpenLibraryService();
    final userName = context.watch<AuthService>().currentUser ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _BooksShelf(
        userName: userName,
        service: service,
      ),
    );
  }
}

class _BooksShelf extends StatelessWidget {
  final String userName;
  final OpenLibraryService service;
  const _BooksShelf({required this.userName, required this.service});

  void _openDetails(BuildContext context, BookItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookDetailsDrawer(item: item),
    );
  }

  String _subtitleFor(BookItem item) {
    if (item.author.isEmpty) return item.year;
    if (item.year.isEmpty) return item.author;
    return '${item.author} • ${item.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShelfHeader(
          accent: ShelfAccent.books,
          title: 'Our Books',
          itemCount: 0,
          onViewAll: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BooksScreen()),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 168,
          child: userName.isEmpty
              ? const ShelfEmpty(
                  accent: ShelfAccent.books,
                  message: 'No books yet. Find your next read!',
                )
              : StreamBuilder<List<BookItem>>(
                  stream: service.getReadListStream(userName),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ShelfMarquee(
                        hasLoaded: false,
                        children: [],
                      );
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return ShelfEmpty(
                        accent: ShelfAccent.books,
                        message: 'No books yet. Find your next read!',
                      );
                    }
                    return ShelfMarquee(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ShelfCard(
                                accent: ShelfAccent.books,
                                imageUrl: item.coverUrl,
                                title: item.title,
                                subtitle: _subtitleFor(item),
                                onTap: () => _openDetails(context, item),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
