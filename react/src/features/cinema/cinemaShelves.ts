// The Browse shelves behind Home's discovery rails.
export interface DiscoveryShelf {
  title: string;
  type: 'movie' | 'tv';
  genre?: number;
  language?: string;
  reason: string;
}

export const DISCOVERY_SHELVES: DiscoveryShelf[] = [
  { title: 'Top-Rated Movies', type: 'movie', reason: 'Loved by critics and viewers' },
  { title: 'Top-Rated Series', type: 'tv', reason: 'The best of the small screen' },
  { title: 'Action & Adventure', type: 'movie', genre: 28, reason: 'Big set pieces, bigger stakes' },
  { title: 'Need a Laugh?', type: 'movie', genre: 35, reason: 'Short of time, long on smiles' },
  { title: 'Romance', type: 'movie', genre: 10749, reason: 'Slow burns and grand gestures' },
  { title: 'Edge-of-Your-Seat Thrillers', type: 'movie', genre: 53, reason: 'Lights off, heart rate up' },
  { title: 'Sci-Fi Escapes', type: 'movie', genre: 878, reason: 'Other worlds, familiar feelings' },
  { title: 'Drama', type: 'movie', genre: 18, reason: 'Serious stories, big feelings' },
];

