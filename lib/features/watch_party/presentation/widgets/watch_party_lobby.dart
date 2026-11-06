import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/tmdb_images.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../data/models/watch_party_room.dart';
import '../../data/services/watch_party_service.dart';
import '../screens/watch_party_screen.dart' deferred as watch_party_lib;

/// The room picker: every named room, who is hosting, what is playing,
/// and one clear way to create another. Used as a full screen from the
/// dashboard and inline inside Cinema's Watch Together tab.
class WatchPartyLobby extends StatefulWidget {
  /// The cinema tab already draws its own page header, so the embedded
  /// copy skips the big title and keeps just the rooms.
  final bool embedded;

  const WatchPartyLobby({super.key, this.embedded = false});

  @override
  State<WatchPartyLobby> createState() => _WatchPartyLobbyState();
}

class _WatchPartyLobbyState extends State<WatchPartyLobby> {
  final WatchPartyService _service = WatchPartyService();
  Stream<List<WatchPartyRoom>>? _rooms;
  String? _uid;
  String? _partnerUid;
  bool _opening = false;
  bool _navigating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (uid == null || partnerUid == null) return;
    if (uid != _uid) {
      _uid = uid;
      _partnerUid = partnerUid;
      _rooms = _service.getRoomsStream(uid);
    }
  }

  Future<void> _createRoom() async {
    final uid = _uid;
    final partnerUid = _partnerUid;
    if (uid == null || partnerUid == null) return;
    final auth = context.read<AuthService>();
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CreateRoomSheet(),
    );
    if (name == null || !mounted) return;
    setState(() => _opening = true);
    try {
      final room = await _service.createRoom(
        hostUid: uid,
        hostName: auth.currentUser ?? '',
        partnerUid: partnerUid,
        partnerName: auth.partnerName,
        name: name,
      );
      if (!mounted) return;
      await _openRoom(room);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the room. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openRoom(WatchPartyRoom room) async {
    if (_navigating) return;
    final uid = _uid;
    if (uid == null) return;
    setState(() {
      _opening = true;
      _navigating = true;
    });
    try {
      var toOpen = room;
      if (!room.isLive()) {
        await _service.reopenRoom(roomId: room.id, updatedBy: uid);
        toOpen = room.copyWith(
          active: true,
          state: 'paused',
          updatedAt: DateTime.now(),
          updatedBy: uid,
        );
      }
      await watch_party_lib.loadLibrary();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => watch_party_lib.WatchPartyScreen(
            initialRoom: toOpen,
            isHost: toOpen.hostUid == uid,
          ),
        ),
      );
    } finally {
      _navigating = false;
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _deleteRoom(WatchPartyRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.inkDeep,
        title: Text(
          'Delete "${room.name.isEmpty ? 'Our room' : room.name}"?',
          style: AppTypography.outfitHeading.copyWith(
            color: AppColors.petalWhite,
            fontSize: 17,
          ),
        ),
        content: Text(
          'This removes the room. It cannot be undone.',
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.textMedium,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _service.deleteRoom(room.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isCoupleUser) {
      return const _CoupleOnlyCard();
    }
    return StreamBuilder<List<WatchPartyRoom>>(
      stream: _rooms,
      builder: (context, snap) {
        if (snap.hasError) {
          return _LobbyMessage(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load your rooms',
            body: 'Check the connection, then try again.',
            action: TextButton(
              onPressed: () {
                final uid = _uid;
                if (uid == null) return;
                setState(() => _rooms = _service.getRoomsStream(uid));
              },
              child: const Text('Retry'),
            ),
          );
        }
        final rooms = snap.data ?? const <WatchPartyRoom>[];
        final loading = snap.connectionState == ConnectionState.waiting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded) _buildHeader(context),
            _buildCreateButton(),
            const SizedBox(height: AppSpacing.md),
            if (loading && rooms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.deepRose,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (rooms.isEmpty)
              const _LobbyMessage(
                icon: Icons.meeting_room_outlined,
                title: 'No rooms yet',
                body:
                    'Create one room for movie nights, one for anime, or one for each mood. No codes, no passwords.',
              )
            else
              for (final room in rooms) ...[
                WatchPartyRoomCard(
                  room: room,
                  myUid: _uid ?? '',
                  onTap: () => _openRoom(room),
                  onLongPress: () => _deleteRoom(room),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Watch Together',
            style: AppTypography.cormorantBoldWhite.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick a room, or make a new one. Both of you can walk in.',
            style: AppTypography.outfitWhite.copyWith(
              color: AppColors.textMedium,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return Semantics(
      button: true,
      label: 'Create a watch party room',
      child: GestureDetector(
        onTap: _opening ? null : _createRoom,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepRose, AppColors.rosePressed],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.add_rounded,
                color: AppColors.petalWhite,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Create a room',
                  style: AppTypography.outfitBold.copyWith(
                    color: AppColors.petalWhite,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                'No password',
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite.withValues(alpha: 0.72),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One room in the picker. Public so the phone/tablet layout test can
/// pump the exact card the app uses.
class WatchPartyRoomCard extends StatelessWidget {
  final WatchPartyRoom room;
  final String myUid;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const WatchPartyRoomCard({
    super.key,
    required this.room,
    required this.myUid,
    required this.onTap,
    this.onLongPress,
  });

  String get _posterUrl {
    final path = room.posterPath;
    if (path.isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return TmdbImages.posterFor(path);
  }

  String get _subtitle {
    if (!room.hasMedia) return 'Nothing chosen yet';
    if (room.mediaType == 'tv') {
      return '${room.title} · S${room.season ?? 1} E${room.episode ?? 1}';
    }
    return room.title;
  }

  @override
  Widget build(BuildContext context) {
    final live = room.isLive();
    final hosting = room.hostUid == myUid;
    final accent = live ? AppColors.success : AppColors.mutedPurple;
    return Semantics(
      button: true,
      label: '${room.name.isEmpty ? 'Our room' : room.name}, $_subtitle',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: live
                  ? AppColors.deepRose.withValues(alpha: 0.55)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 52,
                  height: 72,
                  child: _posterUrl.isEmpty
                      ? Container(
                          color: AppColors.shimmerBase,
                          child: const Icon(
                            Icons.movie_filter_rounded,
                            color: AppColors.mutedPurple,
                            size: 24,
                          ),
                        )
                      : AppNetworkImage(
                          imageUrl: _posterUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            room.name.isEmpty ? 'Our room' : room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitHeading.copyWith(
                              color: AppColors.petalWhite,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            live ? 'LIVE' : 'IDLE',
                            style: AppTypography.outfitWhite.copyWith(
                              color: accent,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppColors.textMedium,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hosting ? 'You are hosting' : '${room.hostName} is hosting',
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                live ? Icons.play_arrow_rounded : Icons.chevron_right_rounded,
                color: live ? AppColors.roseQuartz : AppColors.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRoomSheet extends StatefulWidget {
  const _CreateRoomSheet();

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  final TextEditingController _name = TextEditingController(text: 'Our room');
  static const _suggestions = ['Movie Night', 'Anime Night', 'Cozy Sunday'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.inkDeep,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: AppColors.moonlight.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Name this room',
              style: AppTypography.outfitHeading.copyWith(
                color: AppColors.petalWhite,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A room is a place you can come back to. No code to share.',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 32,
              textCapitalization: TextCapitalization.words,
              style: AppTypography.outfitWhite.copyWith(fontSize: 15),
              cursorColor: AppColors.deepRose,
              onSubmitted: (value) => _done(value),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.shimmerBase,
                hintText: 'Our room',
                hintStyle: AppTypography.outfitMuted.copyWith(
                  color: AppColors.mutedPurple,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _suggestions)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _name.text = suggestion);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.deepRose.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: AppColors.deepRose.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        suggestion,
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => _done(_name.text),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.auroraRose, AppColors.deepRose],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Center(
                  child: Text(
                    'Create room',
                    style: AppTypography.outfitBold.copyWith(
                      color: AppColors.petalWhite,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _done(String value) {
    final name = value.trim();
    Navigator.of(context).pop(name.isEmpty ? 'Our room' : name);
  }
}

class _LobbyMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _LobbyMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.roseQuartz, size: 26),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTypography.outfitHeading.copyWith(
              color: AppColors.petalWhite,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppTypography.outfitWhite.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 6), action!],
        ],
      ),
    );
  }
}

class _CoupleOnlyCard extends StatelessWidget {
  const _CoupleOnlyCard();

  @override
  Widget build(BuildContext context) {
    return const _LobbyMessage(
      icon: Icons.favorite_border_rounded,
      title: 'Just for the two of you',
      body: 'Watch Together is available on the couple profiles.',
    );
  }
}
