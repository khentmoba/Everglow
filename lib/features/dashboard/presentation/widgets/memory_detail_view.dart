import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../domain/models/milestone.dart';

class MemoryDetailOverlay extends StatelessWidget {
  final Milestone milestone;

  const MemoryDetailOverlay({super.key, required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: FadeInUp(
        duration: const Duration(milliseconds: 500),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.pink[100]!.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink[900],
                          ),
                        ),
                        Text(
                          DateFormat('MMMM d, yyyy').format(milestone.date),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.pink[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.pink),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author Tag
                      if (milestone.author != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.pink[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            "Memory by ${milestone.author} 🤍",
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.pink[800],
                            ),
                          ),
                        ),
                      
                      // Full Description
                      Text(
                        milestone.description,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.pink[950],
                          fontFamily: 'Quicksand',
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              
              // Bottom Accent
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite, color: Colors.pink[100], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Living Archive",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.pink[200],
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.favorite, color: Colors.pink[100], size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
