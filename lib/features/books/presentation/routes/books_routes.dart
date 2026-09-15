import 'package:go_router/go_router.dart';
import '../../../../core/router/route_helpers.dart';

import 'package:flutter/material.dart';

import '../../data/models/book_item.dart';
import '../../data/models/book_search_result.dart';
import '../screens/book_categories_screen.dart';
import '../screens/book_detail_screen.dart';
import '../screens/book_list_screen.dart';
import '../screens/books_screen.dart';
import '../screens/our_books_screen.dart';
import '../screens/reader_screen.dart';
import '../widgets/book_categories.dart';

/// Routes owned by the books feature.
final List<GoRoute> booksRoutes = [
  GoRoute(
    path: '/books',
    builder: (_, state) {
      final query = extraOf<String>(state) ?? '';
      return BooksScreen(initialQuery: query);
    },
    routes: [
      GoRoute(
        path: 'reader',
        builder: (_, state) {
          final book = extraOf<BookItem>(state);
          if (book == null) return missingExtraPage(state);
          return ReaderScreen(book: book);
        },
      ),
      GoRoute(
        path: 'detail',
        builder: (_, state) {
          final args = extraOf<BookDetailArgs>(state);
          if (args == null) return missingExtraPage(state);
          return BookDetailScreen(args: args);
        },
      ),
      GoRoute(
        path: 'listen',
        builder: (_, state) {
          final book = extraOf<BookItem>(state);
          if (book == null) return missingExtraPage(state);
          return ReaderScreen(book: book, startListening: true);
        },
      ),
      GoRoute(
        path: 'list',
        builder: (_, state) {
          final args = extraOf<BookListArgs>(state);
          if (args == null) return missingExtraPage(state);
          return BookListScreen(args: args);
        },
      ),
      GoRoute(
        // Accepts either a [BookCategory] (category grid) or a plain
        // subject string (detail-page subject chips).
        path: 'category',
        builder: (_, state) {
          final category = extraOf<BookCategory>(state);
          if (category != null) {
            return BookListScreen(
              args: BookListArgs.category(category),
            );
          }
          final subject = extraOf<String>(state);
          if (subject == null || subject.isEmpty) {
            return missingExtraPage(state);
          }
          return BookListScreen(
            args: BookListArgs.category(
              BookCategory(
                name: subject,
                query: subject,
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFE9B6C2),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: 'categories',
        builder: (_, _) => const BookCategoriesScreen(),
      ),
    ],
  ),
  GoRoute(path: '/our-books', builder: (_, _) => const OurBooksScreen()),
];
