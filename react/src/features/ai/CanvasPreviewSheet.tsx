// Port of lib/features/ai/presentation/widgets/canvas_preview_sheet.dart and canvas_html_view_web.dart.
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { authService } from '../../core/services/auth';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { showDialog, showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { motchiMinisService } from './motchiMinisService';

export type HtmlArtifact = { title: string; html: string };

/** A full-stage dialog on wide screens, a 92%-tall sheet on phones and tablets. */
export function openCanvasPreview(app: HtmlArtifact): Promise<unknown> {
  if (window.innerWidth >= 1024) {
    return showDialog((close) => (
      <div style={{ width: 'calc(100vw - 32px)', height: 'calc(100vh - 32px)', margin: '-8px -24px' }}>
        <PreviewChrome>
          <CanvasPreviewSheet app={app} expanded onClose={() => close(null)} />
        </PreviewChrome>
      </div>
    ));
  }
  return showModalBottomSheet((close) => (
    <div style={{ height: '92vh', display: 'flex', flexDirection: 'column' }}>
      <PreviewChrome>
        <CanvasPreviewSheet app={app} expanded onClose={() => close(null)} />
      </PreviewChrome>
    </div>
  ));
}

function PreviewChrome({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: AppColors.inkDeep,
        borderRadius: AppRadius.x2,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.22)}`,
        boxShadow: '0 -8px 64px rgba(0,0,0,0.5)',
        boxSizing: 'border-box',
        paddingBottom: 'env(safe-area-inset-bottom, 0px)',
      }}
    >
      {children}
    </div>
  );
}

export function CanvasPreviewSheet({ app, expanded, onClose }: { app: HtmlArtifact; expanded?: boolean; onClose: () => void }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: expanded ? 1 : undefined, minHeight: 0 }}>
      <div style={{ height: 10 }} />
      <div style={{ width: 40, height: 4, borderRadius: AppRadius.full, background: withAlpha(AppColors.moonlight, 0.25) }} />
      <div style={{ alignSelf: 'stretch', padding: '12px 12px 8px 20px', display: 'flex', alignItems: 'center' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              ...AppTypography.titleLarge,
              fontSize: 20,
              lineHeight: lineHeight(20),
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {app.title}
          </div>
          <div style={{ height: 2 }} />
          <div style={{ ...AppTypography.bodySmall, fontSize: 12, lineHeight: lineHeight(12), color: Derived.textMuted }}>
            Made by Motchi · runs safely in a sandbox
          </div>
        </div>
        <SaveMiniButton app={app} />
        <MaterialIconButton icon="close" tooltip="Back to chat" color={Derived.textMuted} onPressed={onClose} />
      </div>
      <div style={{ alignSelf: 'stretch', flex: 1, minHeight: 0, padding: '0 16px 20px' }}>
        <div
          style={{
            height: '100%',
            minHeight: 320,
            background: '#FFFFFF',
            borderRadius: AppRadius.lg,
            border: `1px solid ${Derived.border}`,
            overflow: 'hidden',
            boxSizing: 'border-box',
          }}
        >
          <CanvasHtmlView html={app.html} />
        </div>
      </div>
    </div>
  );
}

function SaveMiniButton({ app }: { app: HtmlArtifact }) {
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);
  const save = async () => {
    if (saved || busy) return;
    setBusy(true);
    let ok = false;
    try {
      ok = await motchiMinisService.saveMini({
        title: app.title,
        html: app.html,
        createdBy: authService.currentUser ?? 'motchi',
      });
    } catch {
      ok = false;
    }
    setBusy(false);
    setSaved(ok);
    showSnackBar(ok ? "Saved to Motchi's Minis 🍡" : 'Could not save — try again?', {
      background: ok ? AppColors.velvet : AppColors.deepRose,
      duration: 2000,
    });
  };
  const color = saved ? AppColors.blushGold : Derived.textMuted;
  return (
    <MaterialIconButton tooltip={saved ? 'Saved to Minis' : 'Save to Minis'} color={color} onPressed={() => void save()}>
      {busy ? (
        <CircularProgress size={18} strokeWidth={2} color={AppColors.deepRose} />
      ) : (
        <Icon name={saved ? 'bookmark' : 'bookmark_add_outlined'} color={color} />
      )}
    </MaterialIconButton>
  );
}

/** The sandboxed iframe Motchi's HTML runs in; reports `everglow:content-finished` / `-reading`. */
export function CanvasHtmlView({
  html,
  title = 'Motchi canvas preview',
  onContentFinishedChanged,
}: {
  html: string;
  title?: string;
  onContentFinishedChanged?: (finished: boolean) => void;
}) {
  const frame = useRef<HTMLIFrameElement>(null);
  const callback = useRef(onContentFinishedChanged);
  callback.current = onContentFinishedChanged;
  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      if (!frame.current || event.source !== frame.current.contentWindow) return;
      if (event.data === 'everglow:content-finished' || event.data === 'everglow:content-reading') {
        callback.current?.(event.data === 'everglow:content-finished');
      }
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, []);
  return (
    <iframe
      ref={frame}
      srcDoc={html}
      sandbox="allow-scripts"
      referrerPolicy="no-referrer"
      title={title}
      style={{ width: '100%', height: '100%', border: 0, display: 'block' }}
    />
  );
}
