import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/wiki_page.dart';

class WikiService {
  static final WikiService _instance = WikiService._internal();
  factory WikiService() => _instance;
  WikiService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _shelves = 'wiki_shelves';
  final String _books = 'wiki_books';
  final String _pages = 'wiki_pages';

  Stream<List<WikiShelf>> watchShelves() => withFirestoreTimeout(_db.collection(_shelves).orderBy('order').snapshots().map((s) => s.docs.map((d) => WikiShelf.fromFirestore(d)).toList()), label: 'wiki-shelves');

  Stream<List<WikiBook>> watchBooks(String shelfId) => withFirestoreTimeout(_db.collection(_books).where('shelfId', isEqualTo: shelfId).orderBy('order').snapshots().map((s) => s.docs.map((d) => WikiBook.fromFirestore(d)).toList()), label: 'wiki-books-$shelfId');

  Stream<List<WikiBook>> watchAllBooks() => withFirestoreTimeout(_db.collection(_books).orderBy('createdAt', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => WikiBook.fromFirestore(d)).toList()), label: 'wiki-books-all');

  Stream<List<WikiPage>> watchPages(String bookId) => withFirestoreTimeout(_db.collection(_pages).where('bookId', isEqualTo: bookId).orderBy('updatedAt', descending: true).snapshots().map((s) => s.docs.map((d) => WikiPage.fromFirestore(d)).toList()), label: 'wiki-pages-$bookId');

  Stream<List<WikiPage>> watchAllPages() => withFirestoreTimeout(_db.collection(_pages).orderBy('updatedAt', descending: true).limit(100).snapshots().map((s) => s.docs.map((d) => WikiPage.fromFirestore(d)).toList()), label: 'wiki-pages-all');

  Future<void> addShelf(WikiShelf shelf) async {
    try {
      await _db.collection(_shelves).add(shelf.toFirestore());
      Logger.i('Shelf added: ${shelf.title}');
    } catch (e) {
      Logger.e('Error adding shelf', error: e);
    }
  }

  Future<void> addBook(WikiBook book) async {
    try {
      await _db.collection(_books).add(book.toFirestore());
      Logger.i('Book added: ${book.title}');
    } catch (e) {
      Logger.e('Error adding book', error: e);
    }
  }

  Future<void> addPage(WikiPage page) async {
    try {
      await _db.collection(_pages).add(page.toFirestore());
      Logger.i('Page added: ${page.title}');
    } catch (e) {
      Logger.e('Error adding page', error: e);
    }
  }

  Future<void> updatePage(WikiPage page) async {
    try {
      await _db.collection(_pages).doc(page.id).update({...page.toFirestore(), 'updatedAt': Timestamp.now()});
    } catch (e) {
      Logger.e('Error updating page', error: e);
    }
  }

  Future<void> deleteShelf(String id) async {
    try {
      await _db.collection(_shelves).doc(id).delete();
    } catch (e) {
      Logger.e('Error deleting shelf', error: e);
    }
  }

  Future<void> deleteBook(String id) async {
    try {
      await _db.collection(_books).doc(id).delete();
      final pages = await _db.collection(_pages).where('bookId', isEqualTo: id).get();
      for (final d in pages.docs) await d.reference.delete();
    } catch (e) {
      Logger.e('Error deleting book', error: e);
    }
  }

  Future<void> deletePage(String id) async {
    try {
      await _db.collection(_pages).doc(id).delete();
    } catch (e) {
      Logger.e('Error deleting page', error: e);
    }
  }

  Future<void> togglePin(String pageId, bool pinned) async {
    try {
      await _db.collection(_pages).doc(pageId).update({'isPinned': pinned});
    } catch (e) {
      Logger.e('Error pinning', error: e);
    }
  }
}
