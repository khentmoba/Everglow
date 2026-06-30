import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/services/voice_chat_service.dart';

const _cCard = Color(0xFF1C1228);
const _cDeepRose = Color(0xFFC2185B);
const _cGreen = Color(0xFF4ADE80);
const _cMuted = Color(0xFF8A7A92);

class VoiceChatOverlay extends StatelessWidget {
  final VoiceChatService service;
  final String partnerName;

  const VoiceChatOverlay({
    super.key,
    required this.service,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 52,
      right: 12,
      child: ValueListenableBuilder<VoiceChatState>(
        valueListenable: service.state,
        builder: (_, state, _) {
          if (state == VoiceChatState.idle || state == VoiceChatState.ended) {
            return const SizedBox.shrink();
          }
          return _buildPill(context, state);
        },
      ),
    );
  }

  Widget _buildPill(BuildContext context, VoiceChatState state) {
      return ValueListenableBuilder<bool>(
        valueListenable: service.isMuted,
        builder: (_, muted, _) {
          final isConnecting = state == VoiceChatState.calling;
        final color = isConnecting ? _cMuted : (muted ? _cDeepRose : _cGreen);

        return GestureDetector(
          onTap: () => _showMenu(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: !isConnecting
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 6)
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
            Text(
              isConnecting
                  ? 'Voice...'
                  : muted
                      ? 'Muted'
                      : 'Live',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Voice Chat',
              style: GoogleFonts.cormorantGaramond(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Talking with $partnerName',
              style: GoogleFonts.outfit(
                color: _cMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<bool>(
              valueListenable: service.isMuted,
              builder: (_, muted, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconButton(
                      ctx,
                      icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: muted ? 'Unmute' : 'Mute',
                      color: muted ? _cDeepRose : _cGreen,
                      onTap: () {
                        service.toggleMute();
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(width: 24),
                    _iconButton(
                      ctx,
                      icon: Icons.call_end_rounded,
                      label: 'Disconnect',
                      color: _cDeepRose,
                      onTap: () {
                        service.endCall();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
