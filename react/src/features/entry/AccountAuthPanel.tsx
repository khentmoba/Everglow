import { useState, type CSSProperties, type FormEvent } from 'react';
import { AccountAuthError, authService } from '../../core/services/auth';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { boxShadow, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

type AuthMode = 'signin' | 'register';

const fieldStyle: CSSProperties = {
  width: '100%',
  padding: '12px 14px',
  borderRadius: AppRadius.sm,
  background: withAlpha(AppColors.shimmerBase, 0.92),
  border: `1px solid ${Derived.border}`,
  color: AppColors.petalWhite,
  outline: 'none',
  fontSize: 14,
  fontFamily: 'inherit',
  boxSizing: 'border-box',
};

export function AccountAuthPanel({
  onSuccess,
  onBackToDoor,
}: {
  onSuccess: (username: string) => void;
  onBackToDoor: () => void;
}) {
  const [mode, setMode] = useState<AuthMode>('signin');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [errorTone, setErrorTone] = useState<'error' | 'pending'>('error');
  const [pendingCreatedUser, setPendingCreatedUser] = useState<string | null>(null);

  const passwordsMismatch =
    mode === 'register' && confirmPassword.length > 0 && password !== confirmPassword;

  const switchMode = (next: AuthMode) => {
    setMode(next);
    setError(null);
    setErrorTone('error');
    setPendingCreatedUser(null);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setError(null);
    setErrorTone('error');

    const cleanUser = username.trim();
    if (!cleanUser) {
      setError('Please enter a username.');
      return;
    }

    if (mode === 'register') {
      if (!/^[a-zA-Z0-9_-]{3,24}$/.test(cleanUser)) {
        setError('Username must be 3–24 characters (letters, numbers, -, _).');
        return;
      }
      if (password.length < 6) {
        setError('Password must be at least 6 characters.');
        return;
      }
      if (password !== confirmPassword) {
        setError('Passwords do not match.');
        return;
      }
      setBusy(true);
      try {
        const result = await authService.registerAccount(cleanUser, password, confirmPassword);
        setPendingCreatedUser(result.username);
        setPassword('');
        setConfirmPassword('');
      } catch (err) {
        if (err instanceof AccountAuthError) {
          setError(err.message);
        } else {
          setError('Could not create account. Please try again.');
        }
      } finally {
        setBusy(false);
      }
      return;
    }

    if (!password) {
      setError('Please enter your password.');
      return;
    }
    setBusy(true);
    try {
      const signedInUser = await authService.loginWithAccount(cleanUser, password);
      onSuccess(signedInUser);
    } catch (err) {
      if (err instanceof AccountAuthError) {
        setErrorTone(err.code === 'pending' ? 'pending' : 'error');
        setError(err.message);
      } else {
        setError('Sign in failed. Please try again.');
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      style={{
        width: 'min(390px, calc(100vw - 32px))',
        padding: '22px 20px 20px',
        borderRadius: 24,
        background: withAlpha(AppColors.inkDeep, 0.92),
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.22)}`,
        boxShadow: boxShadow([{ offset: [0, 18], blur: 48, color: 'rgba(0,0,0,0.58)' }]),
        display: 'flex',
        flexDirection: 'column',
        gap: 14,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
        <div>
          <div style={{ ...AppTypography.outfitHeading, fontSize: 19, color: AppColors.petalWhite }}>
            {pendingCreatedUser
              ? 'Pending Approval'
              : mode === 'signin'
                ? 'Account Sign In'
                : 'Create Account'}
          </div>
          <div style={{ ...AppTypography.outfitWhite, fontSize: 12, color: Derived.textMuted, marginTop: 2 }}>
            {pendingCreatedUser
              ? 'Waiting for Khent to approve'
              : mode === 'signin'
                ? 'Sign in with your username and password'
                : 'Choose a username for Cinema, Anime, Books, Manga & Chat'}
          </div>
        </div>
        <button
          type="button"
          className="bare-button"
          aria-label="Switch to passcode door"
          onClick={onBackToDoor}
          style={{
            padding: '6px 10px',
            borderRadius: 999,
            background: withAlpha(AppColors.petalWhite, 0.08),
            border: `1px solid ${Derived.border}`,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 11.5,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
            flexShrink: 0,
          }}
        >
          <Icon name="dialpad" size={14} color={AppColors.blushGold} />
          <span>Door Key</span>
        </button>
      </div>

      {pendingCreatedUser ? (
        <div
          role="status"
          style={{
            padding: 16,
            borderRadius: AppRadius.md,
            background: withAlpha(AppColors.blushGold, 0.12),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.42)}`,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            textAlign: 'center',
            gap: 10,
          }}
        >
          <div
            style={{
              width: 46,
              height: 46,
              borderRadius: '50%',
              background: withAlpha(AppColors.blushGold, 0.18),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="hourglass_top" size={24} color={AppColors.blushGold} />
          </div>
          <div style={{ ...AppTypography.outfitBold, fontSize: 15, color: AppColors.petalWhite }}>
            @{pendingCreatedUser} is pending approval
          </div>
          <div style={{ ...AppTypography.outfitWhite, fontSize: 12.5, color: Derived.textMedium, lineHeight: 1.45 }}>
            Your account has been submitted. Let Khent know your username so he can approve it in the Creator Dashboard.
          </div>
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              setUsername(pendingCreatedUser);
              switchMode('signin');
            }}
            style={{
              marginTop: 4,
              width: '100%',
              padding: '11px 16px',
              borderRadius: AppRadius.sm,
              background: linear([AppColors.deepRose, AppColors.rosePressed]),
              color: AppColors.petalWhite,
              ...AppTypography.outfitBold,
              fontSize: 13.5,
            }}
          >
            Back to Sign In
          </button>
        </div>
      ) : (
        <>
          <div
            role="tablist"
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr 1fr',
              gap: 6,
              padding: 4,
              borderRadius: AppRadius.sm,
              background: withAlpha(AppColors.shimmerBase, 0.7),
              border: `1px solid ${Derived.border}`,
            }}
          >
            {(
              [
                ['signin', 'Sign In'],
                ['register', 'Create Account'],
              ] as const
            ).map(([id, label]) => {
              const active = mode === id;
              return (
                <button
                  key={id}
                  role="tab"
                  aria-selected={active}
                  type="button"
                  className="bare-button"
                  onClick={() => switchMode(id)}
                  style={{
                    padding: '8px 10px',
                    borderRadius: 10,
                    background: active ? withAlpha(AppColors.deepRose, 0.28) : 'transparent',
                    border: `1px solid ${active ? withAlpha(AppColors.blushGold, 0.45) : 'transparent'}`,
                    color: active ? AppColors.petalWhite : Derived.textMuted,
                    ...AppTypography.outfitBold,
                    fontSize: 12.5,
                  }}
                >
                  {label}
                </button>
              );
            })}
          </div>

          <form onSubmit={(e) => void handleSubmit(e)} style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
              <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: Derived.textMedium }}>Username</span>
              <input
                type="text"
                autoComplete="username"
                value={username}
                onChange={(e) => {
                  setUsername(e.target.value);
                  if (error) setError(null);
                }}
                placeholder={mode === 'register' ? 'Choose a username (e.g. sora_99)' : 'Enter your username'}
                maxLength={24}
                style={fieldStyle}
              />
            </label>

            <label style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
              <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: Derived.textMedium }}>Password</span>
              <div style={{ position: 'relative' }}>
                <input
                  type={showPassword ? 'text' : 'password'}
                  autoComplete={mode === 'register' ? 'new-password' : 'current-password'}
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    if (error) setError(null);
                  }}
                  placeholder={mode === 'register' ? 'At least 6 characters' : 'Enter your password'}
                  maxLength={128}
                  style={{ ...fieldStyle, paddingRight: 40 }}
                />
                <button
                  type="button"
                  className="bare-button"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  onClick={() => setShowPassword((v) => !v)}
                  style={{
                    position: 'absolute',
                    right: 8,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    padding: 4,
                    display: 'flex',
                    alignItems: 'center',
                  }}
                >
                  <Icon
                    name={showPassword ? 'visibility_off' : 'visibility'}
                    size={18}
                    color={Derived.textMuted}
                  />
                </button>
              </div>
            </label>

            {mode === 'register' && (
              <label style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: Derived.textMedium }}>
                  Confirm Password
                </span>
                <input
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="new-password"
                  value={confirmPassword}
                  onChange={(e) => {
                    setConfirmPassword(e.target.value);
                    if (error) setError(null);
                  }}
                  placeholder="Re-enter your password"
                  maxLength={128}
                  style={{
                    ...fieldStyle,
                    border: `1px solid ${passwordsMismatch ? AppColors.error : Derived.border}`,
                  }}
                />
                {passwordsMismatch && (
                  <span role="alert" style={{ ...AppTypography.outfitWhite, fontSize: 11.5, color: AppColors.error }}>
                    Passwords do not match
                  </span>
                )}
              </label>
            )}

            {error && (
              <div
                role="alert"
                style={{
                  padding: '10px 12px',
                  borderRadius: AppRadius.sm,
                  background:
                    errorTone === 'pending'
                      ? withAlpha(AppColors.blushGold, 0.14)
                      : withAlpha(AppColors.error, 0.14),
                  border: `1px solid ${
                    errorTone === 'pending'
                      ? withAlpha(AppColors.blushGold, 0.45)
                      : withAlpha(AppColors.error, 0.45)
                  }`,
                  color: errorTone === 'pending' ? AppColors.blushGold : AppColors.petalWhite,
                  ...AppTypography.outfitWhite,
                  fontSize: 12.5,
                  lineHeight: 1.4,
                }}
              >
                {error}
              </div>
            )}

            <button
              type="submit"
              className="bare-button"
              disabled={busy || passwordsMismatch}
              style={{
                marginTop: 4,
                width: '100%',
                padding: '12px 16px',
                borderRadius: AppRadius.sm,
                background: linear([AppColors.deepRose, AppColors.rosePressed]),
                color: AppColors.petalWhite,
                ...AppTypography.outfitBold,
                fontSize: 14,
                opacity: busy || passwordsMismatch ? 0.6 : 1,
                boxShadow: boxShadow([{ offset: [0, 6], blur: 18, color: withAlpha(AppColors.deepRose, 0.35) }]),
              }}
            >
              {busy ? 'Please wait…' : mode === 'signin' ? 'Sign In' : 'Create Account'}
            </button>
          </form>
        </>
      )}
    </div>
  );
}
