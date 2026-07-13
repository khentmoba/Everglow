import 'package:flutter/material.dart';
import '../../data/models/music_status.dart';
import 'package:intl/intl.dart';
import 'listen_along_popup.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class MusicCard extends StatelessWidget {
  final MusicStatus status;
  final String title;
  final Widget? vinylWidget;
  final Widget? marqueeWidget;
  final Widget? heartAnimationWidget;

  const MusicCard({
    super.key,
    required this.status,
    required this.title,
    this.vinylWidget,
    this.marqueeWidget,
    this.heartAnimationWidget,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLive = status.isPlaying;

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (context) => ListenAlongPopup(status: status),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isLive ? 1.0 : 0.65,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLive ? AppTheme.blushGold.withValues(alpha: 0.65) : AppTheme.moonlight.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
              if (isLive)
                BoxShadow(
                  color: AppTheme.deepRose.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.blushGold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      if (vinylWidget != null && isLive)
                        Positioned(
                          right: -30,
                          child: vinylWidget!,
                        ),
                      // Album Art
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            if (isLive)
                              BoxShadow(
                                color: AppTheme.deepRose.withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: status.imageUrl != null
                              ? Image.network(
                                  status.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    color: AppTheme.velvet,
                                    child: const Icon(Icons.music_note, color: AppTheme.roseQuartz),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.velvet,
                                  child: const Icon(Icons.music_note, color: AppTheme.roseQuartz),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLive)
                          Row(
                            children: [
                              _PulsingIndicator(),
                              const SizedBox(width: 8),
                              Text(
                                'LIVE',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warmAmber,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        marqueeWidget ??
                            Text(
                              status.trackName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.petalWhite,
                              ),
                            ),
                        Text(
                          status.artistName,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.petalWhite.withValues(alpha: 0.75),
                          ),
                        ),
                        if (!isLive) ...[
                          const SizedBox(height: 8),
                          Text(
                            status.timestamp != null 
                              ? 'Last heard at ${_formatTime(status.timestamp!)}'
                              : 'Last heard',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.petalWhite.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (heartAnimationWidget != null) heartAnimationWidget!,
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }
}

class _PulsingIndicator extends StatefulWidget {
  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppTheme.warmAmber,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
