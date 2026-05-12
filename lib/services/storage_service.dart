import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class StorageService extends ChangeNotifier {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(Uint8List fileData, String fileName, String userId) async {
    try {
      final String path = "memories/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName";
      final Reference ref = _storage.ref().child(path);
      
      final UploadTask uploadTask = ref.putData(fileData);
      final TaskSnapshot snapshot = await uploadTask;
      
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }
}
