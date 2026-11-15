part of 'katana_service.dart';

extension KatanaServiceSocial on KatanaService {
  CollectionReference<Map<String, dynamic>> get _bookmarks =>
      _firestore.collection('katana_bookmarks');

  Stream<List<KatanaBookmark>> bookmarkStream(
    String userName, {
    bool bookmarkedOnly = false,
  }) {
    if (userName.isEmpty) return Stream.value(const []);
    return _bookmarks
        .where('userName', isEqualTo: userName)
        .limit(500)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => KatanaBookmark.fromFirestore(d.data(), d.id))
                  .where((bookmark) => !bookmarkedOnly || bookmark.isBookmarked)
                  .toList()
                ..sort((a, b) => b.addedAt.compareTo(a.addedAt)),
        );
  }

  Future<KatanaBookmark?> fetchBookmark(String slug, String userName) async {
    if (userName.isEmpty || slug.isEmpty) return null;
    try {
      final doc = await withGetTimeout(
        _bookmarks.doc('$userName|$slug').get(),
        label: 'katana bookmark fetch',
      );
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return KatanaBookmark.fromFirestore(data, doc.id);
    } catch (e, st) {
      Logger.e(
        'KatanaService: failed to fetch bookmark for $slug',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> markChapterRead(
    String slug,
    String userName,
    String chapterId, {
    String title = '',
    String coverUrl = '',
  }) async {
    if (userName.isEmpty || slug.isEmpty || chapterId.isEmpty) return;
    try {
      final data = <String, dynamic>{
        'slug': slug,
        'userName': userName,
        'readChapterIds': FieldValue.arrayUnion([chapterId]),
      };
      if (title.isNotEmpty) data['title'] = title;
      if (coverUrl.isNotEmpty) data['coverUrl'] = coverUrl;
      await _bookmarks.doc('$userName|$slug').set(
        data,
        SetOptions(merge: true),
      );
    } catch (e, st) {
      Logger.e(
        'KatanaService: failed to mark $chapterId read for $slug',
        error: e,
        stackTrace: st,
      );
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
        await ref.set({
          'bookmarked': false,
          'userName': userName,
        }, SetOptions(merge: true));
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
      data.remove('readChapterIds');
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
      if (title.isNotEmpty) data['title'] = title;
      if (coverUrl.isNotEmpty) data['coverUrl'] = coverUrl;
      await _bookmarks
          .doc('$userName|$slug')
          .set(data, SetOptions(merge: true));
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
          final manga = await _fullMangaForReading(
            slug: slug,
            title: title,
            coverUrl: coverUrl,
          );
          await setReading(manga, userName, reading: true);
          await _library
              .doc('$userName|${KatanaService._katanaMangaId(slug)}')
              .set({
            'lastReadChapterId': chapterId,
            'lastReadChapterTitle': chapterTitle,
            'lastReadPage': page,
          }, SetOptions(merge: true));
        } else {
          for (final doc in existing.docs) {
            final metadata = doc.data();
            final tags = metadata['tags'];
            final author = metadata['author'] as String?;
            final artist = metadata['artist'] as String?;
            final needsDetail =
                (tags is! List || tags.isEmpty) ||
                ((author == null || author.trim().isEmpty) &&
                    (artist == null || artist.trim().isEmpty));
            if (needsDetail) {
              final manga = await _fullMangaForReading(
                slug: slug,
                title: title,
                coverUrl: coverUrl,
              );
              if (manga.title.isNotEmpty &&
                  (manga.authors.isNotEmpty || manga.genres.isNotEmpty)) {
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
      data['bookmarked'] = true;
      data['recommendationNote'] = note.trim();
      data['recommendedAt'] = Timestamp.now();
      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      Logger.e('recommendManga error', error: e);
    }
  }

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
