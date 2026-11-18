// Port of lib/features/entry/presentation/state/gateway_state.dart.

export type GatewayState =
  | 'initialLoad'
  | 'awaitingInput'
  | 'evaluating'
  | 'error'
  | 'unlocking'
  | 'revealingSite'
  | 'complete';

export type GatewayFailureReason = 'invalidCode' | 'connection';

const ALLOWED = ['khentsgdz', 'clairjassen', 'breyan', 'octagram'];

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

export class GatewayNotifier {
  currentState: GatewayState = 'awaitingInput';
  currentInput = '';
  lastEnteredPasscode: string | null = null;
  lastFailureReason: GatewayFailureReason | null = null;

  verifyCouplePasscode: ((code: string) => Promise<string | null>) | null = null;
  tryOfflineUnlock: ((code: string) => Promise<string | null>) | null = null;
  hasOfflineRememberedCode: (() => boolean) | null = null;

  private listeners = new Set<() => void>();
  private version = 0;

  subscribe = (l: () => void) => {
    this.listeners.add(l);
    return () => this.listeners.delete(l);
  };

  getVersion = () => this.version;

  private notify() {
    this.version++;
    for (const l of this.listeners) l();
  }

  setFailureReason(reason: GatewayFailureReason) {
    this.lastFailureReason = reason;
    this.notify();
  }

  updateState(next: GatewayState) {
    this.currentState = next;
    this.notify();
  }

  appendDigit = (digit: string) => {
    if (this.currentInput.length < 4 && this.currentState === 'awaitingInput') {
      this.lastFailureReason = null;
      this.currentInput += digit;
      this.notify();
      if (this.currentInput.length === 4) void this.validatePasscode();
    }
  };

  backspace = () => {
    if (this.currentInput.length > 0 && this.currentState === 'awaitingInput') {
      this.currentInput = this.currentInput.slice(0, -1);
      this.notify();
    }
  };

  clearInput = () => {
    this.currentInput = '';
    this.notify();
  };

  private async validatePasscode() {
    this.updateState('evaluating');
    await delay(220);

    if (this.verifyCouplePasscode) {
      try {
        const username = await this.verifyCouplePasscode(this.currentInput);
        if (username != null && ALLOWED.includes(username)) {
          this.lastFailureReason = null;
          this.lastEnteredPasscode = this.currentInput;
          this.updateState('unlocking');
          return;
        }
        this.lastFailureReason = 'invalidCode';
      } catch {
        const remembered = await this.tryOfflineUnlock?.(this.currentInput);
        if (remembered === 'khentsgdz' || remembered === 'clairjassen') {
          this.lastFailureReason = null;
          this.lastEnteredPasscode = this.currentInput;
          this.updateState('unlocking');
          return;
        }
        this.lastFailureReason = this.hasOfflineRememberedCode?.() === true ? 'invalidCode' : 'connection';
      }
    } else {
      this.lastFailureReason = 'invalidCode';
    }
    this.updateState('error');
    await delay(500);
    this.clearInput();
    this.updateState('awaitingInput');
  }
}
