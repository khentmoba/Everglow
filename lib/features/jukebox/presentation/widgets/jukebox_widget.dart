import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/env_config.dart';
import '../providers/jukebox_provider.dart';
import 'music_card.dart';
import '../../data/models/music_status.dart';

import 'package:marquee/marquee.dart';
import 'package:confetti/confetti.dart';
import 'vinyl_record.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

class JukeboxWidget extends StatefulWidget {
  const JukeboxWidget({super.key});

  @override
  State<JukeboxWidget> createState() => _JukeboxWidgetState();
}

class _JukeboxWidgetState extends State<JukeboxWidget> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _triggerHearts(MusicStatus status) {
    if (status.isPlaying && status.artistName.toLowerCase() == 'ethel cain') {
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final khentUser = EnvConfig.lastfmUserKhent;
    final clairUser = EnvConfig.lastfmUserClair;

    return StreamBuilder<Map<String, MusicStatus>>(
      stream: context.read<JukeboxProvider>().statusStream,
      builder: (context, snapshot) {
        // Fallback to empty if no data yet, though provider now seeds it
        final statuses = snapshot.data ?? {};
        final khentStatus = statuses[khentUser] ?? MusicStatus.empty(khentUser);
        final clairStatus = statuses[clairUser] ?? MusicStatus.empty(clairUser);

        // Check for Ethel Cain
        _triggerHearts(khentStatus);
        _triggerHearts(clairStatus);

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.velvet.withValues(alpha: 0.72),
                    AppColors.inkDeep.withValues(alpha: 0.72),
                  ],
                ),
                borderRadius: AppRadius.radiusX2,
                border: Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.inkDeep.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isMobile = constraints.maxWidth < 600;

                  Widget buildCard(MusicStatus status, String title) {
                    return MusicCard(
                      status: status,
                      title: title,
                      vinylWidget: const VinylRecord(),
                      marqueeWidget: status.trackName.length > 20
                          ? SizedBox(
                              height: 24,
                              child: Marquee(
                                text: status.trackName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.petalWhite,
                                ),
                                scrollAxis: Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                blankSpace: 20.0,
                                velocity: 30.0,
                                pauseAfterRound: const Duration(seconds: 1),
                                accelerationDuration: const Duration(
                                  seconds: 1,
                                ),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(
                                  milliseconds: 500,
                                ),
                                decelerationCurve: Curves.easeOut,
                              ),
                            )
                          : null,
                    );
                  }

                  if (isMobile) {
                    return Column(
                      children: [
                        buildCard(khentStatus, 'Khent is vibing to...'),
                        const SizedBox(height: 16),
                        buildCard(clairStatus, 'Clair is vibing to...'),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: buildCard(
                            khentStatus,
                            'Khent is vibing to...',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: buildCard(
                            clairStatus,
                            'Clair is vibing to...',
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.pink, Colors.redAccent, Colors.pinkAccent],
              createParticlePath: _drawHeart,
            ),
          ],
        );
      },
    );
  }

  Path _drawHeart(Size size) {
    final double width = size.width;
    final double height = size.height;
    final Path path = Path();

    path.moveTo(0.5 * width, height * 0.35);
    path.cubicTo(
      0.2 * width,
      height * 0.1,
      -0.2 * width,
      height * 0.6,
      0.5 * width,
      height,
    );
    path.cubicTo(
      1.2 * width,
      height * 0.6,
      0.8 * width,
      height * 0.1,
      0.5 * width,
      height * 0.35,
    );
    path.close();
    return path;
  }
}
