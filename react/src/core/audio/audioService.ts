// Port of lib/core/audio/audio_service.dart: one short sound at a time,
// silent when the shared "isMuted" preference is on.
import { Logger } from '../system/logger';
import { Prefs } from '../system/prefs';

export const Sfx = { sparkle: '/audio/sparkle.mp3', levelUp: '/audio/level_up.mp3' };

let player: HTMLAudioElement | null = null;

export async function playSfx(src: string): Promise<void> {
  if (Prefs.getBool('isMuted') === true) return;
  try {
    player?.pause();
    player = new Audio(src);
    await player.play();
  } catch (e) {
    Logger.d(`SFX playback skipped: ${String(e)}`);
  }
}
