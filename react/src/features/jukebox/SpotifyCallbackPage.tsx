// Port of lib/features/jukebox/presentation/pages/spotify_callback_page.dart.
import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { AppColors } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import { handleSpotifyCallback } from './jukeboxService';

export function SpotifyCallbackPage() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const code = params.get('code');
  const state = params.get('state');
  const error = params.get('error');
  const [status, setStatus] = useState('Connecting to Spotify...');
  const [finished, setFinished] = useState(false);

  useEffect(() => {
    let alive = true;
    let timer = 0;
    void (async () => {
      if (error != null) {
        setStatus(`Spotify auth failed: ${error}`);
        setFinished(true);
        return;
      }
      if (!code) {
        setStatus('No code returned');
        setFinished(true);
        return;
      }
      const ok = await handleSpotifyCallback(code, state);
      if (!alive) return;
      setStatus(ok ? 'Spotify linked! ✓' : 'Link failed — try again');
      setFinished(true);
      if (ok) timer = window.setTimeout(() => alive && navigate('/dashboard'), 900);
    })();
    return () => {
      alive = false;
      window.clearTimeout(timer);
    };
  }, [code, state, error, navigate]);

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: AppColors.inkDeep,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div style={{ padding: 32, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <Icon name="music_note" size={48} color={AppColors.blushGold} />
        <div style={{ height: 16 }} />
        <span style={{ ...AppTypography.outfitWhite, fontSize: 16, textAlign: 'center' }}>{status}</span>
        <div style={{ height: 24 }} />
        {!finished && (
          <div style={{ width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CircularProgress size={32} strokeWidth={4} color={AppColors.blushGold} />
          </div>
        )}
        {finished && (
          <button
            type="button"
            className="bare-button"
            onClick={() => navigate('/dashboard')}
            style={{
              ...AppTypography.labelLarge,
              padding: '18px 28px',
              background: AppColors.deepRose,
              color: AppColors.petalWhite,
              borderRadius: AppRadius.x2,
              boxShadow: '0 1px 2px rgba(0,0,0,0.3), 0 1px 3px 1px rgba(0,0,0,0.15)',
              lineHeight: '18px',
            }}
          >
            Back to Everglow
          </button>
        )}
      </div>
    </div>
  );
}
