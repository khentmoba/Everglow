import 'package:go_router/go_router.dart';
import '../../../../core/router/route_helpers.dart';
import '../../../../core/router/deferred_route.dart';

import 'package:flutter/material.dart';

import '../../data/models/book_item.dart';
import '../../data/models/book_search_result.dart';
import '../screens/book_categories_screen.dart' deferred as categories_lib;
import '../screens/book_detail_screen.dart' deferred as detail_lib;
import '../screens/book_list_screen.dart';
import '../screens/books_screen.dart' deferred as books_lib;
import '../screens/our_books_screen.dart' deferred as our_books_lib;
import '../screens/reader_screen.dart' deferred as reader_lib;
import '../widgets/book_categories.dart';

/// Routes owned by the books feature.
final List<GoRoute> booksRoutes = [
  GoRoute(
    path: '/books',
    builder: (_, state) {
      final query = extraOf<String>(state) ?? '';
      return DeferredRouteLoader(
        label: 'Books',
        loadLibrary: books_lib.loadLibrary,
        builder: () => books_lib.BooksScreen(initialQuery: query),
      );
    },
    routes: [
      GoRoute(
        path: 'reader',
        builder: (_, state) {
          final book = extraOf<BookItem>(state);
          if (book == null) return missingExtraPage(state);
          return DeferredRouteLoader(
            label: 'Book reader',
            loadLibrary: reader_lib.loadLibrary,
            builder: () => reader_lib.ReaderScreen(book: book),
          );
        },
      ),
      GoRoute(
        path: 'detail',
        builder: (_, state) {
          final args = extraOf<BookDetailArgs>(state);
          if (args == null) return missingExtraPage(state);
          return DeferredRouteLoader(
            label: 'Book details',
            loadLibrary: detail_lib.loadLibrary,
            builder: () => detail_lib.BookDetailScreen(args: args),
          );
        },
      ),
      GoRoute(
        path: 'listen',
        builder: (_, state) {
          final book = extraOf<BookItem>(state);
          if (book == null) return missingExtraPage(state);
          return DeferredRouteLoader(
            label: 'Book reader',
            loadLibrary: reader_lib.loadLibrary,
            builder: () =>
                reader_lib.ReaderScreen(book: book, startListening: true),
          );
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
            return BookListScreen(args: BookListArgs.category(category));
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
        builder: (_, _) => DeferredRouteLoader(
          label: 'Book categories',
          loadLibrary: categories_lib.loadLibrary,
          builder: () => categories_lib.BookCategoriesScreen(),
        ),
      ),
    ],
  ),
  GoRoute(
    path: '/our-books',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Our Books',
      loadLibrary: our_books_lib.loadLibrary,
      builder: () => our_books_lib.OurBooksScreen(),
    ),
  ),
];
