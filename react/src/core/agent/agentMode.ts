// Port of lib/core/agent/agent_mode.dart: local test sessions with demo data.
// Never active on the live site.
import { Prefs } from '../system/prefs';
import { Logger } from '../system/logger';
import { ValueNotifier } from '../system/store';

const ACTIVE_KEY = 'everglow_agent_mode_active';
const PROFILE_KEY = 'everglow_agent_mode_profile';

const isProductionHost = (host: string) =>
  host === 'everglow-1c6db.web.app' || host === 'everglow-1c6db.firebaseapp.com';

const isLocalHost = (host: string) => host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0';

export const AgentMode = {
  routeAliases: {
    cinema: '/cinema', anime: '/anime', manga: '/manga', mangacelestia: '/manga',
    books: '/books', bibliotheca: '/books', dashboard: '/dashboard', home: '/dashboard',
    sanctuary: '/sanctuary', chat: '/sanctuary', gallery: '/gallery', journal: '/journal',
    tonight: '/tonight', calendar: '/calendar', garden: '/garden', bloom: '/garden',
    starlight: '/starlight', play: '/play-zone', playzone: '/play-zone', 'play-zone': '/play-zone',
    arcade: '/play-zone', academy: '/academy', 'trip-kit': '/trips', tripkit: '/trips',
    canvas: '/canvas', 'bucket-list': '/bucket-list', bucketlist: '/bucket-list', money: '/money',
    jukebox: '/jukebox', music: '/jukebox', 'watch-party': '/watch-party', watchparty: '/watch-party',
  } as Record<string, string>,

  isActive: new ValueNotifier(false),
  activeProfile: new ValueNotifier('khentsgdz'),
  useDemoData: new ValueNotifier(true),
  showHud: new ValueNotifier(true),
  hudCollapsed: new ValueNotifier(false),
  /** `&gift=1` with `?agent=`: preview Clair's welcome gift with demo content. */
  giftPreview: false,

  /** Services read demo fixtures instead of Firestore when this is true. */
  get demo(): boolean {
    return AgentMode.isActive.value && AgentMode.useDemoData.value;
  },

  get isLocalDev(): boolean {
    return isLocalHost(window.location.hostname) || import.meta.env.DEV;
  },

  get canActivate(): boolean {
    return !isProductionHost(window.location.hostname);
  },

  parseProfile(value: string | null): string {
    if (!value || value === '1' || value === 'true') return 'khentsgdz';
    const lower = value.toLowerCase().trim();
    if (lower === 'clair' || lower === 'clairjassen') return 'clairjassen';
    if (lower === 'cinema' || lower === 'breyan' || lower === 'guest') return 'breyan';
    return 'khentsgdz';
  },

  init(): void {
    if (isProductionHost(window.location.hostname)) {
      AgentMode.clearPersistedState();
      return;
    }
    const params = new URLSearchParams(window.location.search);
    const agentParam = params.get('agent') ?? params.get('demo');
    if (agentParam != null) {
      AgentMode.giftPreview = params.get('gift') === '1';
      AgentMode.enable(AgentMode.parseProfile(agentParam));
      return;
    }
    if (Prefs.getBool(ACTIVE_KEY)) {
      AgentMode.isActive.value = true;
      AgentMode.activeProfile.value = Prefs.getString(PROFILE_KEY) ?? 'khentsgdz';
    }
  },

  enable(profile = 'khentsgdz'): boolean {
    if (isProductionHost(window.location.hostname)) return false;
    AgentMode.isActive.value = true;
    AgentMode.activeProfile.value = profile;
    Logger.i(`[AgentMode] Activated with profile: ${profile}`);
    AgentMode.persist();
    return true;
  },

  switchProfile(profile: string): void {
    AgentMode.activeProfile.value = profile;
    Logger.i(`[AgentMode] Switched profile to: ${profile}`);
    AgentMode.persist();
  },

  clearPersistedState(): void {
    AgentMode.isActive.value = false;
    Prefs.remove(ACTIVE_KEY);
    Prefs.remove(PROFILE_KEY);
  },

  persist(): void {
    Prefs.set(ACTIVE_KEY, AgentMode.isActive.value);
    Prefs.set(PROFILE_KEY, AgentMode.activeProfile.value);
  },
};
