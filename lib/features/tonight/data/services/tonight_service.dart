import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/tmdb_images.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import '../models/tonight_decision.dart';
import '../models/tonight_option.dart';

class TonightService {
  static final TonightService _instance = TonightService._internal();
  factory TonightService({FirebaseFirestore? db}) =>
      db == null ? _instance : TonightService._internal(db);

  TonightService._internal([this._customDb]);

  final FirebaseFirestore? _customDb;
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
      return Stream.value(AgentFixtures.demoDecision);
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

  /// Get the active decision once.
  Future<TonightDecision?> getActiveDecision() async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoDecision;
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

  /// Curated fallback movies when watchlist is empty or offline.
  static const List<Map<String, String>> fallbackMovies = [
    {
      'title': 'Spirited Away',
      'overview': 'A whimsical, magical journey by Studio Ghibli.',
      'posterPath': '/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg',
    },
    {
      'title': 'About Time',
      'overview': 'A heartwarming romance about family, time, and true love.',
      'posterPath': '/mBO5A8p1YgNf8mC8jZ1vX7m6c2C.jpg',
    },
    {
      'title': 'Your Name',
      'overview': 'Two souls connected across time, destiny, and the stars.',
      'posterPath': '/q719jXXEzOoYaps6q2PWi9qQI7W.jpg',
    },
    {
      'title': 'La La Land',
      'overview': 'A vibrant musical love letter to dreaming and romance.',
      'posterPath': '/uDO8zWDdoWNzAcSkzQI8zFG4fys.jpg',
    },
  ];

  /// Fetch a random movie from watchlist or fallback.
  Future<TonightOption> fetchMovieSuggestion() async {
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
        return mediaType == 'movie' && !status.contains('watched');
      }).toList();

      final movies = snap.docs.where((doc) {
        final mediaType = (doc.data()['mediaType'] as String? ?? 'movie')
            .toLowerCase();
        return mediaType == 'movie';
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
          targetRoute: '/cinema',
        );
      }
    } catch (e) {
      Logger.e('Error fetching movie suggestion for Tonight', error: e);
    }

    // Fallback movie
    final fallback = fallbackMovies[Random().nextInt(fallbackMovies.length)];
    return TonightOption(
      id: 'opt_movie_fallback_${DateTime.now().millisecondsSinceEpoch}',
      type: TonightOptionType.movie,
      title: fallback['title']!,
      subtitle: 'Cinema Classic',
      description: fallback['overview']!,
      imageUrl: '${TmdbImages.card}${fallback['posterPath']}',
      targetRoute: '/cinema',
    );
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

  /// Generate a fresh trio of suggestions: 1 Movie, 1 Date Idea, 1 Game.
  Future<List<TonightOption>> generateSuggestions() async {
    final movieFuture = fetchMovieSuggestion();
    final dateFuture = fetchDateIdeaSuggestion();
    final game = fetchGameSuggestion();

    final results = await Future.wait([movieFuture, dateFuture]);
    return [results[0], results[1], game];
  }

  /// Start a new session or re-roll suggestions.
  Future<TonightDecision> createOrShuffle({bool force = false}) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoDecision;
    }

    try {
      final existing = await getActiveDecision();
      if (!force &&
          existing != null &&
          existing.status != TonightStatus.planned) {
        return existing;
      }

      final options = await generateSuggestions();
      final now = DateTime.now();
      final decision = TonightDecision(
        id: activeDocId,
        status: TonightStatus.voting,
        options: options,
        votes: const {},
        createdAt: now,
        updatedAt: now,
      );

      await _collection.doc(activeDocId).set(decision.toMap());
      Logger.i('Created fresh Tonight decision session');
      return decision;
    } catch (e) {
      Logger.e('Error creating Tonight decision', error: e);
      final now = DateTime.now();
      return TonightDecision(
        id: activeDocId,
        status: TonightStatus.voting,
        options: [
          fallbackMovies
              .map(
                (m) => TonightOption(
                  id: 'opt_m',
                  type: TonightOptionType.movie,
                  title: m['title']!,
                  subtitle: 'Cinema',
                  description: m['overview']!,
                ),
              )
              .first,
          TonightOption(
            id: 'opt_d',
            type: TonightOptionType.date,
            title: fallbackDateIdeas.first,
            subtitle: 'Date Idea',
            description: 'Spend cozy time together.',
          ),
          availableGames.first,
        ],
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  /// Record a vote for a user.
  /// Automatically crowns the winner if both Khent and Clair pick the same!
  Future<void> castVote({
    required String username,
    required String optionId,
  }) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      Logger.i('Agent session simulated vote: $username -> $optionId');
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
      Logger.i('Agent session simulated decide winner: $optionId');
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
