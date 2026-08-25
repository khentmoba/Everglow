import 'package:flutter/material.dart';

import '../../../xp/data/services/xp_service.dart';
import '../../../xp/domain/models/user_progress.dart';
import '../../../xp/presentation/widgets/xp_progress_bar.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';

/// Binds the XP progress stream to the current uid without re-creating the
/// Firestore listener on every unrelated auth notification.
///
/// Keeps a static in-memory cache of the last `UserProgress` per uid so
/// a remount (e.g. after the gateway door animation) can paint instantly
/// from cache instead of flashing `SizedBox.shrink` -> bar.
class XpProgressSection extends StatefulWidget {
  final String? uid;
  const XpProgressSection({super.key, required this.uid});

  @override
  State<XpProgressSection> createState() => _XpProgressSectionState();
}

class _XpProgressSectionState extends State<XpProgressSection> {
  static final Map<String, UserProgress> _cache = {};
  final XPService _service = XPService();
  Stream<UserProgress?>? _stream;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant XpProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _bind();
  }

  void _bind() {
    final uid = widget.uid;
    if (uid == null || uid.isEmpty) {
      _stream = null;
    } else {
      _stream = _service.watchProgress(uid).map((p) {
        if (p != null) _cache[uid] = p;
        return p;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    final uid = widget.uid;
    if (stream == null) return const SizedBox.shrink();

    final cached = (uid != null && uid.isNotEmpty) ? _cache[uid] : null;

    // Reserve the bar's height while waiting so the dashboard doesn't jump
    // when the first snapshot arrives (or when switching users).
    const skeleton = Padding(
      padding: EdgeInsets.symmetric(horizontal: 0),
      child: EverglowSkeleton(height: 92, radius: 24),
    );

    return StreamBuilder<UserProgress?>(
      stream: stream,
      initialData: cached,
      builder: (context, snapshot) {
        final data = snapshot.data ?? cached;
        if (data == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return skeleton;
          }
          // Stream emitted null (doc doesn't exist yet — XP init still pending)
          // Keep skeleton rather than collapsing to 0 height.
          if (!snapshot.hasData) return skeleton;
          return const SizedBox.shrink();
        }
        return XPProgressBar(progress: data);
      },
    );
  }
}