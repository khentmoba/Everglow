// Port of table_tennis_game_screen_web.dart: the solo game in an iframe.
import { Logger } from '../../../core/system/logger';
import {
  findTTIframe,
  overlayTop,
  RotateBlock,
  TTGameFrame,
  useMobilePortraitBlocked,
  usePlayZoneBack,
  WebOverlayButton,
} from './TTFrame';

export function TableTennisPage() {
  const close = usePlayZoneBack();
  const blocked = useMobilePortraitBlocked();

  const restart = () => {
    try {
      findTTIframe()?.contentWindow?.location.reload();
    } catch (e) {
      Logger.w(`[TableTennisGameScreen] Failed to reload iframe: ${String(e)}`);
    }
  };

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000' }}>
      <TTGameFrame src="/table_tennis/assets/index.typed.html?v=1" />
      <div style={{ ...overlayTop, left: 12, right: 12, display: 'flex', justifyContent: 'space-between' }}>
        <WebOverlayButton icon="close" onTap={close} />
        <WebOverlayButton icon="replay" onTap={restart} tooltip="Restart match" />
      </div>
      {blocked && <RotateBlock onBack={close} />}
    </div>
  );
}
