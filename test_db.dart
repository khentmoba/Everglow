import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:everglow/firebase_options.dart';

void main() {
  test('Count milestones', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    var snap = await FirebaseFirestore.instance.collection('milestones').get();
    print('MILESTONE COUNT: \');
  });
}
