import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final snap = await FirebaseFirestore.instance.collection('milestones').orderBy('date').get();
  print('Total milestones: \');
  for (var doc in snap.docs) {
    final data = doc.data();
    print('Title: \');
    print('Date: \');
    print('---');
  }
}
