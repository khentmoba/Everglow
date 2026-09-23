part of 'katana_service.dart';

/// Bookmarks, reading list, and couple recommendations for [KatanaService].
extension KatanaServiceSocial on KatanaService {
  // ── Bookmarks (Firestore, per Everglow user) ────────────────────

  CollectionReference<Map<String, dynamic>> get _bookmarks =>
      _firestore.collection('katana_bookmarks');

  Stream<List<KatanaBookmark>> bookmarkStream(String userName) {
    if (userName.isEmpty) return Stream.value(const []);
    return _bookmarks
        .where('userName', isEqualTo: userName)
        .limit(500)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => KatanaBookmark.fromFirestore(d.data(), d.id))
                  .toList()
                ..sort((a, b) => b.addedAt.compareTo(a.addedAt)),
        );
  }

  Future<bool> isBookmarked(String slug, String userName) async {
    if (userName.isEmpty || slug.isEmpty) return false;
    try {
      final doc = await withGetTimeout(
        _bookmarks.doc('$userName|$slug').get(),
        label: 'katana bookmark check',
      );
      return doc.exists;
    } catch (e) {
      Logger.e('isBookmarked error', error: e);
      return false;
    }
  }

  Future<void> setBookmark(
    KatanaManga manga,
    String userName, {
    bool bookmarked = true,
  }) async {
    if (userName.isEmpty || manga.slug.isEmpty) return;
    try {
      final ref = _bookmarks.doc('$userName|${manga.slug}');
      if (!bookmarked) {
        await ref.delete();
        return;
      }
      final data = KatanaBookmark(
        slug: manga.slug,
        title: manga.title,
        coverUrl: manga.coverUrl,
        status: manga.status,
        addedAt: DateTime.now(),
        latestChapterTitle: manga.latestChapter?.displayTitle ?? '',
      ).toFirestore();
      data['userName'] = userName;
      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      Logger.e('setBookmark error', error: e);
    }
  }

  Future<void> saveReadingProgress({
    required String slug,
    required String userName,
    required String chapterId,
    required String chapterTitle,
    required int page,
    String title = '',
    String coverUrl = '',
  }) async {
    if (userName.isEmpty || slug.isEmpty) return;
    try {
      final data = <String, dynamic>{
        'slug': slug,
        'userName': userName,
        'lastReadChapterId': chapterId,
        'lastReadChapterTitle': chapterTitle,
        'lastReadPage': page,
      };
      // Progress saves used to omit title/cover, leaving Continue Reading
      // cards with a blank title and placeholder cover. Only fill when we
      // have real values so we never blank out an existing bookmark.
      if (title.isNotEmpty) data['title'] = title;
      if (coverUrl.isNotEmpty) data['coverUrl'] = coverUrl;
      await _bookmarks
          .doc('$userName|$slug')
          .set(data, SetOptions(merge: true));
      // Auto-add: reading anything pins it to Currently Reading, so
      // Khent and Clair never have to remember the "Reading" button.
      // Guarded on title so we never create blank entries when the
      // reader was opened without metadata; the bookmark above still
      // saves, and the shelf folds progress-only titles in anyway.
      // Mirror progress onto the Currently Reading library entry so
      // the shelf shows "Ch. X • Page Y".
      try {
        final existing = await withGetTimeout(
          _library
              .where('mangaId', isEqualTo: KatanaService._katanaMangaId(slug))
              .where('userName', isEqualTo: userName)
              .limit(1)
              .get(),
          label: 'katana progress save lookup',
        );
        if (existing.docs.isEmpty && title.isNotEmpty) {
          // The reader only passes title + cover, which would save a bare
          // entry (wrong MANGA badge, no tags/authors). Pull the detail
          // page once so the new entry carries full metadata; falls back
          // to the bare entry when the fetch fails.
          final manga = await _fullMangaForReading(
            slug: slug,
            title: title,
            coverUrl: coverUrl,
          );
          await setReading(manga, userName, reading: true);
          // setReading creates a deterministic doc id, so no re-read:
          // stamp this chapter's progress straight onto it.
          await _library
              .doc('$userName|${KatanaService._katanaMangaId(slug)}')
              .set({
            'lastReadChapterId': chapterId,
            'lastReadChapterTitle': chapterTitle,
            'lastReadPage': page,
          }, SetOptions(merge: true));
        } else {
          for (final doc in existing.docs) {
            // One-time backfill for bare auto-adds saved before the detail
            // fetch above existed (empty tags): merge full metadata so the
            // badge and tags correct themselves on the next read.
            final tags = doc.data()['tags'];
            if (tags is List && tags.isEmpty) {
              final manga = await _fullMangaForReading(
                slug: slug,
                title: title,
                coverUrl: coverUrl,
              );
              // Never blank a good title when both the reader and the
              // detail fetch come up empty.
              if (manga.title.isNotEmpty) {
                await setReading(manga, userName, reading: true);
              }
            }
            await doc.reference.set({
              'lastReadChapterId': chapterId,
              'lastReadChapterTitle': chapterTitle,
              'lastReadPage': page,
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        Logger.e('saveReadingProgress library mirror error', error: e);
      }
    } catch (e) {
      Logger.e('saveReadingProgress error', error: e);
    }
  }

  /// Full metadata for a Currently Reading entry: the detail page when it
  /// loads (genres, authors, tags, description), else the bare reader
  /// metadata so the save still proceeds. `fetchMangaDetail` never throws
  /// (null on failure), so no try/catch is needed here.
  Future<KatanaManga> _fullMangaForReading({
    required String slug,
    required String title,
    required String coverUrl,
  }) async {
    final detail = await fetchMangaDetail(slug);
    if (detail != null) return detail;
    return KatanaManga(
      slug: slug,
      id: slug,
      title: title,
      coverUrl: coverUrl,
    );
  }

  // ── Couple reading & recommendations ──────────────────────────

  Future<KatanaBookmark?> getPartnerProgress(
    String slug,
    String currentUserName,
  ) async {
    if (currentUserName.isEmpty || slug.isEmpty) return null;
    final partner = currentUserName == 'khentsgdz'
        ? 'clairjassen'
        : (currentUserName == 'clairjassen' ? 'khentsgdz' : '');
    if (partner.isEmpty) return null;
    try {
      final doc = await withGetTimeout(
        _bookmarks.doc('$partner|$slug').get(),
        label: 'katana partner progress',
      );
      if (doc.exists && doc.data() != null) {
        final bookmark = KatanaBookmark.fromFirestore(doc.data()!, doc.id);
        if (bookmark.hasProgress) return bookmark;
      }
    } catch (e) {
      Logger.e('getPartnerProgress error', error: e);
    }
    return null;
  }

  Future<KatanaBookmark?> getRecommendationForMe(
    String slug,
    String currentUserName,
  ) async {
    if (currentUserName.isEmpty || slug.isEmpty) return null;
    try {
      final doc = await withGetTimeout(
        _bookmarks.doc('$currentUserName|$slug').get(),
        label: 'katana recommendation check',
      );
      if (doc.exists && doc.data() != null) {
        final bookmark = KatanaBookmark.fromFirestore(doc.data()!, doc.id);
        if (bookmark.isRecommended) return bookmark;
      }
    } catch (e, st) {
      Logger.e(
        'KatanaService: failed to read recommendation for $slug',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  Future<void> recommendManga({
    required KatanaManga manga,
    required String fromUser,
    required String note,
  }) async {
    if (fromUser.isEmpty || manga.slug.isEmpty) return;
    final partner = fromUser == 'khentsgdz'
        ? 'clairjassen'
        : (fromUser == 'clairjassen' ? 'khentsgdz' : '');
    if (partner.isEmpty) return;
    try {
      final ref = _bookmarks.doc('$partner|${manga.slug}');
      final existing = await withGetTimeout(
        ref.get(),
        label: 'katana recommend lookup',
      );
      final data = existing.exists
          ? Map<String, dynamic>.from(existing.data()!)
          : KatanaBookmark(
              slug: manga.slug,
              title: manga.title,
              coverUrl: manga.coverUrl,
              status: manga.status,
              addedAt: DateTime.now(),
            ).toFirestore();

      data['slug'] = manga.slug;
      data['title'] = manga.title;
      data['coverUrl'] = manga.coverUrl;
      data['userName'] = partner;
      data['recommendedBy'] = fromUser;
      data['recommendationNote'] = note.trim();
      data['recommendedAt'] = Timestamp.now();
      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      Logger.e('recommendManga error', error: e);
    }
  }

  // ── Reading list (manga_library, shared with the dashboard's "Reading" shelf) ──
  //
  // The dashboard's "Reading" section streams `manga_library` entries whose
  // `libraryStatus == 'reading'`, split into "ME" / partner sub-rows. Katana
  // titles are keyed with a `katana|` prefix so they never collide with the
  // Comick-sourced manga ids used by the rest of the library.

  CollectionReference<Map<String, dynamic>> get _library =>
      _firestore.collection('manga_library');

  Future<bool> isReading(String slug, String userName) async {
    if (userName.isEmpty || slug.isEmpty) return false;
    try {
      final docs = await withGetTimeout(
        _library
            .where('mangaId', isEqualTo: KatanaService._katanaMangaId(slug))
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'katana reading check',
      );
      return docs.docs.isNotEmpty;
    } catch (e) {
      Logger.e('isReading error', error: e);
      return false;
    }
  }

  Future<void> setReading(
    KatanaManga manga,
    String userName, {
    bool reading = true,
  }) async {
    if (userName.isEmpty || manga.slug.isEmpty) return;
    try {
      final mangaId = KatanaService._katanaMangaId(manga.slug);
      final existing = await withGetTimeout(
        _library
            .where('mangaId', isEqualTo: mangaId)
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'katana set reading lookup',
      );
      if (!reading) {
        for (final doc in existing.docs) {
          await doc.reference.delete();
        }
        return;
      }
      final data = <String, dynamic>{
        'mangaId': mangaId,
        'title': manga.title,
        'author': manga.authors.isNotEmpty ? manga.authors.first : '',
        'artist': manga.artists.isNotEmpty ? manga.artists.first : '',
        'description': manga.summary,
        'coverUrl': proxiedImageUrl(manga.coverUrl),
        'status': manga.status,
        'originalLanguage': katanaLanguageForGenres(manga.genres),
        'contentRating': 'safe',
        'tags': [for (final genre in manga.genres) genre.name],
        'userName': userName,
        'addedAt': Timestamp.now(),
        'libraryStatus': 'reading',
        'lastReadChapterId': '',
        'lastReadPage': 0,
        'comickId': 0,
        'comickSlug': '',
        'mangaKakalotId': manga.slug,
        'rating': 0.0,
        'followCount': 0,
        'altTitles': manga.altNames,
      };
      if (existing.docs.isNotEmpty) {
        // Preserve the original add order and any saved chapter
        // progress — re-marking a series as Reading must not wipe
        // where Clair left off.
        data.remove('addedAt');
        data.remove('lastReadChapterId');
        data.remove('lastReadPage');
        await existing.docs.first.reference.set(data, SetOptions(merge: true));
      } else {
        await _library.doc('$userName|$mangaId').set(data);
      }
    } catch (e) {
      Logger.e('setReading error', error: e);
    }
  }
}
