// Port of lib/shared/utils/text_utils.dart (formatPeso).
const whole = new Intl.NumberFormat('en-PH', { maximumFractionDigits: 0 });
const cents = new Intl.NumberFormat('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** ₱1,234 — or ₱1,234.50 when the amount has cents. */
export function formatPeso(amount: number): string {
  const hasCents = Math.abs(amount - Math.trunc(amount)) > 0.004;
  return `₱${(hasCents ? cents : whole).format(amount)}`;
}

/** text_utils.dart displayNameFor: the couple and family usernames as people say them. */
export function displayNameFor(username: string | null | undefined): string {
  switch (username) {
    case 'khentsgdz':
      return 'Khent';
    case 'clairjassen':
      return 'Clair';
    case 'breyan':
      return 'Breyan';
    case 'octagram':
      return 'Octagram';
    default:
      if (!username) return 'Love';
      return username[0].toUpperCase() + username.slice(1);
  }
}
