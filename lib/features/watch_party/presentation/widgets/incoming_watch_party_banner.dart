import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';

import '../../data/services/voice_chat_service.dart';
import '../../data/services/watch_party_service.dart';
import '../../data/models/watch_party_room.dart';
import '../screens/watch_party_screen.dart';

/// Strict-silent banner that appears at the top of the screen when
/// the partner has started a watch party. **No sound, no vibration
/// — visual only.** Tap → opens the watch party screen so the
/// callee can join the call.
///
/// Mounted at the app root (via `main.dart` wrapping `AuthWrapper`
/// in a `Stack`) so it shows up regardless of which screen the
/// user is on. Auto-clears the moment the user is on the watch
/// party screen (the watch party screen calls
/// `VoiceChatService.clearIncomingWatcher()` on init).
class IncomingWatchPartyBanner extends StatefulWidget {
  const IncomingWatchPartyBanner({super.key});

  @override
  State<IncomingWatchPartyBanner> createState() =>
      _IncomingWatchPartyBannerState();
}

class _IncomingWatchPartyBannerState extends State<IncomingWatchPartyBanner> {
  IncomingCall? _current;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _current = VoiceChatService.latestIncoming;
    VoiceChatService.incomingStream.listen(_onIncoming);
  }

  void _onIncoming(IncomingCall? incoming) {
    if (!mounted) return;
    setState(() => _current = incoming);
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _current;
    if (incoming == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: FadeInDown(
          duration: const Duration(milliseconds: 260),
          child: SlideInDown(
            duration: const Duration(milliseconds: 260),
            child: Stack(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap:
                        _navigating ? null : () => _openParty(context, incoming),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 40, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.deepRose.withValues(alpha: 0.92),
                            AppTheme.twilight.withValues(alpha: 0.92),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.roseQuartz.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.deepRose.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(incoming),
                          const SizedBox(width: 12),
                          Expanded(child: _buildText(context, incoming)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.roseQuartz,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Join',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.twilight,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppTheme.twilight,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      VoiceChatService.clearIncomingWatcher();
                      setState(() => _current = null);
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppTheme.petalWhite.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppTheme.petalWhite.withValues(alpha: 0.8),
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(IncomingCall incoming) {
    final initial = incoming.callerName.isNotEmpty
        ? incoming.callerName[0].toUpperCase()
        : '?';
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.roseQuartz,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.roseQuartz.withValues(alpha: 0.45),
            blurRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.twilight,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildText(BuildContext context, IncomingCall incoming) {
    final hasTitle = incoming.mediaTitle.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${incoming.callerName} started a watch party',
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          hasTitle
              ? 'Watching ${incoming.mediaTitle}${_episodeSuffix(incoming)}'
              : 'Tap to join',
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.7),
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _episodeSuffix(IncomingCall incoming) {
    if (incoming.mediaType != 'tv') return '';
    if (incoming.season == null || incoming.episode == null) return '';
    return ' · S${incoming.season}E${incoming.episode}';
  }

  Future<void> _openParty(BuildContext context, IncomingCall incoming) async {
    if (_navigating) return;
    setState(() => _navigating = true);

    try {
      final auth = context.read<AuthService>();
      final myUid = auth.uid;
      if (myUid == null) return;
      final roomId = incoming.roomId;

      // The voice_rooms doc carries the call metadata; the
      // watch_party_rooms doc carries the media metadata. Read
      // the latter so we can build a WatchPartyRoom for the
      // existing screen.
      final partySnap = await WatchPartyService().getRoom(roomId);
      if (!mounted) return;

      WatchPartyRoom toOpen;
      bool isHost = false;
      if (partySnap != null && partySnap.active) {
        toOpen = partySnap;
        isHost = partySnap.hostUid == myUid;
      } else {
        // Watch party room doesn't exist yet (caller may not have
        // finished writing it). Build a minimal placeholder so we
        // can at least navigate; the screen will recover from a
        // missing room.
        toOpen = WatchPartyRoom(
          id: roomId,
          hostUid: incoming.callerUid,
          hostName: incoming.callerName,
          partnerUid: myUid,
          partnerName: auth.currentUser ?? 'Partner',
          mediaType: incoming.mediaType,
          tmdbId: 0,
          isAnime: false,
          season: incoming.season,
          episode: incoming.episode,
          title: incoming.mediaTitle,
          posterPath: incoming.mediaPosterPath,
          state: 'paused',
          currentTime: 0.0,
          updatedAt: DateTime.now(),
          updatedBy: incoming.callerUid,
          createdAt: DateTime.now(),
          active: true,
        );
      }

      // Dismiss the banner immediately so the watch party screen
      // doesn't see its own incoming call on top.
      VoiceChatService.clearIncomingWatcher();

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WatchPartyScreen(initialRoom: toOpen, isHost: isHost),
        ),
      );
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }
}
