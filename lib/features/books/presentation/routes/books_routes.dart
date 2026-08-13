import 'package:go_router/go_router.dart';
import '../../../../core/router/route_helpers.dart';

import '../../data/models/book_item.dart';
import '../../data/models/book_search_result.dart';
import '../screens/book_detail_screen.dart';
import '../screens/books_screen.dart';
import '../screens/our_books_screen.dart';
import '../screens/reader_screen.dart';

/// Routes owned by the books feature.
final List<GoRoute> booksRoutes = [
  GoRoute(
    path: '/books',
    builder: (_, _) => const BooksScreen(),
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
    ],
  ),
  GoRoute(path: '/our-books', builder: (_, _) => const OurBooksScreen()),
];
