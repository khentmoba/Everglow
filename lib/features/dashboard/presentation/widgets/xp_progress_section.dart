import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/logger.dart';
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
///
/// Hardened against the "always buffering" grey bar seen in screenshots:
///  1. Doc doesn't exist yet (null emission) — show Level 1 / 0 XP and
///     trigger initializeProgress in background.
///  2. Firestore WebChannel hang / permission race (withFirestoreTimeout
///     closes after 5s with no first event) — retry 3x then show retry UI.
///  3. Network error — same retry.
///  4. Absolute fallback: if no data after 6s regardless of stream state,
///     force a zero-state bar so the skeleton never spins forever.
class XpProgressSection extends StatefulWidget {
  final String? uid;
  const XpProgressSection({super.key, required this.uid});

  @override
  State<XpProgressSection> createState() => _XpProgressSectionState();
}

class _XpProgressSectionState extends State<XpProgressSection> {
  static final Map<String, UserProgress> _cache = {};
  final XPService _service = XPService();
  StreamSubscription<UserProgress?>? _sub;
  Timer? _retryTimer;
  Timer? _fallbackTimer;
  UserProgress? _progress;
  bool _isLoading = true;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  String? _boundUid;

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

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _bind() {
    _sub?.cancel();
    _retryTimer?.cancel();
    _fallbackTimer?.cancel();
    final uid = widget.uid;
    _boundUid = uid;
    _retryCount = 0;
    _hasError = false;

    if (uid == null || uid.isEmpty) {
      _progress = null;
      _isLoading = false;
      return;
    }

    final cached = _cache[uid];
    if (cached != null) {
      _progress = cached;
      _isLoading = false;
    } else {
      _progress = null;
      _isLoading = true;
    }
    if (mounted) setState(() {});

    _subscribe(uid);

    // Absolute fallback: never let the shimmer spin forever. If the
    // Firestore stream is hung (no data, no error, no done) for 6s,
    // force a zero-state bar and try to seed the doc.
    _fallbackTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _boundUid != uid) return;
      if (_progress == null && _isLoading && !_hasError) {
        Logger.w('[XpProgressSection] fallback timer — forcing zero state for $uid');
        unawaited(_service.initializeProgress(uid).catchError((Object e) {
          Logger.e('[XpProgressSection] fallback initializeProgress failed', error: e);
        }));
        setState(() {
          _progress = UserProgress(
            uid: uid,
            xpTotal: 0,
            level: 1,
            streak: 0,
            lastActivity: DateTime.now(),
          );
          _isLoading = false;
          _hasError = false;
        });
      }
    });
  }

  void _subscribe(String uid) {
    _sub?.cancel();
    _retryTimer?.cancel();
    _sub = _service.watchProgress(uid).map((p) {
      if (p != null) _cache[uid] = p;
      return p;
    }).listen(
      (data) {
        if (!mounted || _boundUid != uid) return;
        _fallbackTimer?.cancel();
        _retryCount = 0;
        if (data == null) {
          Logger.w('[XpProgressSection] progress doc null for $uid — seeding zero state');
          unawaited(_service.initializeProgress(uid).catchError((Object e) {
            Logger.e('[XpProgressSection] initializeProgress failed', error: e);
          }));
          final fallback = _cache[uid] ??
              UserProgress(
                uid: uid,
                xpTotal: 0,
                level: 1,
                streak: 0,
                lastActivity: DateTime.now(),
              );
          setState(() {
            _progress = fallback;
            _isLoading = false;
            _hasError = false;
          });
        } else {
          setState(() {
            _progress = data;
            _isLoading = false;
            _hasError = false;
          });
        }
      },
      onError: (Object e, StackTrace st) {
        if (!mounted || _boundUid != uid) return;
        _fallbackTimer?.cancel();
        Logger.e('[XpProgressSection] watchProgress error', error: e, stackTrace: st);
        if (_retryCount < _maxRetries) {
          _retryCount++;
          _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
            if (mounted && _boundUid == uid) _subscribe(uid);
          });
        } else {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      },
      onDone: () {
        if (!mounted || _boundUid != uid) return;
        _fallbackTimer?.cancel();
        if (_progress == null && !_hasError) {
          Logger.w('[XpProgressSection] stream closed with no data for $uid (timeout?)');
          if (_retryCount < _maxRetries) {
            _retryCount++;
            _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
              if (mounted && _boundUid == uid) _subscribe(uid);
            });
          } else {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        }
      },
    );
  }

  void _retry() {
    final uid = widget.uid;
    if (uid == null || uid.isEmpty) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
      _retryCount = 0;
    });
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _boundUid != uid) return;
      if (_progress == null && _isLoading && !_hasError) {
        Logger.w('[XpProgressSection] fallback timer (retry) — forcing zero state for $uid');
        setState(() {
          _progress = UserProgress(
            uid: uid,
            xpTotal: 0,
            level: 1,
            streak: 0,
            lastActivity: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    });
    _subscribe(uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    const skeleton = Padding(
      padding: EdgeInsets.symmetric(horizontal: 0),
      child: EverglowSkeleton(height: 92, radius: 24),
    );

    if (_hasError) {
      return Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.velvet.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 20, color: AppColors.roseQuartz.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Couldn't load XP",
                      style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Check connection and retry',
                      style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite.withValues(alpha: 0.5), fontSize: 11)),
                ],
              ),
            ),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.deepRose.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.deepRose.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 14, color: AppColors.petalWhite),
                    const SizedBox(width: 6),
                    Text('Retry',
                        style: AppTypography.outfitBold
                            .copyWith(fontSize: 12, color: AppColors.petalWhite)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_progress != null) {
      return XPProgressBar(progress: _progress!);
    }

    if (_isLoading) return skeleton;

    return XPProgressBar(
      progress: UserProgress(
        uid: uid,
        xpTotal: 0,
        level: 1,
        streak: 0,
        lastActivity: DateTime.now(),
      ),
    );
  }
}
