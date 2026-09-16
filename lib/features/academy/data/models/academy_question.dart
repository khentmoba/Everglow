import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AcademyQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String category;

  AcademyQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'category': category,
    };
  }

  factory AcademyQuestion.fromMap(Map<String, dynamic> map, String docId) {
    final optionsRaw = map['options'];
    return AcademyQuestion(
      id: docId,
      questionText: _toStr(map['questionText']),
      options: optionsRaw is List
          ? optionsRaw.map((e) => e.toString()).toList()
          : const [],
      correctOptionIndex: _toInt(map['correctOptionIndex']),
      category: _toStr(map['category'], fallback: 'engineering'),
    );
  }

  static String _toStr(dynamic value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static int _toInt(dynamic value) => value is num ? value.toInt() : 0;

  factory AcademyQuestion.fromFirestore(DocumentSnapshot doc) {
    return AcademyQuestion.fromMap(doc.data() as Map<String, dynamic>? ?? const {}, doc.id);
  }

  static String generateId(String questionText) {
    final bytes = utf8.encode(questionText);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
