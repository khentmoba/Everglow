import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../cinema/data/models/media_item.dart';

class AnimeXNavigation {
  const AnimeXNavigation._();

  @visibleForTesting
  static Future<bool> Function(Uri url)? urlLauncherForTesting;

  static Uri buildAnimeUri(MediaItem item, {int? episode}) {
    final params = <String, String>{};
    if (item.anilistId != null && item.anilistId! > 0) {
      params['id'] = item.anilistId.toString();
    }
    if (item.source == 'tmdb') {
      if (item.tmdbId > 0) {
        params['tmdbId'] = item.tmdbId.toString();
      }
      params['source'] = 'tmdb';
    } else {
      if (item.tmdbId > 0) {
        params['malId'] = item.tmdbId.toString();
      }
      if (item.source.isNotEmpty) {
        params['source'] = item.source;
      }
    }
    if (item.mediaType.isNotEmpty) {
      params['type'] = item.mediaType;
    }
    if (item.format.isNotEmpty) {
      params['format'] = item.format;
    }
    if (item.title.isNotEmpty) {
      params['title'] = item.title;
    }
    if (item.posterPath.isNotEmpty) {
      params['poster'] = item.posterPath;
    }
    final ep = episode ?? item.currentEpisode;
    if (ep != null && ep > 0) {
      params['ep'] = ep.toString();
    }

    if (kIsWeb) {
      final currentAgent = Uri.base.queryParameters['agent'];
      if (currentAgent != null && currentAgent.isNotEmpty) {
        params['agent'] = currentAgent;
      }
      return Uri.base.replace(
        path: '/anime',
        queryParameters: params,
        fragment: '',
      );
    }

    return Uri(
      path: '/anime',
      queryParameters: params,
    );
  }

  static Future<bool> openInNewTab(MediaItem item, {int? episode}) async {
    final uri = buildAnimeUri(item, episode: episode);
    final launcher = urlLauncherForTesting;
    if (launcher != null) {
      return launcher(uri);
    }
    return launchUrl(uri, webOnlyWindowName: '_blank');
  }

  static bool isMiddleClick(PointerDownEvent event) {
    return (event.buttons & kTertiaryButton) != 0;
  }

  static bool isNewTabModifierPressed() {
    return HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
  }
}
