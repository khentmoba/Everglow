/// Warm, time-aware greeting lines for Motchi's welcome screen.
///
/// Pure and tiny on purpose: the chat empty-state shows these with zero
/// backend calls, so Clair always gets a personal hello even offline.
library;

/// Pet name Motchi uses for each user. Unknown/null → no name.
String motchiPetName(String? username) {
  switch (username) {
    case 'khentsgdz':
      return 'Dada';
    case 'clairjassen':
      return 'Mama';
    default:
      return '';
  }
}

/// "Good evening, Mama 🍡" — title line for the welcome screen.
String motchiGreetingTitle(DateTime now, String? username) {
  final pet = motchiPetName(username);
  final who = pet.isEmpty ? '' : ', $pet';
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning$who 🍡';
  if (h >= 12 && h < 18) return 'Good afternoon$who';
  if (h >= 18 && h < 22) return 'Good evening$who 🍡';
  return pet.isEmpty ? 'Up late? 🌙' : 'Up late$who? 🌙';
}

/// One warm contextual line under the greeting.
String motchiGreetingSubtitle(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) {
    return 'A fresh day for you two — what shall we do first?';
  }
  if (h >= 12 && h < 18) {
    return 'Hope your day is going lovely — I\'m purring right here.';
  }
  if (h >= 18 && h < 22) {
    return 'Wind down with me — a recap, a game, or a little plan?';
  }
  return 'The stars are out — tell me about your day?';
}
