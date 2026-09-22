import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/logger.dart';
import '../../../xp/data/services/xp_service.dart';
import '../../../xp/domain/models/user_progress.dart';
import '../../../xp/presentation/widgets/xp_progress_bar.dart';
import 'dashboard_load_tracker.dart';

/// Binds the XP progress stream to the current uid without re-creating the
/// Firestore listener on every unrelated auth notification.
///
/// Keeps a static in-memory cache of the last `UserProgress` per uid so
/// a remount (e.g. after the gateway door animation) can paint instantly
/// from cache instead of flashing `SizedBox.shrink` -> bar.
///
/// Optimistic first paint: the bar renders instantly with cached data or a
/// Level 1 / 0 XP zero-state while the Firestore stream resolves in the
/// background. The stream used to gate first paint behind a skeleton +
/// 5s `withFirestoreTimeout` + 3 retries (≈20s grey slab in screenshots
/// when the WebChannel was contended) — now retries are silent and never
/// replace the bar.
class XpProgressSection extends StatefulWidget {
  final String? uid;

  /// Test seam for the XP stream. Production always uses
  /// `XPService().watchProgress`, which needs Firestore.
  final Stream<UserProgress?> Function(String uid)? watchProgress;

  const XpProgressSection({super.key, required this.uid, this.watchProgress});

  @override
  State<XpProgressSection> createState() => _XpProgressSectionState();
}

class _XpProgressSectionState extends State<XpProgressSection> {
  static final Map<String, UserProgress> _cache = {};
  final XPService _service = XPService();
  StreamSubscription<UserProgress?>? _sub;
  Timer? _retryTimer;
  UserProgress? _progress;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  String? _boundUid;

  static UserProgress _zero(String uid) => UserProgress(
    uid: uid,
    xpTotal: 0,
    level: 1,
    streak: 0,
    lastActivity: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _bind();
    // No mark here on purpose: the optimistic zero-state bar is a
    // placeholder, not readiness. Stars count only when XP truly
    // settles — a cache hit, a real snapshot, or exhausted retries —
    // so the veil percent never climbs on a guess.
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
    super.dispose();
  }

  void _bind() {
    _sub?.cancel();
    _retryTimer?.cancel();
    final uid = widget.uid;
    _boundUid = uid;
    _retryCount = 0;
    _hasError = false;

    if (uid == null || uid.isEmpty) {
      _progress = null;
      // Settled: with no uid there is nothing to load and the card
      // renders empty, so the veil must not wait on us.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reportLoaded();
      });
      return;
    }

    // Optimistic paint: show cached progress — or a zero-state bar —
    // synchronously so first paint never waits on Firestore.
    final cached = _cache[uid];
    _progress = cached ?? _zero(uid);
    if (mounted) setState(() {});
    // A cache hit paints real data, so it counts — reported post-frame
    // since notifyListeners must not fire during initState's build pass.
    // A zero-state paint counts for nothing: the stream below must answer.
    if (cached != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reportLoaded();
      });
    }

    _subscribe(uid);
  }

  void _subscribe(String uid) {
    _sub?.cancel();
    _retryTimer?.cancel();
    final source =
        widget.watchProgress?.call(uid) ?? _service.watchProgress(uid);
    _sub = source
        .map((p) {
          if (p != null) _cache[uid] = p;
          return p;
        })
        .listen(
          (data) {
            if (!mounted || _boundUid != uid) return;
            _retryCount = 0;
            // First answer from Firestore — real data or a genuine "no doc"
            // (null) — so the veil can count us.
            _reportLoaded();
            if (data == null) {
              // Doc doesn't exist yet — keep the optimistic zero-state visible
              // and seed in the background (fire-and-forget with its own timeout).
              Logger.w(
                '[XpProgressSection] progress doc null for $uid — seeding in bg',
              );
              unawaited(
                _service.initializeProgress(uid).catchError((Object e) {
                  Logger.e(
                    '[XpProgressSection] initializeProgress failed',
                    error: e,
                  );
                }),
              );
              // No setState needed: zero-state already painted in _bind().
              // Only clear a prior error flag.
              if (_hasError && mounted) setState(() => _hasError = false);
            } else {
              setState(() {
                _progress = data;
                _hasError = false;
              });
            }
          },
          onError: (Object e, StackTrace st) {
            if (!mounted || _boundUid != uid) return;
            Logger.e(
              '[XpProgressSection] watchProgress error (bg retry)',
              error: e,
              stackTrace: st,
            );
            _scheduleSilentRetry(uid);
          },
          onDone: () {
            if (!mounted || _boundUid != uid) return;
            // withFirestoreTimeout closes the stream when the first snapshot
            // never arrives (WebChannel hang). Retry silently — the optimistic
            // bar stays on screen, so the user never sees a skeleton.
            Logger.w(
              '[XpProgressSection] stream closed with no data for $uid — bg retry',
            );
            _scheduleSilentRetry(uid);
          },
        );
  }

  void _scheduleSilentRetry(String uid) {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
        if (mounted && _boundUid == uid) _subscribe(uid);
      });
    } else if (mounted && !_hasError) {
      // Retries exhausted: keep the optimistic bar, just flag for the
      // optional inline retry affordance (never replaces the bar).
      setState(() => _hasError = true);
      // The error state is final, so the veil can stop waiting on us
      // even though no XP arrived.
      _reportLoaded();
    }
  }

  /// First-screen progress: XP has settled (cache hit, real snapshot,
  /// or final error), so the load veil can count us. Marking is
  /// idempotent — cache hits, snapshots, and exhausted retries all
  /// funnel here safely. After dispose this is a no-op; a missing
  /// tracker is a wiring bug, so it logs instead of hiding.
  void _reportLoaded() {
    if (!mounted) return;
    try {
      context.read<DashboardLoadTracker>().mark(DashboardLoadSignal.stars);
    } catch (e, st) {
      Logger.e(
        '[XpProgressSection] failed to report stars load signal',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _retry() {
    final uid = widget.uid;
    if (uid == null || uid.isEmpty) return;
    setState(() {
      _hasError = false;
      _retryCount = 0;
    });
    _subscribe(uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    // Optimistic bar always wins — _progress is set synchronously in _bind,
    // so this paints on the very first frame with zero Firestore waiting.
    if (_progress != null) {
      return XPProgressBar(progress: _progress!);
    }

    if (_hasError) {
      return Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.velvet.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 20,
              color: AppColors.roseQuartz.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Couldn't load XP",
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Check connection and retry',
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deepRose.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.deepRose.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: AppColors.petalWhite,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Retry',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.petalWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Should be unreachable (_bind always sets _progress), but never show a
    // hanging skeleton — fall back to a zero-state bar.
    return XPProgressBar(progress: _zero(uid));
  }
}
