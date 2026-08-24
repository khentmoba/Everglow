import 'package:flutter/material.dart';

import '../../../xp/data/services/xp_service.dart';
import '../../../xp/domain/models/user_progress.dart';
import '../../../xp/presentation/widgets/xp_progress_bar.dart';

/// Binds the XP progress stream to the current uid without re-creating the
/// Firestore listener on every unrelated auth notification.
class XpProgressSection extends StatefulWidget {
  final String? uid;
  const XpProgressSection({super.key, required this.uid});

  @override
  State<XpProgressSection> createState() => _XpProgressSectionState();
}

class _XpProgressSectionState extends State<XpProgressSection> {
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
    _stream = (uid == null || uid.isEmpty) ? null : _service.watchProgress(uid);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<UserProgress?>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return XPProgressBar(progress: snapshot.data!);
      },
    );
  }
}
