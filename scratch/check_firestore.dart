import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final snap = await FirebaseFirestore.instance.collection('milestones').get();
  print('Total milestones in Firestore: ${snap.docs.length}');
  for (var doc in snap.docs) {
    print('ID: ${doc.id}, Title: ${doc.get('title')}');
  }
}
