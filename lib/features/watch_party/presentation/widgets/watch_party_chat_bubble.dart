import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:everglow/core/theme/app_theme.dart';

/// A single chat bubble for the Watch Together chat. Reuses the
/// rose-quartz / deep-rose palette from the dashboard's Sanctuary
/// Chat so the two surfaces feel like siblings, but kept as a
/// separate widget so the Watch Together visual identity can drift
/// independently later (different background, different bubble
/// shapes, etc.).
class WatchPartyChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String sender;
  final DateTime timestamp;

  const WatchPartyChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.sender,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(timestamp);
    final isToday = DateTime.now().day == timestamp.day &&
        DateTime.now().month == timestamp.month &&
        DateTime.now().year == timestamp.year;

    return FadeInUp(
      duration: const Duration(milliseconds: 280),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  sender.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.blushGold.withValues(alpha: 0.85),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.deepRose
                    : Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isToday ? timeStr : timeStr,
                    style: GoogleFonts.outfit(
                      color: isMe
                          ? AppTheme.petalWhite.withValues(alpha: 0.7)
                          : AppTheme.roseQuartz.withValues(alpha: 0.55),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
