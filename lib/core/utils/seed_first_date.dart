import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../firebase_options.dart';
import '../../features/dashboard/domain/models/milestone.dart';
import 'logger.dart';

Future<void> seedFirstDate() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;

  final milestone = Milestone(
    id: '', // Firestore will generate this
    title: "First Date",
    date: DateTime(2026, 2, 14),
    author: "Khent",
    description: """Okay what happened here is i asked her out for valentines and it seems she was shocked i guess? I dont know why pero she was like “OMLLLL” pero its understandable since from her words, its her first time having someone ask her out for valentines pud daw, and for me, its also gonna be my first time giving out flowers so im kinda nervous too, so fast forward nagkita mi at 5:30 since mao na ang sabot and it was kinda cute kay nag tago sya atbang sa csu and not exactly at our meetup place which is 7/11, cutiee kaayo na and damn was i starstruck sa iyahang beauty, i know shes beautiful already based from her pics pero the beauty when seen personally is even a whole’nother level so i kinda forgot my script and even when i finally remembered it, it’s useless cause pan os na ang scene pero either way wa mi nagdugay didto csu since niadto mi diretso sa zackies and we talked there, thats where i knew her abit, specially her hobbies and about her love with ethel cain and her songs, the highlight really was just the fact that she didnt get uncomfy i guess? She really was in the mood to talk maybe cause i asked about ethel cain and the convo swayed from there making it work out best, either way i can say rhat i really did clutch Valentines, we took cute pictures and did a trend nga kabalo sya which was to put the flower para tabunan among faces in rhat video, it will look like a lowkey fit check or ootd something which was cuteee. Ofc ended the night nga gihatud nako sya and it seems tapok2 sya? Or maybe wa ra kaabot, idk pero didto sya sa luyo sa csu, i hope maka adto gyud ko door to door""",
    imageUrls: [
      'assets/images/milestones/valentines_khent_1.jpg',
      'assets/images/milestones/valentines_khent_2.png',
      'assets/images/milestones/valentines_khent_3.jpg',
      'assets/images/milestones/valentines_khent_4.jpg',
    ],
  );

  await db.collection('milestones').add(milestone.toFirestore());
  Logger.i("✅ Successfully seeded 'First Date' memory!");
}

void main() async {
  await seedFirstDate();
}
