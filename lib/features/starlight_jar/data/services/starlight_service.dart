import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/star_note.dart';

class StarlightService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'starlight_jar';

  Stream<List<StarNote>> getStarNotes() {
    return _db
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StarNote.fromFirestore(doc)).toList());
  }

  Future<void> addStar(String content, String author) async {
    if (content.trim().isEmpty) return;
    
    try {
      await _db.collection(_collection).add({
        'content': content.trim(),
        'author': author.toLowerCase(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("Dropped star into jar successfully");
    } catch (e) {
      print("Error adding star: $e");
    }
  }

  Future<StarNote?> getRandomStarNote() async {
    try {
      final snapshot = await _db.collection(_collection).get();
      if (snapshot.docs.isEmpty) return null;
      
      final docs = snapshot.docs;
      docs.shuffle();
      return StarNote.fromFirestore(docs.first);
    } catch (e) {
      print("Error getting random star: $e");
      return null;
    }
  }
}
