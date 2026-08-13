import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../books/data/models/book_item.dart';
import '../../../books/data/models/our_books_item.dart';
import '../../../books/data/services/open_library_service.dart';
import '../../../books/data/services/our_books_service.dart';
import '../../../books/presentation/widgets/book_details_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '_partner_label.dart';
import 'partner_subrow.dart';
import 'shelf_widgets.dart';

/// "Our Books" shelf on the dashboard.
///
/// For couple users (khentsgdz / clairjassen) the shelf splits into
/// two labeled sub-rows — "Me" and the partner — sourced from the
/// shared `our_books` collection filtered by `addedBy`. This keeps the
/// per-partner attribution consistent with the in-app "Our Books"
/// screen.
///
/// Non-couple users fall back to the original single-row layout that
/// streams the user's own `read_list` collection (the dashboard
/// "Our Books" rail has always shown the personal read history for
/// non-couple accounts).
class BooksPreview extends StatelessWidget {
  const BooksPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final ourBooksService = context.read<OurBooksService>();

    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final isCouple = auth.isCoupleUser;
    final partner = auth.partnerUsername;
    final partnerLabel = partnerEyebrowLabelFor(userName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BooksHeader(ourBooksService: ourBooksService),
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _OurBooksSubrow(
              ourBooksService: ourBooksService,
              adder: userName,
              label: 'ME',
              isSelf: true,
            ),
            _OurBooksSubrow(
              ourBooksService: ourBooksService,
              adder: partner,
              label: partnerLabel,
              isSelf: false,
            ),
          ] else
            _PersonalBooksShelf(userName: userName),
        ],
      ),
    );
  }
}

class _BooksHeader extends StatefulWidget {
  final OurBooksService ourBooksService;
  const _BooksHeader({required this.ourBooksService});

  @override
  State<_BooksHeader> createState() => _BooksHeaderState();
}

class _BooksHeaderState extends State<_BooksHeader> {
  int _count = 0;
  StreamSubscription<List<OurBooksItem>>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _BooksHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ourBooksService != widget.ourBooksService) {
      _sub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _sub = widget.ourBooksService.getOurBooksStream().listen((items) {
      if (!mounted) return;
      setState(() => _count = items.length);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShelfHeader(
      accent: ShelfAccent.books,
      title: 'Our Books',
      itemCount: _count,
      onViewAll: () => context.push('/books'),
    );
  }
}

class _OurBooksSubrow extends StatefulWidget {
  final OurBooksService ourBooksService;
  final String adder;
  final String label;
  final bool isSelf;
  const _OurBooksSubrow({
    required this.ourBooksService,
    required this.adder,
    required this.label,
    required this.isSelf,
  });

  @override
  State<_OurBooksSubrow> createState() => _OurBooksSubrowState();
}

class _OurBooksSubrowState extends State<_OurBooksSubrow> {
  List<OurBooksItem> _items = const [];
  bool _hasLoaded = false;
  StreamSubscription<List<OurBooksItem>>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _OurBooksSubrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ourBooksService != widget.ourBooksService ||
        oldWidget.adder != widget.adder) {
      _sub?.cancel();
      setState(() {
        _items = const [];
        _hasLoaded = false;
      });
      _subscribe();
    }
  }

  void _subscribe() {
    _sub = widget.ourBooksService.getOurBooksByAdderStream(widget.adder).listen(
      (items) {
        if (!mounted) return;
        setState(() {
          _items = items;
          _hasLoaded = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openDetails(OurBooksItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookDetailsDrawer(item: item.toBookItem()),
    );
  }

  String _subtitleFor(OurBooksItem item) {
    if (item.author.isEmpty) return item.year;
    if (item.year.isEmpty) return item.author;
    return '${item.author} • ${item.year}';
  }

  List<Widget> _buildCards() {
    return _items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ShelfCard(
              accent: ShelfAccent.books,
              imageUrl: item.coverUrl,
              title: item.title,
              subtitle: _subtitleFor(item),
              onTap: () => _openDetails(item),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PartnerSubrow(
      label: widget.label,
      accent: ShelfAccent.books,
      emptyMessage: widget.isSelf
          ? 'You haven\'t added any books to "Ours" yet.'
          : 'They haven\'t added any books to "Ours" yet.',
      children: _hasLoaded ? _buildCards() : const [],
    );
  }
}

class _PersonalBooksShelf extends StatefulWidget {
  final String userName;
  const _PersonalBooksShelf({required this.userName});

  @override
  State<_PersonalBooksShelf> createState() => _PersonalBooksShelfState();
}

class _PersonalBooksShelfState extends State<_PersonalBooksShelf> {
  final OpenLibraryService _openLibraryService = OpenLibraryService();
  Stream<List<BookItem>>? _stream;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant _PersonalBooksShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) _bind();
  }

  void _bind() {
    _stream = widget.userName.isEmpty
        ? null
        : _openLibraryService.getReadListStream(widget.userName);
  }

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
    final stream = _stream;
    return SizedBox(
      height: 168,
      child: stream == null
          ? const ShelfEmpty(
              accent: ShelfAccent.books,
              message: 'No books yet. Find your next read!',
            )
          : StreamBuilder<List<BookItem>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError ||
                    (!snapshot.hasData &&
                        snapshot.connectionState == ConnectionState.done)) {
                  return ShelfEmpty(
                    accent: ShelfAccent.books,
                    message: 'Could not load books. Tap to retry.',
                  );
                }
                if (!snapshot.hasData) {
                  return const ShelfMarquee(hasLoaded: false, children: []);
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
    );
  }
}
