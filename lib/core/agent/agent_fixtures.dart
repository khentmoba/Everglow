import '../../features/bucket_list/data/models/bucket_item.dart';
import '../../features/calendar/domain/models/calendar_event.dart';
import '../../features/chat/domain/models/chat_message.dart';
import '../../features/daily_bloom/data/models/garden_stats.dart';
import '../../features/dashboard/domain/models/hidden_note.dart';
import '../../features/dashboard/domain/models/milestone.dart';
import '../../features/date_randomizer/data/models/date_idea.dart';
import '../../features/gallery/domain/models/memory_photo.dart';
import '../../features/guardian/data/models/guardian_message.dart';
import '../../features/heartbeat/data/models/user_mood.dart';
import '../../features/journal/data/models/journal_entry.dart';
import '../../features/starlight_jar/domain/models/star_note.dart';
import '../../features/tonight/data/models/tonight_decision.dart';
import '../../features/tonight/data/models/tonight_option.dart';

/// Pre-populated, privacy-safe demo fixtures for Everglow couple surfaces.
///
/// Ensures agents and developers can render, verify, and take PR proof
/// screenshots of couple-only screens (Dashboard, Milestones, Notes, Garden,
/// Chat, Journal, Starlight Jar) without requiring Firebase credentials or
/// leaking private couple memories.
class AgentFixtures {
  AgentFixtures._();

  static final List<Milestone> demoMilestones = [
    Milestone(
      id: 'demo_milestone_1',
      title: 'Our First Date',
      description:
          'Met at 7/11, grabbed coffee, took cute photos with the flowers, and spent hours talking about our favorite music and memories.',
      date: DateTime(2026, 2, 14),
      author: 'Khent',
      category: MilestoneCategory.firstDate,
      imageUrls: const [
        'assets/images/milestones/valentines_khent_1.jpg',
        'assets/images/milestones/valentines_khent_2.jpg',
        'assets/images/milestones/valentines_khent_3.jpg',
      ],
    ),
    Milestone(
      id: 'demo_milestone_2',
      title: 'Our First Kiss',
      description:
          'Riding together on the motorcycle, stopping by when the rain started, and sharing an unforgettable sweet moment under the moonlight.',
      date: DateTime(2026, 2, 17),
      author: 'Khent',
      category: MilestoneCategory.memory,
      imageUrls: const [
        'assets/images/milestones/kiss_khent_1.jpg',
        'assets/images/milestones/kiss_khent_2.jpg',
        'assets/images/milestones/kiss_khent_3.jpg',
      ],
    ),
    Milestone(
      id: 'demo_milestone_3',
      title: 'Puting Bato Roadtrip',
      description:
          'Scenic winding road view, warm afternoon breeze, delicious food at Zackies, and cherished moments overlooking the hills.',
      date: DateTime(2026, 3, 14),
      author: 'Khent',
      category: MilestoneCategory.trip,
      imageUrls: const [
        'assets/images/milestones/puting_bato_khent_1.jpg',
        'assets/images/milestones/puting_bato_khent_2.jpg',
        'assets/images/milestones/puting_bato_khent_3.jpg',
      ],
    ),
    Milestone(
      id: 'demo_milestone_4',
      title: 'A Day Before Your Birthday',
      description:
          'Thrifting adventures in Butuan, cozy bus ride naps, delicious snacks, and laughter all the way home.',
      date: DateTime(2026, 2, 20),
      author: 'Khent',
      category: MilestoneCategory.anniversary,
      imageUrls: const [
        'assets/images/milestones/birthday_pre_khent_1.jpg',
        'assets/images/milestones/birthday_pre_khent_2.jpg',
      ],
    ),
  ];

  static final List<HiddenNote> demoNotes = [
    HiddenNote(
      id: 'demo_note_1',
      title: 'Always Thinking of You 💖',
      content:
          'Just a little reminder of how proud I am of you every single day. Keep shining my love!',
      unlockDate: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
    ),
    HiddenNote(
      id: 'demo_note_2',
      title: 'Movie Night Tonight 🎬',
      content:
          'I picked out the best snacks for our Studio Ghibli marathon. Can’t wait to cuddle and watch together!',
      unlockDate: DateTime.now().subtract(const Duration(hours: 4)),
      isRead: false,
    ),
    HiddenNote(
      id: 'demo_note_3',
      title: 'A Secret Promise 🌸',
      content:
          'No matter how busy life gets, I will always choose you, cherish you, and walk hand-in-hand with you.',
      unlockDate: DateTime.now().subtract(const Duration(days: 10)),
      isRead: true,
    ),
  ];

  static final UserMood demoMood = UserMood(
    username: 'clairjassen',
    moodScore: 5,
    moodEmoji: '💖',
    timestamp: DateTime.now(),
  );

  static final GardenStats demoGardenStats = GardenStats(
    currentStage: 3,
    lastVisit: DateTime.now(),
    streakCount: 42,
    totalInteractions: 128,
    plantType: 'lily',
  );

  static final List<StarNote> demoStars = [
    StarNote(
      id: 'demo_star_1',
      content: 'Grateful for your warm smile that lights up my whole world.',
      author: 'Khent',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      category: 'gratitude',
      tags: const ['smile', 'love'],
    ),
    StarNote(
      id: 'demo_star_2',
      content: 'Remembering when we hid in front of CSU and you surprised me.',
      author: 'Clair',
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
      category: 'memory',
      tags: const ['cute', 'date'],
    ),
    StarNote(
      id: 'demo_star_3',
      content: 'Dreaming of our road trip across Japan together one day!',
      author: 'Khent',
      timestamp: DateTime.now().subtract(const Duration(days: 12)),
      category: 'dream',
      tags: const ['travel', 'japan'],
    ),
  ];

  static final List<BucketItem> demoBucketList = [
    BucketItem(
      id: 'demo_bucket_1',
      title: 'Trip to Tokyo & Kyoto 🇯🇵',
      description: 'Visit Studio Ghibli Museum, see cherry blossoms, and explore Kyoto temples.',
      category: BucketCategory.travel,
      status: BucketStatus.planned,
      createdBy: 'khentsgdz',
      createdAt: DateTime(2026, 2, 15),
      priority: BucketPriority.high,
    ),
    BucketItem(
      id: 'demo_bucket_2',
      title: 'Stargazing Campfire at Puting Bato 🌌',
      description: 'Bring hot cocoa, warm blankets, and watch shooting stars all night.',
      category: BucketCategory.adventure,
      status: BucketStatus.wish,
      createdBy: 'clairjassen',
      createdAt: DateTime(2026, 2, 20),
      priority: BucketPriority.medium,
    ),
    BucketItem(
      id: 'demo_bucket_3',
      title: 'Bake Strawberry Matcha Cake Together 🍰',
      description: 'Follow our special recipe and decorate it with heart strawberries.',
      category: BucketCategory.food,
      status: BucketStatus.completed,
      createdBy: 'clairjassen',
      createdAt: DateTime(2026, 3, 1),
      completedAt: DateTime(2026, 3, 10),
      completedBy: 'clairjassen',
      priority: BucketPriority.low,
    ),
  ];

  static final List<CalendarEvent> demoEvents = [
    CalendarEvent(
      id: 'demo_event_1',
      title: 'Our Monthly Anniversary 💕',
      description: 'Celebrating another month of endless love and happiness.',
      date: DateTime.now().add(const Duration(days: 3)),
      type: CalendarEventType.anniversary,
      createdBy: 'khentsgdz',
      recurring: 'monthly',
    ),
    CalendarEvent(
      id: 'demo_event_2',
      title: 'Cinema & Ramen Date Night 🍜',
      description: 'Watch the new anime movie and eat hot tonkotsu ramen.',
      date: DateTime.now().add(const Duration(days: 6)),
      type: CalendarEventType.dateNight,
      createdBy: 'clairjassen',
    ),
    CalendarEvent(
      id: 'demo_event_3',
      title: 'Weekend Garden Bloom Watering 🌸',
      description: 'Tend to our shared Everglow digital garden together.',
      date: DateTime.now().add(const Duration(days: 1)),
      type: CalendarEventType.reminder,
      createdBy: 'khentsgdz',
    ),
  ];

  static final TonightDecision demoDecision = TonightDecision(
    id: 'demo_tonight_1',
    status: TonightStatus.voting,
    options: const [
      TonightOption(
        id: 'opt_1',
        type: TonightOptionType.movie,
        title: 'Spirited Away',
        subtitle: 'Studio Ghibli Classic',
        description: 'Immerse into Chihiro’s magical journey.',
      ),
      TonightOption(
        id: 'opt_2',
        type: TonightOptionType.date,
        title: 'Late Night Coffee & Dessert',
        subtitle: 'Zackies / 7-11',
        description: 'Warm latte and cozy sweet talks.',
      ),
      TonightOption(
        id: 'opt_3',
        type: TonightOptionType.game,
        title: 'Everglow Play Zone Showdown',
        subtitle: 'Arcade Mini-games',
        description: 'Challenge each other to high-score games.',
      ),
    ],
    votes: const {'khentsgdz': 'opt_1', 'clairjassen': 'opt_1'},
    winnerOptionId: 'opt_1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  static final List<JournalEntry> demoJournalEntries = [
    JournalEntry(
      id: 'demo_journal_1',
      title: 'The Magic of Ordinary Days ☕',
      content:
          'Sometimes the sweetest memories are the simplest ones — having coffee by the corner, laughing at random reels, and knowing you’re right there beside me.',
      author: 'khentsgdz',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      category: JournalCategory.gratitude,
      mood: JournalMood.loved,
      tags: const ['love', 'peace', 'us'],
      isPinned: true,
      wordCount: 32,
    ),
    JournalEntry(
      id: 'demo_journal_2',
      title: 'Looking Forward to our Next Adventure ✨',
      content:
          'Counting down the days to our next roadtrip. Every milestone with you feels like a page out of a fairy tale.',
      author: 'clairjassen',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 7)),
      category: JournalCategory.daily,
      mood: JournalMood.excited,
      tags: const ['adventure', 'future'],
      isPinned: false,
      wordCount: 26,
    ),
  ];

  static final List<ChatMessage> demoChatMessages = [
    ChatMessage(
      id: 'msg_1',
      sender: 'Clair',
      senderUid: 'clair_demo_uid',
      text: 'Good morning love! Hope you slept well 🥰',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    ChatMessage(
      id: 'msg_2',
      sender: 'Khent',
      senderUid: 'khent_demo_uid',
      text: 'Good morning gorgeous! Ready for our movie night later? 🎬💖',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
    ),
    ChatMessage(
      id: 'msg_3',
      sender: 'Clair',
      senderUid: 'clair_demo_uid',
      text: 'Yessss! Already craving popcorn! See you soonest 💕',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
    ),
  ];

  static final List<MemoryPhoto> demoPhotos = [
    MemoryPhoto(
      id: 'demo_photo_1',
      imageUrl: 'assets/images/milestones/valentines_khent_1.jpg',
      thumbUrl: 'assets/images/milestones/valentines_khent_1.jpg',
      caption: 'Valentine’s Day flower surprise 🌹',
      uploadedBy: 'Khent',
      uploadedAt: DateTime(2026, 2, 14),
      tags: const ['date', 'valentines', 'flowers'],
    ),
    MemoryPhoto(
      id: 'demo_photo_2',
      imageUrl: 'assets/images/milestones/kiss_khent_1.jpg',
      thumbUrl: 'assets/images/milestones/kiss_khent_1.jpg',
      caption: 'Sweetest moment under the rain ✨',
      uploadedBy: 'Khent',
      uploadedAt: DateTime(2026, 2, 17),
      tags: const ['kiss', 'rain', 'roadtrip'],
    ),
    MemoryPhoto(
      id: 'demo_photo_3',
      imageUrl: 'assets/images/milestones/puting_bato_khent_1.jpg',
      thumbUrl: 'assets/images/milestones/puting_bato_khent_1.jpg',
      caption: 'Overlooking the hills at Puting Bato 🏞️',
      uploadedBy: 'Khent',
      uploadedAt: DateTime(2026, 3, 14),
      tags: const ['view', 'hills', 'scenic'],
    ),
  ];

  static final List<DateIdea> demoDateIdeas = [
    DateIdea(id: 'demo_idea_1', title: 'Studio Ghibli Movie Marathon & Hot Cocoa'),
    DateIdea(id: 'demo_idea_2', title: 'Sunset Motorcycle Ride to Puting Bato'),
    DateIdea(id: 'demo_idea_3', title: 'Late Night Coffee & Dessert at Zackies'),
    DateIdea(id: 'demo_idea_4', title: 'Picnic with Homemade Sandwiches & Fruit Tea'),
  ];

  static final List<GuardianMessage> demoGuardianMessages = [
    GuardianMessage(
      id: 'demo_guardian_1',
      content: 'Remember that you are both deeply loved and cherished every day.',
      category: 'encouragement',
      createdAt: DateTime.now(),
    ),
    GuardianMessage(
      id: 'demo_guardian_2',
      content: 'A sweet smile from your partner is the brightest sunshine.',
      category: 'love',
      createdAt: DateTime.now(),
    ),
  ];
}
