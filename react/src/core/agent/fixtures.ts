// Port of lib/core/agent/agent_fixtures.dart: made-up demo data for agent mode.
// Never real couple data.
import type { UserProgress } from '../../features/xp/xpService';

export type GuardianMessageFixture = {
  id: string;
  content: string;
  category: string;
  createdAt: Date;
};

export type HiddenNoteFixture = {
  id: string;
  title: string;
  content: string;
  unlockDate: Date;
  isRead: boolean;
};

export type CalendarEventType = 'dateNight' | 'anniversary' | 'reminder' | 'custom';

export type CalendarEventFixture = {
  id: string;
  title: string;
  description: string;
  date: Date;
  type: CalendarEventType;
  createdBy: string;
  recurring?: string;
};

export type TonightOptionType = 'movie' | 'date' | 'game';
export type TonightStatus = 'voting' | 'decided' | 'planned';

export type TonightOptionFixture = {
  id: string;
  type: TonightOptionType;
  title: string;
  subtitle: string;
  description: string;
  targetRoute?: string;
};

export type TonightDecisionFixture = {
  id: string;
  status: TonightStatus;
  options: TonightOptionFixture[];
  votes: Record<string, string>;
  winnerOptionId?: string;
  planTime?: Date;
  createdAt: Date;
  updatedAt: Date;
};

export type GardenStatsFixture = {
  currentStage: number;
  lastVisit: Date;
  streakCount: number;
  totalInteractions: number;
  plantType: string;
};

export type StarNoteFixture = {
  id: string;
  content: string;
  author: string;
  timestamp: Date;
  category: string;
  tags: string[];
};

export type MilestoneCategory = 'firstDate' | 'anniversary' | 'trip' | 'memory' | 'other';

export type MilestoneFixture = {
  id: string;
  title: string;
  description: string;
  date: Date;
  author: string;
  category: MilestoneCategory;
  imageUrls: string[];
};

export type MemoryPhotoFixture = {
  id: string;
  imageUrl: string;
  thumbUrl: string;
  caption: string;
  uploadedBy: string;
  uploadedAt: Date;
  tags: string[];
  locationName?: string;
};

export type JournalEntryFixture = {
  id: string;
  title: string;
  content: string;
  author: string;
  createdAt: Date;
  updatedAt: Date;
  category: string;
  mood: string;
  tags: string[];
  isPinned: boolean;
  wordCount: number;
};

export type BucketItemFixture = {
  id: string;
  title: string;
  description: string;
  category: string;
  status: 'wish' | 'planned' | 'completed';
  createdBy: string;
  createdAt: Date;
  completedAt?: Date;
  completedBy?: string;
  priority: 'low' | 'medium' | 'high';
};

export type ChatMessageFixture = {
  id: string;
  sender: string;
  senderUid: string;
  text: string;
  timestamp: Date;
};

export type DateIdeaFixture = { id: string; title: string };

export const AgentFixtures = {
  demoProgress: (uid: string): UserProgress => ({
    uid,
    xpTotal: 420,
    level: 3,
    streak: 4,
    lastActivity: new Date(2026, 10, 4),
  }),
  demoMood: { username: 'clairjassen', moodScore: 5, moodEmoji: '💖' },
  demoGuardianMessages: (): GuardianMessageFixture[] => [
    {
      id: 'demo_guardian_1',
      content: 'Remember that you are both deeply loved and cherished every day.',
      category: 'encouragement',
      createdAt: new Date(),
    },
    {
      id: 'demo_guardian_2',
      content: 'A sweet smile from your partner is the brightest sunshine.',
      category: 'love',
      createdAt: new Date(),
    },
  ],
  demoNotes: (): HiddenNoteFixture[] => [
    {
      id: 'demo_note_1',
      title: 'Always Thinking of You 💖',
      content: 'Just a little reminder of how proud I am of you every single day. Keep shining my love!',
      unlockDate: new Date(Date.now() - 3 * 86_400_000),
      isRead: true,
    },
    {
      id: 'demo_note_2',
      title: 'Movie Night Tonight 🎬',
      content: 'I picked out the best snacks for our Studio Ghibli marathon. Can’t wait to cuddle and watch together!',
      unlockDate: new Date(Date.now() - 4 * 3_600_000),
      isRead: false,
    },
    {
      id: 'demo_note_3',
      title: 'A Secret Promise 🌸',
      content: 'No matter how busy life gets, I will always choose you, cherish you, and walk hand-in-hand with you.',
      unlockDate: new Date(Date.now() - 10 * 86_400_000),
      isRead: true,
    },
  ],
  demoEvents: (): CalendarEventFixture[] => [
    {
      id: 'demo_event_1',
      title: 'Our Monthly Anniversary 💕',
      description: 'Celebrating another month of endless love and happiness.',
      date: new Date(Date.now() + 3 * 86_400_000),
      type: 'anniversary',
      createdBy: 'khentsgdz',
      recurring: 'monthly',
    },
    {
      id: 'demo_event_2',
      title: 'Cinema & Ramen Date Night 🍜',
      description: 'Watch the new anime movie and eat hot tonkotsu ramen.',
      date: new Date(Date.now() + 6 * 86_400_000),
      type: 'dateNight',
      createdBy: 'clairjassen',
    },
    {
      id: 'demo_event_3',
      title: 'Weekend Garden Bloom Watering 🌸',
      description: 'Tend to our shared Everglow digital garden together.',
      date: new Date(Date.now() + 1 * 86_400_000),
      type: 'reminder',
      createdBy: 'khentsgdz',
    },
  ],
  demoDecision: (): TonightDecisionFixture => ({
    id: 'demo_tonight_1',
    status: 'voting',
    options: [
      {
        id: 'opt_1',
        type: 'movie',
        title: 'Spirited Away',
        subtitle: 'Studio Ghibli Classic',
        description: 'Immerse into Chihiro’s magical journey.',
      },
      {
        id: 'opt_2',
        type: 'date',
        title: 'Late Night Coffee & Dessert',
        subtitle: 'Zackies / 7-11',
        description: 'Warm latte and cozy sweet talks.',
      },
      {
        id: 'opt_3',
        type: 'game',
        title: 'Everglow Play Zone Showdown',
        subtitle: 'Arcade Mini-games',
        description: 'Challenge each other to high-score games.',
      },
    ],
    votes: { khentsgdz: 'opt_1', clairjassen: 'opt_1' },
    winnerOptionId: 'opt_1',
    createdAt: new Date(),
    updatedAt: new Date(),
  }),
  demoGardenStats: (): GardenStatsFixture => ({
    currentStage: 3,
    lastVisit: new Date(),
    streakCount: 42,
    totalInteractions: 128,
    plantType: 'lily',
  }),
  demoStars: (): StarNoteFixture[] => [
    {
      id: 'demo_star_1',
      content: 'Grateful for your warm smile that lights up my whole world.',
      author: 'Khent',
      timestamp: new Date(Date.now() - 86_400_000),
      category: 'gratitude',
      tags: ['smile', 'love'],
    },
    {
      id: 'demo_star_2',
      content: 'Remembering when we hid in front of CSU and you surprised me.',
      author: 'Clair',
      timestamp: new Date(Date.now() - 5 * 86_400_000),
      category: 'memory',
      tags: ['cute', 'date'],
    },
    {
      id: 'demo_star_3',
      content: 'Dreaming of our road trip across Japan together one day!',
      author: 'Khent',
      timestamp: new Date(Date.now() - 12 * 86_400_000),
      category: 'dream',
      tags: ['travel', 'japan'],
    },
  ],
  demoMilestones: (): MilestoneFixture[] => [
    {
      id: 'demo_milestone_1',
      title: 'Demo coffee date',
      description: 'A fictional afternoon sharing coffee and favorite songs.',
      date: new Date(2026, 1, 14),
      author: 'Khent',
      category: 'firstDate',
      imageUrls: ['/images/demo/poster-1.jpg', '/images/demo/poster-2.jpg', '/images/demo/poster-3.jpg'],
    },
    {
      id: 'demo_milestone_2',
      title: 'Demo rainy evening',
      description: 'A fictional rainy evening with warm drinks and a movie.',
      date: new Date(2026, 1, 17),
      author: 'Khent',
      category: 'memory',
      imageUrls: ['/images/demo/poster-4.jpg', '/images/demo/poster-1.jpg', '/images/demo/poster-2.jpg'],
    },
    {
      id: 'demo_milestone_3',
      title: 'Demo road trip',
      description: 'An imaginary road trip past green hills and a picnic stop.',
      date: new Date(2026, 2, 14),
      author: 'Khent',
      category: 'trip',
      imageUrls: ['/images/demo/poster-3.jpg', '/images/demo/poster-4.jpg', '/images/demo/poster-1.jpg'],
    },
    {
      id: 'demo_milestone_4',
      title: 'Demo birthday picnic',
      description: 'An imaginary birthday picnic with snacks and board games.',
      date: new Date(2026, 1, 20),
      author: 'Khent',
      category: 'anniversary',
      imageUrls: ['/images/demo/poster-2.jpg', '/images/demo/poster-3.jpg'],
    },
  ],
  demoPhotos: (): MemoryPhotoFixture[] => [
    {
      id: 'demo_photo_1',
      imageUrl: '/images/demo/poster-1.jpg',
      thumbUrl: '/images/demo/poster-1.jpg',
      caption: 'Demo artwork: rose-colored evening',
      uploadedBy: 'Khent',
      uploadedAt: new Date(2026, 1, 14),
      tags: ['date', 'valentines', 'flowers'],
    },
    {
      id: 'demo_photo_2',
      imageUrl: '/images/demo/poster-4.jpg',
      thumbUrl: '/images/demo/poster-4.jpg',
      caption: 'Demo artwork: rainy evening',
      uploadedBy: 'Khent',
      uploadedAt: new Date(2026, 1, 17),
      tags: ['kiss', 'rain', 'roadtrip'],
    },
    {
      id: 'demo_photo_3',
      imageUrl: '/images/demo/poster-3.jpg',
      thumbUrl: '/images/demo/poster-3.jpg',
      caption: 'Demo artwork: imaginary hills',
      uploadedBy: 'Khent',
      uploadedAt: new Date(2026, 2, 14),
      tags: ['view', 'hills', 'scenic'],
    },
  ],
  demoJournalEntries: (): JournalEntryFixture[] => [
    {
      id: 'demo_journal_1',
      title: 'The Magic of Ordinary Days ☕',
      content: 'Sometimes the sweetest memories are the simplest ones — having coffee by the corner, laughing at random reels, and knowing you’re right there beside me.',
      author: 'khentsgdz',
      createdAt: new Date(Date.now() - 2 * 86_400_000),
      updatedAt: new Date(Date.now() - 2 * 86_400_000),
      category: 'gratitude',
      mood: 'loved',
      tags: ['love', 'peace', 'us'],
      isPinned: true,
      wordCount: 32,
    },
    {
      id: 'demo_journal_2',
      title: 'Looking Forward to our Next Adventure ✨',
      content: 'Counting down the days to our next roadtrip. Every milestone with you feels like a page out of a fairy tale.',
      author: 'clairjassen',
      createdAt: new Date(Date.now() - 7 * 86_400_000),
      updatedAt: new Date(Date.now() - 7 * 86_400_000),
      category: 'daily',
      mood: 'excited',
      tags: ['adventure', 'future'],
      isPinned: false,
      wordCount: 26,
    },
  ],
  demoBucketList: (): BucketItemFixture[] => [
    {
      id: 'demo_bucket_1',
      title: 'Trip to Tokyo & Kyoto 🇯🇵',
      description: 'Visit Studio Ghibli Museum, see cherry blossoms, and explore Kyoto temples.',
      category: 'travel',
      status: 'planned',
      createdBy: 'khentsgdz',
      createdAt: new Date(2026, 1, 15),
      priority: 'high',
    },
    {
      id: 'demo_bucket_2',
      title: 'Stargazing Campfire at Puting Bato 🌌',
      description: 'Bring hot cocoa, warm blankets, and watch shooting stars all night.',
      category: 'adventure',
      status: 'wish',
      createdBy: 'clairjassen',
      createdAt: new Date(2026, 1, 20),
      priority: 'medium',
    },
    {
      id: 'demo_bucket_3',
      title: 'Bake Strawberry Matcha Cake Together 🍰',
      description: 'Follow our special recipe and decorate it with heart strawberries.',
      category: 'food',
      status: 'completed',
      createdBy: 'clairjassen',
      createdAt: new Date(2026, 2, 1),
      completedAt: new Date(2026, 2, 10),
      completedBy: 'clairjassen',
      priority: 'low',
    },
  ],
  demoChatMessages: (): ChatMessageFixture[] => [
    {
      id: 'msg_1',
      sender: 'clairjassen',
      senderUid: 'agent_clairjassen_uid',
      text: 'Good morning love! Hope you slept well 🥰',
      timestamp: new Date(Date.now() - 3 * 3_600_000),
    },
    {
      id: 'msg_2',
      sender: 'khentsgdz',
      senderUid: 'agent_khentsgdz_uid',
      text: 'Good morning gorgeous! Ready for our movie night later? 🎬💖',
      timestamp: new Date(Date.now() - (2 * 60 + 45) * 60_000),
    },
    {
      id: 'msg_3',
      sender: 'clairjassen',
      senderUid: 'agent_clairjassen_uid',
      text: 'Yessss! Already craving popcorn! See you soonest 💕',
      timestamp: new Date(Date.now() - (60 + 10) * 60_000),
    },
  ],
  demoDateIdeas: (): DateIdeaFixture[] => [
    { id: 'demo_idea_1', title: 'Studio Ghibli Movie Marathon & Hot Cocoa' },
    { id: 'demo_idea_2', title: 'Sunset Motorcycle Ride to Puting Bato' },
    { id: 'demo_idea_3', title: 'Late Night Coffee & Dessert at Zackies' },
    { id: 'demo_idea_4', title: 'Picnic with Homemade Sandwiches & Fruit Tea' },
  ],
};
