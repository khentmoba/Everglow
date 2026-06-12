import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/gamified_background.dart';
import '../../models/assault_match.dart';
import '../../services/assault_match_service.dart';
import 'assault_cube_game_screen.dart';

class AssaultCubeResultsScreen extends StatefulWidget {
  final AssaultMatch match;
  final String userId;

  const AssaultCubeResultsScreen({
    super.key,
    required this.match,
    required this.userId,
  });

  @override
  State<AssaultCubeResultsScreen> createState() => _AssaultCubeResultsScreenState();
}

class _AssaultCubeResultsScreenState extends State<AssaultCubeResultsScreen> {
  final AssaultMatchService _matchService = AssaultMatchService();
  StreamSubscription<DocumentSnapshot>? _matchSub;
  bool _requestingRematch = false;

  @override
  void initState() {
    super.initState();
    _listenForRematch();
  }

  void _listenForRematch() {
    // Listen to the match document. If status changes to active, automatically push back to the game.
    _matchSub = _matchService.watchMatch(widget.match.matchId).listen((snap) {
      if (!mounted || !snap.exists) return;
      final updatedMatch = AssaultMatch.fromFirestore(snap);
      if (updatedMatch.status == AssaultMatchStatus.active) {
        _matchSub?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AssaultCubeGameScreen(
              mode: 'multi',
              matchId: updatedMatch.matchId,
              userId: widget.userId,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWinner = widget.match.winnerId == widget.userId;
    final isHost = widget.match.hostId == widget.userId;

    final myKills = isHost ? widget.match.hostKills : widget.match.participantKills;
    final oppKills = isHost ? widget.match.participantKills : widget.match.hostKills;
    final myHp = isHost ? widget.match.hostHp : widget.match.participantHp;
    final oppHp = isHost ? widget.match.participantHp : widget.match.hostHp;

    final opponentName = isHost ? 'Clair' : 'Khent';

    String resultTitle;
    IconData resultIcon;
    Color resultColor;

    if (isWinner) {
      resultTitle = 'VICTORY!';
      resultIcon = Icons.emoji_events_rounded;
      resultColor = AppTheme.blushGold;
    } else {
      resultTitle = 'DEFEAT';
      resultIcon = Icons.favorite_border_rounded;
      resultColor = AppTheme.deepRose;
    }

    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Icon(resultIcon, size: 80, color: resultColor),
                  const SizedBox(height: 16),
                  Text(
                    resultTitle,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: resultColor,
                      letterSpacing: 2.0,
                      shadows: [
                        BoxShadow(
                          color: resultColor.withValues(alpha: 0.35),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Player stats cards
                  _buildStatCard(
                    title: 'Your Performance',
                    kills: myKills,
                    hp: myHp,
                    color: AppTheme.softLavender,
                    isWinner: isWinner,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: "$opponentName's Performance",
                    kills: oppKills,
                    hp: oppHp,
                    color: AppTheme.roseQuartz,
                    isWinner: !isWinner,
                  ),

                  const SizedBox(height: 50),

                  if (_requestingRematch)
                    Column(
                      children: [
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(color: AppTheme.roseQuartz, strokeWidth: 3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Resetting arena...',
                          style: GoogleFonts.outfit(color: AppTheme.roseQuartz, fontSize: 14),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _requestingRematch = true);
                            try {
                              await _matchService.resetMatchForRematch(widget.match.matchId);
                            } catch (e) {
                              if (mounted) {
                                setState(() => _requestingRematch = false);
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed to request rematch: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.deepRose,
                            foregroundColor: AppTheme.petalWhite,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 5,
                          ),
                          child: Text(
                            'REMATCH',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                          child: Text(
                            'Return to Hub',
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite.withValues(alpha: 0.6),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int kills,
    required int hp,
    required Color color,
    required bool isWinner,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWinner
              ? AppTheme.blushGold.withValues(alpha: 0.45)
              : AppTheme.moonlight.withValues(alpha: 0.18),
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.petalWhite,
                ),
              ),
              if (isWinner)
                const Icon(Icons.star_rounded, color: AppTheme.blushGold, size: 22),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KILLS',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.petalWhite.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$kills',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'REMAINING HP',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.petalWhite.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hp <= 0 ? 'ELIMINATED' : '$hp%',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: hp <= 0 ? AppTheme.deepRose : AppTheme.softLavender,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
