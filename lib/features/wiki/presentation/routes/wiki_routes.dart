import 'package:go_router/go_router.dart';
import '../screens/wiki_screen.dart';
import '../screens/book_screen.dart';
import '../screens/page_screen.dart';

final List<GoRoute> wikiRoutes = [
  GoRoute(path: '/wiki', builder: (_, _) => const WikiScreen()),
  GoRoute(
    path: '/wiki/book/:bookId',
    builder: (context, state) =>
        BookScreen(bookId: state.pathParameters['bookId']!),
  ),
  GoRoute(
    path: '/wiki/page/:pageId',
    builder: (context, state) =>
        PageScreen(pageId: state.pathParameters['pageId']!),
  ),
];
