import 'dart:async';

import '../../../../core/services/on_this_day_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../bucket_list/data/services/bucket_list_service.dart';
import '../../../books/data/services/open_library_service.dart';
import '../../../books/data/services/our_books_service.dart';
import '../../../calendar/data/services/calendar_service.dart';
import '../../../cinema/data/services/tmdb/tmdb_watchlist_service.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../gallery/data/services/gallery_service.dart';
import '../../../journal/data/services/journal_service.dart';
import '../../../manga/data/services/mangakakalot_service.dart';
import '../../../starlight_jar/data/services/starlight_service.dart';
import '../../../tonight/data/services/tonight_service.dart';
import '../../data/services/letterbox_service.dart';
import '../../data/services/milestone_service.dart';

/// Warms Home's data right after entry, so scrolled-to sections render
/// instantly instead of showing skeletons.
///
/// Each entry below mirrors a deferred section's query with the same method
/// and args (see the "mirrors" notes). Firestore dedups identical active
/// queries to one backend listener, so when the section mounts later its
/// first snapshot is already here — no wait, no skeleton flash. Production
/// also runs with IndexedDB persistence, so the warmed docs sit in cache.
///
/// This warms DATA only: widgets still build lazily via [DeferredSection],
/// and images still decode as sections appear (full-res decode on web is
/// upstream-blocked, so pre-decoding would just move the jank to entry).
/// A full "wait for everything" veil was tried and removed (Sep 2026): it
/// held a frozen spinner while the same burst ran behind it.
///
/// Best-effort by design: every subscribe is guarded, errors only log, and
/// nothing here gates the load veil. If warming fails, sections load lazily
/// exactly as before — the failure mode is the status quo, never a break.
///
/// Drift note: if a section changes its query, update the matching entry
/// here or that section quietly falls back to lazy loading. Each entry
/// names the section file it mirrors.
class DashboardPreload {
  DashboardPreload._(this._subs);

  final List<StreamSubscription<dynamic>> _subs;

  /// Test seam: hold [streams] open with best-effort handlers.
  factory DashboardPreload.subscribe(List<Stream<dynamic>> streams) {
    final subs = <StreamSubscription<dynamic>>[];
    for (final stream in streams) {
      try {
        subs.add(
          stream.listen(
            (_) {},
            onError: (Object e) =>
                Logger.e('[Preload] warm query failed', error: e),
          ),
        );
      } catch (e) {
        Logger.e('[Preload] could not subscribe', error: e);
      }
    }
    return DashboardPreload._(subs);
  }

  /// Production entry: attach every deferred Home section's query now.
  ///
  /// Sections skip empty usernames, so warming does too. Non-couple
  /// branches mirror the sections' own fallbacks even though the router
  /// keeps cinema-only users off the dashboard.
  factory DashboardPreload.warmUp({
    required String userName,
    String? partner,
    required bool isCouple,
  }) {
    if (userName.isEmpty) return DashboardPreload._(const []);

    final hasPartner = isCouple && partner != null && partner.isNotEmpty;

    // One-shot reads: populate the cache for sections that load via
    // Future instead of a stream. Fire-and-forget with logged errors.
    unawaited(
      OnThisDayService().getAllMemories().then(
        (_) {},
        onError: (Object e) =>
            Logger.e('[Preload] on-this-day warmup failed', error: e),
      ),
    );
    final tmdb = TMDBService();
    unawaited(
      tmdb
          .getPreviewItems(
            userName,
            limit: TMDBWatchlistService.previewLimit,
            isAnime: true,
          )
          .then(
            (_) {},
            onError: (Object e) =>
                Logger.e('[Preload] anime preview warmup failed', error: e),
          ),
    );
    if (hasPartner) {
      unawaited(
        tmdb
            .getPreviewItems(
              partner,
              limit: TMDBWatchlistService.previewLimit,
              isAnime: true,
            )
            .then(
              (_) {},
              onError: (Object e) =>
                  Logger.e('[Preload] anime preview warmup failed', error: e),
            ),
      );
    }

    final streams = <Stream<dynamic>>[
      TonightService().watchActiveDecision(), // tonight_card.dart
      CalendarService().getUpcomingEvents(days: 60), // upcoming_countdowns + calendar_preview (same query)
      LetterboxService().notesPreview(limit: 10), // letterbox_view.dart
      StarlightService().getStarNotes(), // starlight_jar_widget.dart (limit 40 in service)
      MilestoneService().milestonesPreview(limit: 12), // timeline_view.dart
      GalleryService().getRecentPhotos(limit: 6), // gallery_preview.dart
      JournalService().watchPreview(limit: 12), // keepsakes_cluster.dart
      BucketListService().watchPreview(limit: 12), // keepsakes_cluster.dart
      // cinema_preview.dart: header + shelf share one query per user.
      tmdb.getWatchListStream(
        userName,
        limit: TMDBWatchlistService.previewLimit,
      ),
      // currently_watching_preview.dart
      tmdb.getCurrentlyWatchingStream(
        userName,
        limit: TMDBWatchlistService.previewLimit,
      ),
      // anime_preview.dart shelves (headers are the futures above).
      tmdb.getAnimeWatchListStream(
        userName,
        limit: TMDBWatchlistService.previewLimit,
      ),
      // books_preview.dart header badge.
      OurBooksService().getOurBooksCountPreviewStream(limit: 24),
    ];
    if (hasPartner) {
      streams.addAll([
        tmdb.getWatchListStream(
          partner,
          limit: TMDBWatchlistService.previewLimit,
        ),
        tmdb.getAnimeWatchListStream(
          partner,
          limit: TMDBWatchlistService.previewLimit,
        ),
        // books_preview.dart couple sub-rows.
        OurBooksService().getOurBooksByAdderPreviewStream(userName, limit: 24),
        OurBooksService().getOurBooksByAdderPreviewStream(partner, limit: 24),
        // manga_preview.dart header + sub-rows.
        MangaKakalotService().getCoupleLibraryPreviewStream(limit: 24),
        MangaKakalotService().getReadingPreviewStream(userName, limit: 24),
        MangaKakalotService().getReadingPreviewStream(partner, limit: 24),
      ]);
    } else {
      // Single-user fallbacks, mirroring the sections' else branches.
      streams.addAll([
        OpenLibraryService().getReadListStream(userName, limit: 24),
        MangaKakalotService().getLibraryStream(userName),
      ]);
    }
    return DashboardPreload.subscribe(streams);
  }

  /// Release every warmed stream. Called when Home goes away; the sections
  /// own their own subscriptions afterwards, so this never drops live UI.
  void dispose() {
    for (final sub in _subs) {
      try {
        unawaited(sub.cancel());
      } catch (e) {
        Logger.e('[Preload] dispose cancel failed', error: e);
      }
    }
  }
}
