import 'package:flutter/material.dart';
import '../../data/models/music_status.dart';
import 'package:intl/intl.dart';

import 'listen_along_popup.dart';

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
      child: Opacity(
        opacity: isLive ? 1.0 : 0.7,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.pink.shade300,
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
                                color: Colors.pink.withOpacity(0.3),
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
                                    color: Colors.pink.shade50,
                                    child: const Icon(Icons.music_note, color: Colors.pink),
                                  ),
                                )
                              : Container(
                                  color: Colors.pink.shade50,
                                  child: const Icon(Icons.music_note, color: Colors.pink),
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
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.pink,
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
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A4A4A),
                              ),
                            ),
                        Text(
                          status.artistName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!isLive) ...[
                          const SizedBox(height: 8),
                          Text(
                            status.timestamp != null 
                              ? 'Last heard at ${_formatTime(status.timestamp!)}'
                              : 'Last heard',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade400,
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
          color: Colors.pink,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
