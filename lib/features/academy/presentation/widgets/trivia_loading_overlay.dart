import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class TriviaLoadingOverlay extends StatelessWidget {
  final String message;

  const TriviaLoadingOverlay({
    super.key,
    this.message = 'Downloading new study materials... 📚',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.pink.withOpacity(0.3),
      child: Center(
        child: BounceInDown(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Spin(
                  infinite: true,
                  duration: const Duration(seconds: 3),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 50,
                    color: Colors.pink,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink[400],
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    backgroundColor: Color(0xFFFFE6F2),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.pink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
