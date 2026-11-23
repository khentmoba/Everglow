// Port of lib/features/guardian/presentation/controllers/guardian_controller.dart.
import { authService } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { ValueNotifier } from '../../core/system/store';
import { moodService, type UserMood } from '../heartbeat/moodService';
import { guardianService, type GuardianMessage } from './guardianService';

export type GuardianState = 'idle' | 'greeting' | 'reacting' | 'thinking';

const LOCAL_GREETINGS = [
  '✨ Purring with love for you two!',
  '🐱 Meow! Hope today feels soft and sweet!',
  '🍡 Motchi is watching over you both!',
  '💕 You two make everything brighter!',
  '🌙 Rest a little — I saved you a warm spot!',
];

class GuardianController {
  state = new ValueNotifier<GuardianState>('idle');
  currentMessage = new ValueNotifier<GuardianMessage | null>(null);
  isMessageVisible = new ValueNotifier(false);
  isMoodPromptVisible = new ValueNotifier(false);
  isAIMode = new ValueNotifier(false);

  private idleTimer: number | null = null;
  private dismissTimer: number | null = null;
  private welcomeTimer: number | null = null;
  private reactTimer: number | null = null;
  private messageCounter = 0;
  private lastTapAt = 0;
  private moodCache: UserMood | null = null;
  private moodCacheAt = 0;
  private idlePaused = false;

  toggleAIMode() {
    const next = !this.isAIMode.value;
    this.isAIMode.value = next;
    this.currentMessage.value = next
      ? {
          id: 'ai_greeting',
          content: "✨ I'm in AI mode now! Tap me and tell me something!",
          category: 'ai',
          createdAt: new Date(),
        }
      : {
          id: 'mode_switch',
          content: 'Back to normal mode! 🐱',
          category: 'idle',
          createdAt: new Date(),
        };
    this.isMessageVisible.value = true;
    this.scheduleDismiss(4000);
  }

  welcome() {
    this.state.value = 'greeting';
    if (this.welcomeTimer) clearTimeout(this.welcomeTimer);
    this.welcomeTimer = window.setTimeout(() => {
      this.welcomeTimer = null;
      this.state.value = 'idle';
      this.startIdleTimer();
    }, 2000);
  }

  react() {
    const now = Date.now();
    if (now - this.lastTapAt < 400) return;
    this.lastTapAt = now;
    this.state.value = 'reacting';
    if (this.isAIMode.value) {
      if (this.dismissTimer) clearTimeout(this.dismissTimer);
      this.currentMessage.value = {
        id: 'ai_prompt',
        content: "💬 Tell me something! What's on your mind?",
        category: 'ai',
        createdAt: new Date(),
      };
      this.isMessageVisible.value = true;
    } else {
      void this.showMessage();
    }
    if (this.reactTimer) clearTimeout(this.reactTimer);
    this.reactTimer = window.setTimeout(() => {
      this.reactTimer = null;
      if (this.state.value === 'reacting') this.state.value = 'idle';
    }, 800);
  }

  async sendAIMessage(message: string) {
    if (this.state.value === 'thinking') return;
    this.state.value = 'thinking';
    this.isMessageVisible.value = true;
    if (this.dismissTimer) clearTimeout(this.dismissTimer);
    this.currentMessage.value = {
      id: 'thinking',
      content: '🤔 *thinking...*',
      category: 'ai',
      createdAt: new Date(),
    };
    try {
      // Uses local greeting fallback until AI service moves over.
      const reply = LOCAL_GREETINGS[Math.floor(Math.random() * LOCAL_GREETINGS.length)];
      this.state.value = 'reacting';
      this.currentMessage.value = {
        id: `ai_reply_${Date.now()}`,
        content: message ? reply : LOCAL_GREETINGS[0],
        category: 'ai',
        createdAt: new Date(),
      };
      this.isMessageVisible.value = true;
      this.scheduleDismiss(8000);
    } catch (e) {
      Logger.e('Guardian AI reply failed', e);
      this.state.value = 'idle';
      this.currentMessage.value = {
        id: 'error',
        content: '😿 Oops, I got distracted! Tap me again!',
        category: 'ai',
        createdAt: new Date(),
      };
      this.isMessageVisible.value = true;
      this.scheduleDismiss(4000);
    }
  }

  pauseIdle() {
    this.idlePaused = true;
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
      this.idleTimer = null;
    }
  }

  resumeIdle() {
    if (!this.idlePaused) return;
    this.idlePaused = false;
    this.startIdleTimer();
  }

  private startIdleTimer() {
    if (this.idleTimer) clearTimeout(this.idleTimer);
    if (this.idlePaused) return;
    const minutes = 3 + Math.floor(Math.random() * 5);
    this.idleTimer = window.setTimeout(() => {
      if (this.idlePaused) return;
      void this.showMessage();
      this.startIdleTimer();
    }, minutes * 60_000);
  }

  private async showMessage() {
    this.messageCounter++;
    if (this.dismissTimer) clearTimeout(this.dismissTimer);

    if (this.messageCounter % 7 === 0) {
      try {
        const partnerUsername = authService.partnerUsername ?? '';
        const partnerName = authService.partnerName;
        let latest = this.moodCache;
        const fresh = this.moodCacheAt > 0 && Date.now() - this.moodCacheAt < 5 * 60_000;
        if (!fresh && partnerUsername) {
          latest = await moodService.getLatestMood(partnerUsername);
          this.moodCache = latest;
          this.moodCacheAt = Date.now();
        }
        if (latest) {
          this.currentMessage.value = {
            id: 'partner_mood',
            content: `${partnerName} is feeling ${latest.moodEmoji} today!`,
            category: 'mood',
            createdAt: new Date(),
          };
          this.isMessageVisible.value = true;
          this.scheduleDismiss(5000);
          return;
        }
      } catch (e) {
        Logger.e('Guardian mood mention failed', e);
      }
    }

    const msg = guardianService.getRandomMessage();
    if (msg) {
      this.currentMessage.value = msg;
      this.isMessageVisible.value = true;
      this.scheduleDismiss(5000);
    }
  }

  private scheduleDismiss(afterMs: number) {
    if (this.dismissTimer) clearTimeout(this.dismissTimer);
    this.dismissTimer = window.setTimeout(() => {
      this.isMessageVisible.value = false;
      if (this.state.value !== 'thinking') this.state.value = 'idle';
    }, afterMs);
  }

  triggerMoodPrompt() {
    if (this.dismissTimer) clearTimeout(this.dismissTimer);
    this.isMoodPromptVisible.value = true;
    this.currentMessage.value = {
      id: 'mood_prompt',
      content: 'How is your heart today?',
      category: 'prompt',
      createdAt: new Date(),
    };
    this.isMessageVisible.value = true;
  }

  dismissMoodPrompt() {
    if (this.dismissTimer) clearTimeout(this.dismissTimer);
    this.isMoodPromptVisible.value = false;
    this.isMessageVisible.value = false;
  }
}

export const guardianController = new GuardianController();
