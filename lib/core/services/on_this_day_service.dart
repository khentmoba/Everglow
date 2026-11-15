import 'dart:async';
import '../../features/gallery/data/services/gallery_service.dart';
import '../../features/cinema/data/services/tmdb/tmdb_watchlist_service.dart';

import '../../features/chat/data/services/chat_service.dart';
import '../utils/logger.dart';

class OnThisDayMemory {
  final OnThisDaySource source;
  final DateTime date;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? posterUrl;
  final dynamic original;

  const OnThisDayMemory({
    required this.source,
    required this.date,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.posterUrl,
    this.original,
  });

  int get yearsAgo => DateTime.now().year - date.year;
}

enum OnThisDaySource { gallery, cinema, chat }

class OnThisDayService {
  final GalleryService _galleryService;
  final TMDBWatchlistService _cinemaService;
  final ChatService _chatService;

  OnThisDayService()
    : _galleryService = GalleryService(),
      _cinemaService = TMDBWatchlistService(),
      _chatService = ChatService();

  Future<List<OnThisDayMemory>> getAllMemories() async {
    try {
      final results = await Future.wait([
        _getGalleryMemories(),
        _getCinemaMemories(),
        _getChatMemories(),
      ]);
      final all = results.expand((list) => list).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return all;
    } catch (e) {
      Logger.e("Error fetching on-this-day memories", error: e);
      return [];
    }
  }

  Future<List<OnThisDayMemory>> getThisWeekMemories() async {
    try {
      final photos = await _galleryService.getPhotosFromThisWeek();
      final cinemaWeek = await _getGalleryMemoriesForWeek();
      final all = <OnThisDayMemory>[
        ...photos.map(
          (p) => OnThisDayMemory(
            source: OnThisDaySource.gallery,
            date: p.uploadedAt,
            title: p.caption.isNotEmpty ? p.caption : 'A photo memory',
            subtitle: p.locationName != null
                ? '📍 ${p.locationName}'
                : 'Gallery • This week',
            imageUrl: GalleryService.displayUrl(p.imageUrl, thumb: true),
            original: p,
          ),
        ),
        ...cinemaWeek,
      ]..sort((a, b) => b.date.compareTo(a.date));
      return all;
    } catch (e) {
      Logger.e("Error fetching this-week memories", error: e);
      return [];
    }
  }

  Future<List<OnThisDayMemory>> _getGalleryMemoriesForWeek() async {
    return [];
  }

  Future<List<OnThisDayMemory>> _getGalleryMemories() async {
    final photos = await _galleryService.getPhotosFromThisDay();
    return photos
        .map(
          (p) => OnThisDayMemory(
            source: OnThisDaySource.gallery,
            date: p.uploadedAt,
            title: p.caption.isNotEmpty ? p.caption : 'A photo memory',
            subtitle: 'Gallery photo',
            imageUrl: GalleryService.displayUrl(p.imageUrl, thumb: true),
            original: p,
          ),
        )
        .toList();
  }

  Future<List<OnThisDayMemory>> _getCinemaMemories() async {
    final items = await _cinemaService.getWatchListFromThisDay();
    return items.map((item) {
      final label = item.isWatched ? 'watched together' : 'added to your list';
      return OnThisDayMemory(
        source: OnThisDaySource.cinema,
        date: item.addedAt,
        title: item.title,
        subtitle: 'You $label',
        posterUrl: item.posterUrl,
        original: item,
      );
    }).toList();
  }

  Future<List<OnThisDayMemory>> _getChatMemories() async {
    final messages = await _chatService.getMessagesFromThisDay();
    final picked = messages.take(3).toList();
    return picked
        .map(
          (msg) => OnThisDayMemory(
            source: OnThisDaySource.chat,
            date: msg.timestamp,
            title: msg.text.length > 80
                ? '${msg.text.substring(0, 80)}...'
                : msg.text,
            subtitle: '${msg.sender} said',
            original: msg,
          ),
        )
        .toList();
  }
}
