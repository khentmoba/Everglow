import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_details_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_discovery_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_cache_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_watchlist_service.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'agent catalogue and drawer metadata work without Firebase or HTTP',
    () async {
      AgentMode.isActive.value = true;
      AgentMode.useDemoData.value = true;
      addTearDown(() => AgentMode.isActive.value = false);
      var networkRequests = 0;
      final items = await http.runWithClient(
        () => TMDBDiscoveryService().fetchTrending(),
        () => MockClient((_) async {
          networkRequests++;
          throw StateError('Demo catalogue must stay offline');
        }),
      );
      expect(networkRequests, 0);
      expect(items, isNotEmpty);
      final item = items.first;
      final details = await TMDBDetailsService().fetchMediaDetails(
        item.tmdbId,
        item.mediaType,
      );
      expect(details?['id'], item.tmdbId);
      expect(details?['overview'], isNotEmpty);
      final watchlist = TMDBWatchlistService(TMDBCacheService());
      // A simulated couple session must not read or write real/cached lists.
      expect(await watchlist.getCoupleWatchListStream().first, isEmpty);
      expect(
        await watchlist.getSavedProgress(item.tmdbId, 'khentsgdz'),
        isNull,
      );
      await watchlist.saveToWatchList(item, 'watched-both', 'khentsgdz');
      await watchlist.removeFromWatchList(item.tmdbId, 'khentsgdz');
      expect(await TMDBCacheService().getCachedWatchList('khentsgdz'), isEmpty);
    },
  );
}
