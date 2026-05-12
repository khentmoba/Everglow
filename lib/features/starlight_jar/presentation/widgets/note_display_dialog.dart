import 'package:flutter/material.dart';
import '../../domain/models/star_note.dart';

class NoteDisplayDialog extends StatelessWidget {
  final StarNote note;

  const NoteDisplayDialog({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.pink[100]!,
              Colors.pink[50]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.pink[200]!.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.pink, size: 40),
            const SizedBox(height: 16),
            Text(
              note.content,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.pink[800],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "— ${note.author.toUpperCase()}",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.pink[300],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${note.timestamp.month}/${note.timestamp.day}/${note.timestamp.year}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.pink[200],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.pink[300],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.pink[100]!),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }
}
