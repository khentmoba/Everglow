import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/tmdb_images.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import '../models/tonight_decision.dart';
import '../models/tonight_option.dart';
import '../models/tonight_preferences.dart';

class TonightService {
  static final TonightService _instance = TonightService._internal();
  factory TonightService({FirebaseFirestore? db}) =>
      db == null ? _instance : TonightService._internal(db);

  TonightService._internal([this._customDb]);

  final FirebaseFirestore? _customDb;
  TonightDecision? _demoDecision;
  final _demoChanges = StreamController<TonightDecision>.broadcast();
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('tonight_decisions');

  static String get activeDocId {
    final now = DateTime.now();
    return 'day_${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Realtime stream of the active tonight decision session.
  /// Bounded to one doc for today's shared decision.
  Stream<TonightDecision?> watchActiveDecision() {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return _watchDemo();
    }

    Stream<TonightDecision?> subscribe() {
      return _collection.doc(activeDocId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return TonightDecision.fromFirestore(doc);
      });
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'tonight-active',
      duration: const Duration(seconds: 10),
    );
  }

  Stream<TonightDecision> _watchDemo() async* {
    yield _demoDecision ?? AgentFixtures.demoDecision;
    yield* _demoChanges.stream;
  }

  void _setDemo(TonightDecision decision) {
    _demoDecision = decision;
    _demoChanges.add(decision);
  }

  /// Get the active decision once.
  Future<TonightDecision?> getActiveDecision() async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return _demoDecision ?? AgentFixtures.demoDecision;
    }

    try {
      final doc = await withGetTimeout(
        _collection.doc(activeDocId).get(),
        label: 'tonight get active',
      );
      if (!doc.exists || doc.data() == null) return null;
      return TonightDecision.fromFirestore(doc);
    } catch (e) {
      Logger.e('Error getting active tonight decision', error: e);
      return null;
    }
  }

  /// Curated fallback games from Play Zone.
  static const List<TonightOption> availableGames = [
    TonightOption(
      id: 'game_scribble',
      type: TonightOptionType.game,
      title: 'Scribble Together',
      subtitle: 'Play Zone Arcade',
      description:
          'One draws, one guesses! Real-time canvas with secret words.',
      targetRoute: '/play-zone/scribble',
    ),
    TonightOption(
      id: 'game_table_tennis',
      type: TonightOptionType.game,
      title: 'Table Tennis Showdown',
      subtitle: 'Play Zone Arcade',
      description: 'Fast 1v1 rally battle or solo tournament bracket.',
      targetRoute: '/play-zone/tt',
    ),
    TonightOption(
      id: 'game_chess',
      type: TonightOptionType.game,
      title: 'Couple Chess',
      subtitle: 'Play Zone Classic',
      description: 'Cozy chess board for two with quiet, loving turns.',
      targetRoute: '/play-zone/chess',
    ),
  ];

  /// Curated fallback date ideas when Firestore date_ideas is empty or offline.
  static const List<String> fallbackDateIdeas = [
    'Cook homemade pasta together by candlelight',
    'Blanket fort movie marathon with warm popcorn',
    'Late night dessert run and sweet car talk',
    'Stargazing on the roof with our favorite songs',
    'Bake cookies together from scratch',
    'Cozy tea talk sharing our top 5 favorite memories',
  ];

  /// Prefer an unwatched film with a usable playback link.
  Future<TonightOption> fetchMovieSuggestion({int? maxMinutes}) async {
    try {
      final snap = await withGetTimeout(
        _db
            .collection('watch_list')
            .where('userName', whereIn: ['khentsgdz', 'clairjassen'])
            .limit(25)
            .get(),
        label: 'tonight movie fetch',
      );

      final candidates = snap.docs.where((d) {
        final data = d.data();
        final status = (data['status'] as String? ?? '').toLowerCase();
        // Pick a feature film, not a TV/anime series. Filter watched titles
        // when the queue contains other choices, but allow a rewatch fallback.
        final mediaType = (data['mediaType'] as String? ?? 'movie')
            .toLowerCase();
        final duration = data['durationSeconds'];
        final fits =
            maxMinutes == null ||
            (duration is num && duration > 0 && duration <= maxMinutes * 60);
        return mediaType == 'movie' &&
            (data['source'] ?? 'tmdb') == 'tmdb' &&
            movieRoute(data) != '/cinema' &&
            !status.contains('watched') &&
            fits;
      }).toList();

      final movies = snap.docs.where((doc) {
        final mediaType = (doc.data()['mediaType'] as String? ?? 'movie')
            .toLowerCase();
        final duration = doc.data()['durationSeconds'];
        return mediaType == 'movie' &&
            (doc.data()['source'] ?? 'tmdb') == 'tmdb' &&
            movieRoute(doc.data()) != '/cinema' &&
            (maxMinutes == null ||
                (duration is num &&
                    duration > 0 &&
                    duration <= maxMinutes * 60));
      }).toList();
      final list = candidates.isNotEmpty ? candidates : movies;
      if (list.isNotEmpty) {
        final randomDoc = list[Random().nextInt(list.length)];
        final data = randomDoc.data();
        final title = data['title'] as String? ?? 'Watchlist Movie';
        final posterPath = data['posterPath'] as String?;
        final overview =
            data['overview'] as String? ??
            data['synopsis'] as String? ??
            'From your saved Cinema watchlist.';
        final imageUrl = TmdbImages.isUsablePath(posterPath)
            ? '${TmdbImages.card}$posterPath'
            : null;

        return TonightOption(
          id: 'opt_movie_${randomDoc.id}',
          type: TonightOptionType.movie,
          title: title,
          subtitle: 'From Cinema Watchlist',
          description: overview,
          imageUrl: imageUrl,
          targetRoute: movieRoute(data),
        );
      }
    } catch (e) {
      Logger.e('Error fetching movie suggestion for Tonight', error: e);
    }

    return quietOptions.first;
  }

  /// Fetch a random date idea from date_ideas collection or fallback.
  Future<TonightOption> fetchDateIdeaSuggestion() async {
    try {
      final snap = await withGetTimeout(
        _db.collection('date_ideas').limit(40).get(),
        label: 'tonight date idea fetch',
      );

      if (snap.docs.isNotEmpty) {
        final randomDoc = snap.docs[Random().nextInt(snap.docs.length)];
        final data = randomDoc.data();
        final title = data['title'] as String? ?? 'Cozy Date Night';
        return TonightOption(
          id: 'opt_date_${randomDoc.id}',
          type: TonightOptionType.date,
          title: title,
          subtitle: 'Saved Date Idea',
          description:
              'A romantic, special idea to experience together tonight.',
          targetRoute: '/calendar',
        );
      }
    } catch (e) {
      Logger.e('Error fetching date idea for Tonight', error: e);
    }

    final fallback =
        fallbackDateIdeas[Random().nextInt(fallbackDateIdeas.length)];
    return TonightOption(
      id: 'opt_date_fallback_${DateTime.now().millisecondsSinceEpoch}',
      type: TonightOptionType.date,
      title: fallback,
      subtitle: 'Everglow Date Idea',
      description: 'A cozy, loving plan made for just the two of you.',
      targetRoute: '/calendar',
    );
  }

  /// Pick a game suggestion from Play Zone games.
  TonightOption fetchGameSuggestion() {
    return availableGames[Random().nextInt(availableGames.length)];
  }

  static String movieRoute(Map<String, dynamic> data) {
    final rawId = data['tmdbId'];
    final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
    if (id == null || id <= 0) return '/cinema';
    return Uri(
      path: '/cinema/video/$id',
      queryParameters: {
        'type': 'movie',
        'title': data['title'] as String? ?? '',
      },
    ).toString();
  }

  static const quietOptions = [
    TonightOption(
      id: 'quiet_chat',
      type: TonightOptionType.date,
      title: 'Tea and a little catch-up',
      subtitle: '20 minutes / Stay in',
      description: 'Make something warm and share the best part of your day.',
      targetRoute: '/sanctuary',
    ),
    TonightOption(
      id: 'quiet_draw',
      type: TonightOptionType.game,
      title: 'Draw a tiny memory together',
      subtitle: '20 minutes / Stay in',
      description: 'Take turns adding something to your shared canvas.',
      targetRoute: '/canvas',
    ),
    TonightOption(
      id: 'quiet_music',
      type: TonightOptionType.date,
      title: 'Trade three favorite songs',
      subtitle: '20 minutes / Stay in',
      description: 'Play a few songs and tell each other why you chose them.',
      targetRoute: '/jukebox',
    ),
  ];

  static List<TonightOption> localSuggestions(TonightPreferences preferences) {
    if (preferences.goingOut) {
      final adventurous = preferences.energy == EveningEnergy.adventurous;
      return [
        TonightOption(
          id: 'out_walk',
          type: TonightOptionType.date,
          title: adventurous
              ? 'Take a new route together'
              : 'A gentle evening walk',
          subtitle: '20 minutes / Go out',
          description:
              'Choose somewhere nearby and enjoy a little time outside.',
          targetRoute: '/calendar',
        ),
        const TonightOption(
          id: 'out_treat',
          type: TonightOptionType.date,
          title: 'Share a nearby treat',
          subtitle: '30 minutes / Go out',
          description: 'Pick a nearby spot for a snack or a drink.',
          targetRoute: '/calendar',
        ),
        TonightOption(
          id: 'out_photo',
          type: TonightOptionType.date,
          title: adventurous
              ? 'A little photo scavenger hunt'
              : 'Find a quiet spot to sit',
          subtitle: '20 minutes / Go out',
          description: 'Keep it nearby, with no big plan needed.',
          targetRoute: '/calendar',
        ),
      ];
    }
    if (preferences.energy == EveningEnergy.quiet) return quietOptions;
    return [availableGames[0], availableGames[1], availableGames[2]];
  }

  Future<List<TonightOption>> generateSuggestions({
    TonightPreferences preferences = const TonightPreferences(),
  }) async {
    final local = localSuggestions(preferences);
    if (preferences.goingOut ||
        (preferences.minutes != null && preferences.minutes! < 90)) {
      return local;
    }
    final movie = await fetchMovieSuggestion(maxMinutes: preferences.minutes);
    if (preferences.minutes == null &&
        preferences.energy != EveningEnergy.quiet) {
      return [movie, await fetchDateIdeaSuggestion(), local[2]];
    }
    return [movie, ...local.where((option) => option.id != movie.id).take(2)];
  }

  /// Start a new session or re-roll suggestions.
  Future<TonightDecision> createOrShuffle({
    bool force = false,
    TonightPreferences preferences = const TonightPreferences(),
  }) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      final now = DateTime.now();
      final decision = TonightDecision(
        id: activeDocId,
        options: localSuggestions(preferences),
        preferences: preferences,
        createdAt: now,
        updatedAt: now,
      );
      _setDemo(decision);
      return decision;
    }

    try {
      final existing = await getActiveDecision();
      if (!force &&
          existing != null &&
          existing.status != TonightStatus.planned) {
        return existing;
      }

      final options = await generateSuggestions(preferences: preferences);
      final now = DateTime.now();
      final decision = TonightDecision(
        id: activeDocId,
        status: TonightStatus.voting,
        options: options,
        preferences: preferences,
        votes: const {},
        createdAt: now,
        updatedAt: now,
      );

      await _collection.doc(activeDocId).set(decision.toMap());
      Logger.i('Created fresh Tonight decision session');
      return decision;
    } catch (e) {
      Logger.e('Error creating Tonight decision', error: e);
      rethrow;
    }
  }

  /// Record a vote for a user.
  /// Automatically crowns the winner if both Khent and Clair pick the same!
  Future<void> castVote({
    required String username,
    required String optionId,
  }) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      final current = _demoDecision ?? AgentFixtures.demoDecision;
      final votes = {...current.votes, username: optionId};
      final match =
          votes['khentsgdz'] != null &&
          votes['khentsgdz'] == votes['clairjassen'];
      _setDemo(
        TonightDecision.fromMap({
          ...current.toMap(),
          'votes': votes,
          if (match) 'status': 'decided',
          if (match) 'winnerOptionId': optionId,
        }, current.id),
      );
      return;
    }

    try {
      final docRef = _collection.doc(activeDocId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists || snap.data() == null) return;

        final current = TonightDecision.fromFirestore(snap);
        if (current.status != TonightStatus.voting ||
            !current.options.any((option) => option.id == optionId) ||
            !{'khentsgdz', 'clairjassen'}.contains(username)) {
          return;
        }
        final updatedVotes = Map<String, String>.from(current.votes);
        updatedVotes[username] = optionId;

        final khentVote = updatedVotes['khentsgdz'];
        final clairVote = updatedVotes['clairjassen'];

        String? winnerId = current.winnerOptionId;
        TonightStatus status = current.status;

        // If both voted for the same option -> Instant Match!
        if (khentVote != null && clairVote != null && khentVote == clairVote) {
          winnerId = khentVote;
          status = TonightStatus.decided;
        }

        final updateData = <String, dynamic>{
          'votes': updatedVotes,
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (winnerId != null) {
          updateData['winnerOptionId'] = winnerId;
        }

        tx.update(docRef, updateData);
      });
      Logger.i('Cast vote on Tonight: $username -> $optionId');
    } catch (e) {
      Logger.e('Error casting vote for Tonight', error: e);
    }
  }

  /// Explicitly decide the winner (e.g. "We pick this together" or tie-breaker).
  Future<void> decideWinner({required String optionId}) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      final current = _demoDecision ?? AgentFixtures.demoDecision;
      _setDemo(
        TonightDecision.fromMap({
          ...current.toMap(),
          'status': 'decided',
          'winnerOptionId': optionId,
        }, current.id),
      );
      return;
    }

    try {
      final docRef = _collection.doc(activeDocId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists || snap.data() == null) return;
        final current = TonightDecision.fromFirestore(snap);
        if (current.status != TonightStatus.voting ||
            !current.options.any((option) => option.id == optionId)) {
          return;
        }
        tx.update(docRef, {
          'winnerOptionId': optionId,
          'status': TonightStatus.decided.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      Logger.i('Decided Tonight winner: $optionId');
    } catch (e) {
      Logger.e('Error deciding Tonight winner', error: e);
    }
  }

  /// Make the winning activity a planned CalendarEvent.
  Future<CalendarEvent?> makePlan({
    required TonightOption option,
    required DateTime planTime,
    required String createdBy,
  }) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated makePlan');
      return CalendarEvent(
        id: 'agent_event',
        title: 'Plan: ${option.title}',
        description: 'Decided together in Agent Mode session.',
        date: planTime,
        type: CalendarEventType.dateNight,
        createdBy: createdBy,
        attendees: const ['khentsgdz', 'clairjassen'],
      );
    }

    try {
      final title = switch (option.type) {
        TonightOptionType.movie => '🎬 Movie Night: ${option.title}',
        TonightOptionType.date => '🌹 Date: ${option.title}',
        TonightOptionType.game => '🎮 Game: ${option.title}',
      };

      final eventRef = _db.collection('calendar_events').doc();
      final event = CalendarEvent(
        id: eventRef.id,
        title: title,
        description:
            'Decided together on Tonight ✨\n${option.description.isNotEmpty ? option.description : option.subtitle}',
        date: planTime,
        type: CalendarEventType.dateNight,
        createdBy: createdBy,
        attendees: const ['khentsgdz', 'clairjassen'],
      );
      final decisionRef = _collection.doc(activeDocId);

      // Commit the event and decision together so a failed calendar write
      // cannot leave Tonight claiming a plan exists when it doesn't.
      await _db.runTransaction((tx) async {
        final snap = await tx.get(decisionRef);
        if (!snap.exists || snap.data() == null) {
          throw StateError('Tonight decision no longer exists');
        }
        final current = TonightDecision.fromFirestore(snap);
        if (current.status != TonightStatus.decided ||
            current.winnerOptionId != option.id) {
          throw StateError('Tonight winner changed before the plan was saved');
        }
        tx.set(eventRef, event.toFirestore());
        tx.update(decisionRef, {
          'status': TonightStatus.planned.name,
          'calendarEventId': eventRef.id,
          'planTime': Timestamp.fromDate(planTime),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      Logger.i('Made Tonight winner a plan in Calendar: $title at $planTime');
      return event;
    } catch (e) {
      Logger.e('Error turning Tonight winner into a plan', error: e);
      return null;
    }
  }

  /// Clear or reset the active decision so a new one can be started.
  Future<void> resetSession() async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return;
    }

    try {
      await _collection.doc(activeDocId).delete();
      Logger.i('Reset Tonight session');
    } catch (e) {
      Logger.e('Error resetting Tonight session', error: e);
    }
  }
}
