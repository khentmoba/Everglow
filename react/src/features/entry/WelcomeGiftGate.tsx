import { lazy, Suspense, useEffect, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { AppColors } from '../../core/theme/colors';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { completeGift, giftRecipient, pendingGiftHtml } from './welcomeGiftService';

function GiftLoadFallback({
  onContentFinishedChanged,
}: {
  html: string;
  title: string;
  onContentFinishedChanged?: (finished: boolean) => void;
}) {
  useEffect(() => {
    onContentFinishedChanged?.(true);
  }, [onContentFinishedChanged]);
  return (
    <div style={{ padding: 24, textAlign: 'center', color: AppColors.roseDepths }}>
      Could not load your gift right now. You can continue to Everglow and check again later.
    </div>
  );
}

const CanvasHtmlView = lazy(() =>
  import('../ai/CanvasPreviewSheet')
    .then((m) => ({ default: m.CanvasHtmlView }))
    .catch(() => ({ default: GiftLoadFallback })),
);

/** Covers the app with Clair's gift until she taps Continue after its last page. */
export function WelcomeGiftGate() {
  const uid = giftRecipient(useAuth());
  const [gift, setGift] = useState<{ uid: string; html: string } | null>(null);
  const [finished, setFinished] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveFailed, setSaveFailed] = useState(false);

  useEffect(() => {
    setGift(null);
    setFinished(false);
    setSaveFailed(false);
    if (uid == null) return;
    let live = true;
    void pendingGiftHtml(uid).then((html) => {
      if (live && html != null) setGift({ uid, html });
    });
    return () => {
      live = false;
    };
  }, [uid]);

  if (gift == null || gift.uid !== uid) return null;

  const complete = async () => {
    if (!finished || saving) return;
    setSaving(true);
    setSaveFailed(false);
    try {
      await completeGift(gift.uid);
      setGift(null);
    } catch (e) {
      Logger.e('Could not save welcome gift receipt', e);
      setSaveFailed(true);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="A gift for you"
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 2000,
        display: 'flex',
        flexDirection: 'column',
        background: AppColors.petalWhite,
        paddingTop: 'env(safe-area-inset-top)',
      }}
    >
      <div style={{ flex: 1, minHeight: 0, position: 'relative', zIndex: 0, overflow: 'hidden' }}>
        <Suspense fallback={null}>
          <CanvasHtmlView html={gift.html} title="A gift for you" onContentFinishedChanged={setFinished} />
        </Suspense>
      </div>
      {finished && (
        <div
          style={{
            position: 'relative',
            zIndex: 1,
            background: AppColors.petalWhite,
            width: '100%',
            maxWidth: 480,
            margin: '0 auto',
            boxSizing: 'border-box',
            padding: '12px 20px calc(12px + env(safe-area-inset-bottom))',
            display: 'flex',
            flexDirection: 'column',
            gap: 10,
          }}
        >
          {saveFailed && (
            <div role="alert" style={{ color: AppColors.roseDepths, textAlign: 'center' }}>
              Couldn't save right now. Check your connection and try again.
            </div>
          )}
          <EverglowButton
            label={saving ? 'Saving...' : 'Continue to Everglow'}
            enabled={!saving}
            onPressed={() => void complete()}
            backgroundColor={AppColors.roseDepths}
            foregroundColor={AppColors.petalWhite}
            fullWidth
          />
        </div>
      )}
    </div>
  );
}
