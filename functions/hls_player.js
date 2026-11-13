'use strict';

// The ad-free HLS player page, shared by the Firebase functions (anime.js)
// and the Cloudflare streaming Worker (cloudflare/src/worker.js), so the two
// can never drift apart. Keep it dependency-free: the Worker bundles it.

function escHtml(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Ad-free HLS player with recovery. The video URL must already be playable
 *  from a browser (proxied through us when the upstream needs headers).
 *
 *  The first version attached hls.js and hoped for the best: any fatal
 *  stream error stalled on an endless spinner, and phones that block
 *  unmuted autoplay never started at all. This version starts playback once
 *  the manifest is ready, retries transient failures, and — after repeated
 *  fatal errors — shows a "try another server" card with a retry button
 *  instead of spinning forever. The card deliberately avoids the failover
 *  marker text, so the app's server probe never mistakes a healthy player
 *  page for a dead one. */
/** [kind] is 'anime' (default) or 'cinema'. Cinema has no sub/dub choice and
 *  no episode drawer of ours, so those controls are left out entirely. */
function hlsPlayerHtml({ src, title, tracks, token, ep, audio, kind, servers, current }) {
  const isCinema = kind === 'cinema';
  // The in-page server list. A resolver that has more than one upstream hands
  // us `{id, label, url}` per server; the player fetches one only when it is
  // picked, so a nine-server source costs nothing until she tries a second one.
  const serverList = (Array.isArray(servers) ? servers : [])
    .filter((s) => s && s.id && s.url)
    .map((s) => ({ id: String(s.id), label: String(s.label || s.id), url: String(s.url) }));
  const currentServer = serverList.some((s) => s.id === current) ? current : serverList[0]?.id || '';
  // When the page was loaded with a login token, hls.js sends it back as
  // an Authorization header — never inside media URLs (which land in
  // browser history and request logs). Native-HLS Safari keeps using the
  // token-bearing page URL, which only it needs.
  const trackTags = (Array.isArray(tracks) ? tracks : [])
    .filter((t) => t && t.file)
    .slice(0, 8)
    .map(
      (t, idx) =>
        '<track kind="captions" src="' + escHtml(t.file) + '"' +
        (t.label ? ' label="' + escHtml(t.label) + '"' : '') +
        (idx === 0 ? ' default' : '') +
        '>',
    )
    .join('\n    ');
  const epNum = Number.isSafeInteger(ep) && ep > 0 ? ep : null;
  const isDub = String(audio || 'sub').toLowerCase() === 'dub';
  const displayTitle = escHtml(title || (epNum ? 'Episode ' + epNum : 'Everglow'));
  return (
    '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<meta name="referrer" content="no-referrer">' +
    '<title>' + displayTitle + '</title>' +
    '<link rel="preconnect" href="https://fonts.googleapis.com">' +
    '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' +
    '<link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=DM+Sans:wght@500;600;700;800&display=swap" rel="stylesheet">' +
    '<style>' +
    '*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}' +
    'html,body{margin:0;height:100%;background:#08060e;overflow:hidden;' +
    'font-family:"DM Sans",-apple-system,BlinkMacSystemFont,sans-serif;color:#fff5f5;user-select:none}' +
    'video{width:100%;height:100%;background:#000;display:block}' +
    // Netflix-style subtitles: zero black background box, bold white text with crisp dark stroke + drop shadow
    'video::cue{background:transparent!important;background-color:transparent!important;' +
    'color:#fff;font-family:"DM Sans",sans-serif;font-weight:800;' +
    'text-shadow:-1.5px -1.5px 0 rgba(0,0,0,.94),1.5px -1.5px 0 rgba(0,0,0,.94),' +
    '-1.5px 1.5px 0 rgba(0,0,0,.94),1.5px 1.5px 0 rgba(0,0,0,.94),' +
    '0 2px 5px rgba(0,0,0,.95),0 4px 12px rgba(0,0,0,.8)}' +
    '#sub-box{position:fixed;left:50%;transform:translateX(-50%);bottom:calc(88px + var(--sub-lift,0px));width:88%;' +
    'text-align:center;z-index:4;pointer-events:none;transition:bottom .24s cubic-bezier(.22,1,.36,1)}' +
    'body.idle #sub-box{bottom:30px}' +
    // 2.4vw tracks the picture, not the window: 22px was the old ceiling and
    // it left the captions tiny on a fullscreen laptop or tablet. The cap only
    // stops an ultra-wide monitor from turning them into billboards.
    '#sub-txt{display:inline;background:transparent;color:#fff;' +
    'font-size:calc(clamp(15px,2.4vw,52px)*var(--sub-scale,1));' +
    'font-weight:800;line-height:1.35;letter-spacing:.01em;white-space:pre-line;' +
    'text-shadow:-1.5px -1.5px 0 rgba(0,0,0,.94),1.5px -1.5px 0 rgba(0,0,0,.94),' +
    '-1.5px 1.5px 0 rgba(0,0,0,.94),1.5px 1.5px 0 rgba(0,0,0,.94),' +
    '0 2px 5px rgba(0,0,0,.95),0 4px 12px rgba(0,0,0,.8)}' +
    '.ov{position:fixed;inset:0;display:flex;align-items:center;' +
    'justify-content:center;background:rgba(8,6,14,.74);backdrop-filter:blur(4px);z-index:8}' +
    // The `hidden` attribute alone cannot hide these overlays: author-origin
    // `.ov{display:flex}` beats the UA stylesheet's `[hidden]{display:none}`,
    // so without this rule the tap-to-play button AND the "stalled" card
    // paint over the video from the first frame on every episode.
    '.ov[hidden]{display:none!important}[hidden]{display:none!important}' +
    // Wave-animated EVERGLOW loading text (text only, no spinner box)
    '.eg-wave{display:inline-flex;font-family:"Bebas Neue",Impact,sans-serif;' +
    'font-size:clamp(34px,6vw,50px);letter-spacing:.1em;line-height:1}' +
    '.wc{display:inline-block;animation:egw 1.3s ease-in-out infinite}' +
    '.wc.e{color:#f8f8f8;text-shadow:0 4px 16px rgba(0,0,0,.75)}' +
    '.wc.g{color:#c2185b;text-shadow:0 4px 20px rgba(194,24,91,.75)}' +
    '.wc:nth-child(1){animation-delay:0s}.wc:nth-child(2){animation-delay:.09s}' +
    '.wc:nth-child(3){animation-delay:.18s}.wc:nth-child(4){animation-delay:.27s}' +
    '.wc:nth-child(5){animation-delay:.36s}.wc:nth-child(6){animation-delay:.45s}' +
    '.wc:nth-child(7){animation-delay:.54s}.wc:nth-child(8){animation-delay:.63s}' +
    '@keyframes egw{0%,100%{transform:translateY(0);opacity:.72}' +
    '45%{transform:translateY(-9px);opacity:1}}' +
    '#tap{cursor:pointer;border:0;border-radius:999px;padding:13px 26px;' +
    'font-size:15px;font-weight:700;color:#fff5f5;background:#c2185b;' +
    'box-shadow:0 8px 24px rgba(194,24,91,.5)}' +
    '#dead{flex-direction:column;text-align:center;color:#f8f8f8;padding:0 28px}' +
    '#dead button{margin-top:14px;cursor:pointer;border:1px solid #c2185b;' +
    'border-radius:999px;padding:10px 24px;font-size:14px;color:#fff5f5;background:transparent}' +
    // Sakura Broadcast HUD
    '#hud{position:fixed;inset:0;display:flex;flex-direction:column;justify-content:space-between;' +
    'background:linear-gradient(180deg,rgba(10,8,16,.78) 0%,transparent 22%,transparent 62%,rgba(10,8,16,.94) 100%);' +
    'z-index:5;transition:opacity .26s cubic-bezier(.22,1,.36,1);pointer-events:none}' +
    // The gradient sheet covers the whole frame. Without this every tap on
    // the picture lands on the HUD instead of the video, so click-to-pause
    // looks dead. Only the two control bands take pointers back.
    '.h-top,.h-bot{pointer-events:auto}' +
    'body.idle #hud{opacity:0;pointer-events:none}' +
    'body.idle .h-top,body.idle .h-bot{pointer-events:none}' +
    'body.idle{cursor:none}' +
    '.h-top{padding:14px 20px;display:flex;justify-content:space-between;align-items:center;gap:12px}' +
    '#hud-title{font-size:15px;font-weight:800;letter-spacing:.02em;color:#fff5f5;' +
    'white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
    '.h-top-r{display:flex;align-items:center;gap:8px;flex-shrink:0}' +
    '.sd-box{display:flex;background:rgba(240,230,255,.08);border-radius:6px;padding:2px;' +
    'border:1px solid rgba(240,230,255,.14)}' +
    '.sd-b{border:0;background:transparent;padding:3px 8px;font-size:10.5px;font-weight:800;' +
    'border-radius:4px;color:#d5adb9;cursor:pointer;font-family:inherit}' +
    '.sd-b.on{background:#c2185b;color:#fff5f5}' +
    '.h-bot{padding:0 20px 14px;display:flex;flex-direction:column;gap:9px}' +
    // Skip/Next sit outside the HUD on purpose: reaching the opening or the
    // ending is exactly when nobody is touching the mouse, so the action has
    // to survive the controls fading out.
    '#binge{position:fixed;left:0;right:0;bottom:104px;padding:0 20px;z-index:7;' +
    'display:flex;justify-content:flex-end;align-items:center;min-height:34px;' +
    'pointer-events:none}' +
    '#binge .b-act{pointer-events:auto}' +
    // A soft scrim keeps the words readable over a bright frame. It is a
    // legibility wash, not a card: no edge, no border, no fill of its own.
    '.b-scrim{position:absolute;right:-20px;bottom:-14px;width:340px;height:120px;' +
    'pointer-events:none;background:radial-gradient(ellipse at 78% 62%,' +
    'rgba(8,5,14,.82) 0%,rgba(8,5,14,.5) 45%,transparent 72%)}' +
    '#b-scrim[hidden]{display:none!important}' +
    '.b-act{position:relative;display:inline-flex;align-items:center;gap:8px;' +
    'padding:6px 2px 9px;border:0;background:transparent;font-family:inherit;' +
    'font-size:14px;font-weight:800;letter-spacing:.01em;color:#fff5f5;cursor:pointer;' +
    'text-shadow:0 2px 6px rgba(0,0,0,.9),0 4px 16px rgba(0,0,0,.7);' +
    'transition:color .15s ease}' +
    '.b-act:hover{color:#fff}' +
    '.b-ico{display:inline-flex}' +
    '.b-skip .b-ico{color:#f5c97b}' +
    '.b-next .b-ico{color:#ff8caf}' +
    '.b-t{color:#f5c97b;font-variant-numeric:tabular-nums;font-weight:800}' +
    '.b-next .b-t{color:rgba(255,245,245,.72)}' +
    // The underline drains with the stretch it belongs to, so the word and
    // the time left are the same reading.
    '.b-u{position:absolute;left:2px;right:2px;bottom:3px;height:2px;border-radius:2px;' +
    'overflow:hidden;background:rgba(255,255,255,.14)}' +
    '.b-u i{display:block;height:100%;width:100%;transition:width .2s linear}' +
    '.b-skip .b-u i{background:#f5c97b}' +
    '.b-next .b-u i{background:#c2185b}' +
    '#scrub{position:relative;height:6px;border-radius:4px;background:rgba(240,230,255,.22);' +
    'cursor:pointer;outline:none}' +
    // A 6px bar is impossible to grab on a phone. This invisible band
    // widens the hit area without touching the painted bar.
    '#scrub::before{content:"";position:absolute;left:0;right:0;top:-7px;bottom:-7px}' +
    '#scrub:focus-visible{box-shadow:0 0 0 3px rgba(194,24,91,.55)}' +
    '#s-buf{position:absolute;left:0;top:0;bottom:0;width:0%;background:rgba(240,230,255,.32);border-radius:4px}' +
    '#s-fill{position:absolute;left:0;top:0;bottom:0;width:0%;background:#c2185b;z-index:2;border-radius:4px}' +
    '.s-chap{position:absolute;top:0;bottom:0;background:rgba(245,201,123,.55);' +
    'border-left:1px solid #f5c97b;border-right:1px solid #f5c97b;z-index:3;pointer-events:none}' +
    '.ctrl-r{display:flex;align-items:center;justify-content:space-between;gap:10px;font-size:12px;color:#f1cbd2}' +
    '.ctrl-l,.ctrl-rt{display:flex;align-items:center;gap:12px}' +
    '.ib{border:0;background:transparent;color:#fff5f5;display:inline-flex;align-items:center;' +
    'justify-content:center;cursor:pointer;padding:2px;opacity:.92}' +
    '.ib:hover{opacity:1;color:#c2185b}' +
    '.ib.rose{color:#c2185b}' +
    '#vol-wrap{display:flex;align-items:center;gap:7px}' +
    '#vol-range{width:72px;height:16px;margin:0;padding:0;accent-color:#c2185b;' +
    'background:transparent;cursor:pointer}' +
    // Hardware volume buttons are the right control on a phone; a slider
    // there is a row of pixels nobody can hit.
    '@media (hover:none),(pointer:coarse){#vol-range{display:none}}' +
    '#btn-speed{min-width:36px}' +
    '#buf{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;' +
    'z-index:6;pointer-events:none}' +
    '.buf-ring{width:38px;height:38px;border-radius:50%;' +
    'border:3px solid rgba(255,245,245,.18);border-top-color:#c2185b;' +
    'animation:egspin .85s linear infinite}' +
    '@keyframes egspin{to{transform:rotate(360deg)}}' +
    '#time-lbl{font-variant-numeric:tabular-nums;font-weight:600;color:#fff5f5;font-size:12px}' +
    '.chip{border:1px solid rgba(240,230,255,.16);background:rgba(240,230,255,.09);color:#fff5f5;' +
    'border-radius:6px;padding:4px 9px;font-size:11px;font-weight:700;cursor:pointer;' +
    'font-family:inherit;font-variant-numeric:tabular-nums}' +
    '.chip.on{border-color:#c2185b;background:rgba(194,24,91,.28)}' +
    '.eg-badge{display:inline-flex;align-items:center;gap:7px;padding:3px 9px 3px 4px;' +
    'border-radius:999px;background:rgba(17,17,24,.82);border:1px solid rgba(255,255,255,.15);' +
    'box-shadow:0 6px 16px rgba(0,0,0,.45)}' +
    '.eg-cat{width:20px;height:20px;border-radius:50%;object-fit:cover;' +
    'border:1.5px solid rgba(244,194,194,.7)}' +
    '.eg-w{font-family:"Bebas Neue",Impact,sans-serif;font-size:16px;letter-spacing:.06em;line-height:1}' +
    '.eg-w b{color:#f8f8f8;font-weight:400}' +
    '.eg-w i{color:#c2185b;font-style:normal;text-shadow:0 2px 10px rgba(194,24,91,.65)}' +
    '#q-menu,#cc-menu,#sp-menu,#sv-menu{position:fixed;right:20px;bottom:58px;width:164px;background:rgba(18,13,26,.95);' +
    'backdrop-filter:blur(18px);border:1px solid rgba(240,230,255,.18);border-radius:10px;' +
    'padding:6px;z-index:12;box-shadow:0 14px 32px rgba(0,0,0,.65)}' +
    '.qi{display:flex;justify-content:space-between;align-items:center;width:100%;border:0;' +
    'background:transparent;color:#f1cbd2;padding:6px 8px;border-radius:6px;font-size:11.5px;' +
    'font-weight:600;cursor:pointer;font-family:inherit;text-align:left}' +
    '.qi.on{background:rgba(194,24,91,.28);color:#fff5f5}' +
    '#cc-menu{width:238px;max-height:56vh;overflow-y:auto}' +
    // Nine servers is 257px tall, and the in-app phone player is a 16:9 box
    // only 192px high: uncapped, the menu's top lands above the frame and the
    // first rows — including the current server — are clipped and untappable.
    '#sv-menu{max-height:calc(100vh - 76px);overflow-y:auto}' +
    '.cc-h{font-size:9.5px;font-weight:800;letter-spacing:.09em;text-transform:uppercase;' +
    'color:#b795a2;padding:8px 8px 3px}' +
    '.cc-row{display:flex;gap:4px;align-items:center;padding:0 4px 4px}' +
    '.cc-row .qi{flex:1;justify-content:center;padding:5px 4px;text-align:center}' +
    '.chip[hidden]{display:none}' +
    // Phones keep the Everglow badge (Clair watches here) and volume button;
    // the volume slider, speed chip, and PiP button give up their room so
    // fullscreen is never clipped off the right edge.
    '@media (max-width:520px){.h-top{padding:10px 14px}.h-bot{padding:0 14px 10px}' +
    '.ctrl-l,.ctrl-rt{gap:6px}.ctrl-r{gap:6px}#vol-range{display:none}#btn-speed{display:none}#btn-pip{display:none}' +
    '#time-lbl{white-space:nowrap;font-size:11px}#binge{padding:0 14px;bottom:96px}' +
    '.eg-w{display:none}.eg-badge{padding:2px;border-radius:50%}.eg-cat{width:17px;height:17px}' +
    '.chip{padding:3px 7px;font-size:10.5px}#hud-title{font-size:13px}}' +
    '</style></head><body>' +
    '<video id="v" playsinline autoplay preload="auto" crossorigin="anonymous">' +
    (trackTags ? '\n    ' + trackTags : '') +
    '</video>\n' +
    '<div id="sub-box"><span id="sub-txt"></span></div>\n' +
    '<div id="hud">' +
    '<div class="h-top">' +
    '<span id="hud-title">' + displayTitle + '</span>' +
    '<div class="h-top-r">' +
    '<button type="button" class="chip" id="btn-sv" aria-haspopup="true"' +
    (serverList.length > 1 ? '' : ' hidden') + '>Servers</button>' +
    (isCinema
      ? ''
      : '<div class="sd-box">' +
        '<button type="button" class="sd-b' + (isDub ? '' : ' on') + '" id="btn-sub">SUB</button>' +
        '<button type="button" class="sd-b' + (isDub ? ' on' : '') + '" id="btn-dub">DUB</button>' +
        '</div>' +
        '<button type="button" class="chip" id="btn-eps">Episodes</button>') +
    '</div></div>' +
    '<div class="h-bot">' +
    '<div id="scrub">' +
    '<div id="s-buf"></div>' +
    '<div id="s-fill"></div>' +
    '<div class="s-chap" id="s-op" hidden></div>' +
    '<div class="s-chap" id="s-ed" hidden></div>' +
    '</div>' +
    '<div class="ctrl-r">' +
    '<div class="ctrl-l">' +
    '<button type="button" class="ib rose" id="btn-play" aria-label="Play or pause">' +
    '<svg width="17" height="17" viewBox="0 0 20 20"><path id="play-p" fill="currentColor" d="M4 3h3.5v14H4zM12.5 3H16v14h-3.5z"/></svg></button>' +
    '<button type="button" class="ib" id="btn-rew" aria-label="Rewind 10 seconds">' +
    '<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 9a7 7 0 1 0 2-4.9"/><polyline points="3.5 2 3.5 5.5 7 5.5"/></svg></button>' +
    '<button type="button" class="ib" id="btn-ff" aria-label="Forward 10 seconds">' +
    '<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M16.5 9a7 7 0 1 1-2-4.9"/><polyline points="16.5 2 16.5 5.5 13 5.5"/></svg></button>' +
    '<span id="vol-wrap">' +
    '<button type="button" class="ib" id="btn-vol" aria-label="Mute or unmute">' +
    '<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><polygon points="9 4 5 7.5 2 7.5 2 12.5 5 12.5 9 16 9 4" fill="currentColor"/><path id="vol-w" d="M12.5 7a4 4 0 0 1 0 6M15 4.8a7.2 7.2 0 0 1 0 10.4"/></svg></button>' +
    '<input type="range" id="vol-range" min="0" max="1" step="0.01" value="1" aria-label="Volume">' +
    '</span>' +
    '<span id="time-lbl">00:00 / 00:00</span>' +
    '</div>' +
    '<div class="ctrl-rt">' +
    '<div class="eg-badge">' +
    '<img class="eg-cat" src="https://everglow-1c6db.web.app/favicon.png" alt="">' +
    '<span class="eg-w"><b>EVER</b><i>GLOW</i></span>' +
    '</div>' +
    '<button type="button" class="chip on" id="btn-cc" aria-haspopup="true"' +
    (trackTags ? '' : ' hidden') + '>CC</button>' +
    '<button type="button" class="chip" id="btn-speed" aria-haspopup="true">1x</button>' +
    '<button type="button" class="chip" id="btn-q">Auto</button>' +
    '<button type="button" class="ib" id="btn-pip" aria-label="Picture in picture">' +
    '<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="4" width="15" height="12" rx="2"/><rect x="10.2" y="9.4" width="6" height="4.8" rx="1" fill="currentColor" stroke="none"/></svg></button>' +
    '<button type="button" class="ib" id="btn-fs" aria-label="Fullscreen">' +
    '<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7V3h4M17 7V3h-4M3 13v4h4M17 13v4h-4"/></svg></button>' +
    '</div></div></div></div>\n' +
    '<div id="binge">' +
    '<div class="b-scrim" id="b-scrim" hidden></div>' +
    '<button type="button" class="b-act b-skip" id="btn-skip" hidden>' +
    '<span class="b-ico"><svg width="15" height="15" viewBox="0 0 20 20" fill="none" ' +
    'stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">' +
    '<polygon points="4 4.5 11.5 10 4 15.5 4 4.5" fill="currentColor" stroke="none"/>' +
    '<line x1="15.5" y1="4.5" x2="15.5" y2="15.5"/></svg></span>' +
    '<span id="skip-lbl">Skip opening</span>' +
    '<span class="b-t" id="skip-time"></span>' +
    '<span class="b-u"><i id="skip-fill"></i></span>' +
    '</button>' +
    '<button type="button" class="b-act b-next" id="btn-next" hidden>' +
    '<span class="b-ico"><svg width="15" height="15" viewBox="0 0 20 20" fill="none" ' +
    'stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">' +
    '<polygon points="5 4.5 13 10 5 15.5 5 4.5" fill="currentColor" stroke="none"/></svg></span>' +
    '<span id="next-lbl">Next episode</span>' +
    '<span class="b-t" id="next-tok"></span>' +
    '<span class="b-u"><i id="next-fill"></i></span>' +
    '</button>' +
    '</div>\n' +
    '<div id="q-menu" hidden></div>\n' +
    '<div id="cc-menu" hidden></div>\n' +
    '<div id="sp-menu" hidden></div>\n' +
    '<div id="sv-menu" hidden></div>\n' +
    '<div id="buf" hidden><div class="buf-ring"></div></div>\n' +
    '<div class="ov" id="boot"><div class="eg-wave" aria-label="Everglow loading">' +
    '<span class="wc e">E</span><span class="wc e">V</span><span class="wc e">E</span><span class="wc e">R</span>' +
    '<span class="wc g">G</span><span class="wc g">L</span><span class="wc g">O</span><span class="wc g">W</span>' +
    '</div></div>\n' +
    '<div class="ov" id="tapw" hidden>' +
    '<button id="tap">&#9654; Tap to play</button></div>\n' +
    '<div class="ov" id="dead" hidden>' +
    '<p style="font-size:15px;margin:0 0 6px">This stream stalled.</p>' +
    '<p style="font-size:12px;color:#d5adb9;margin:0">' +
    'Try another server below — or retry here.</p>' +
    '<button onclick="location.reload()">Retry</button></div>\n' +
    '<script src="https://cdn.jsdelivr.net/npm/hls.js@1"></script>\n' +
    '<script>(function(){var src=' + JSON.stringify(src) + ';var v=' +
    'document.getElementById("v");' +
    'var servers=' + JSON.stringify(serverList) + ';' +
    'var currentServer=' + JSON.stringify(currentServer) + ';' +
    'var btnSv=document.getElementById("btn-sv");' +
    'var svMenu=document.getElementById("sv-menu");' +
    'var boot=document.getElementById("boot");' +
    'var tapw=document.getElementById("tapw");' +
    'var tap=document.getElementById("tap");' +
    'var dead=document.getElementById("dead");' +
    'var hudTitle=document.getElementById("hud-title");' +
    'var sFill=document.getElementById("s-fill");' +
    'var sBuf=document.getElementById("s-buf");' +
    'var sOp=document.getElementById("s-op");' +
    'var sEd=document.getElementById("s-ed");' +
    'var scrub=document.getElementById("scrub");' +
    'var timeLbl=document.getElementById("time-lbl");' +
    'var btnPlay=document.getElementById("btn-play");' +
    'var playP=document.getElementById("play-p");' +
    'var btnRew=document.getElementById("btn-rew");' +
    'var btnFf=document.getElementById("btn-ff");' +
    'var btnVol=document.getElementById("btn-vol");' +
    'var btnCc=document.getElementById("btn-cc");' +
    'var ccMenu=document.getElementById("cc-menu");' +
    'var btnSpeed=document.getElementById("btn-speed");' +
    'var spMenu=document.getElementById("sp-menu");' +
    'var btnPip=document.getElementById("btn-pip");' +
    'var volRange=document.getElementById("vol-range");' +
    'var buf=document.getElementById("buf");' +
    'var btnQ=document.getElementById("btn-q");' +
    'var qMenu=document.getElementById("q-menu");' +
    'var btnFs=document.getElementById("btn-fs");' +
    'var btnSkip=document.getElementById("btn-skip");' +
    'var btnNext=document.getElementById("btn-next");' +
    'var btnSub=document.getElementById("btn-sub");' +
    'var btnDub=document.getElementById("btn-dub");' +
    'var btnEps=document.getElementById("btn-eps");' +
    'var subTxt=document.getElementById("sub-txt");' +
    'var subBox=document.getElementById("sub-box");' +
    'var skipTime=document.getElementById("skip-time");' +
    'var skipFill=document.getElementById("skip-fill");' +
    'var nextLbl=document.getElementById("next-lbl");' +
    'var nextTok=document.getElementById("next-tok");' +
    'var nextFill=document.getElementById("next-fill");' +
    'var episode=' + JSON.stringify(epNum) + ';' +
    'var opRange=null,edRange=null,activeSkipEnd=null,hlsInst=null,hlsDead=false,makeHls=null,picking=false;' +
    // Player habits that must survive an episode change: captions on/off,
    // the picked track, the subtitle delay she tuned, text size, volume.
    'var prefs={cc:true,lang:0,delay:0,size:1,vol:1,muted:false,speed:1};' +
    'var ccOn=true,subPick=0;' +
    'function loadPrefs(){try{' +
    'var raw=window.localStorage&&window.localStorage.getItem("everglow.player.prefs");' +
    'if(!raw)return;var o=JSON.parse(raw);if(!o||typeof o!=="object")return;' +
    'if(typeof o.cc==="boolean")prefs.cc=o.cc;' +
    'if(typeof o.lang==="number"&&o.lang>=0)prefs.lang=Math.floor(o.lang);' +
    'if(typeof o.delay==="number"&&isFinite(o.delay))prefs.delay=Math.max(-10,Math.min(10,o.delay));' +
    'if(typeof o.size==="number")prefs.size=Math.max(0,Math.min(2,Math.floor(o.size)));' +
    'if(typeof o.vol==="number"&&isFinite(o.vol))prefs.vol=Math.max(0,Math.min(1,o.vol));' +
    'if(typeof o.muted==="boolean")prefs.muted=o.muted;' +
    'if(typeof o.speed==="number"&&isFinite(o.speed)&&o.speed>=0.25&&o.speed<=2)prefs.speed=o.speed;}catch(e){}}' +
    'function savePrefs(){try{if(window.localStorage){' +
    'window.localStorage.setItem("everglow.player.prefs",JSON.stringify(prefs));}}catch(e){}}' +
    'function applySubSize(){if(!subTxt||!subTxt.style)return;' +
    'var s=[0.84,1,1.3][prefs.size]||1;' +
    'if(subTxt.style.setProperty){subTxt.style.setProperty("--sub-scale",String(s));}' +
    'else{subTxt.style.fontSize=(16*s)+"px";}}' +
    'function applyVolume(){try{v.volume=prefs.vol;v.muted=prefs.muted;}catch(e){}' +
    'if(volRange)volRange.value=String(prefs.vol);' +
    'if(btnVol)btnVol.style.opacity=prefs.muted?"0.45":"0.92";}' +
    'var SPEEDS=[0.25,0.5,0.75,1,1.25,1.5,1.75,2];' +
    'function speedLabel(s){return(s===1?"1":String(s))+"x";}' +
    'function applySpeed(){try{v.playbackRate=prefs.speed;}catch(e){}' +
    'if(btnSpeed){btnSpeed.textContent=speedLabel(prefs.speed);' +
    'btnSpeed.classList.toggle("on",prefs.speed!==1);}}' +
    'function setSpeed(s){if(!isFinite(s))return;prefs.speed=s;savePrefs();' +
    'applySpeed();buildSpeedMenu();}' +
    'function buildSpeedMenu(){if(!spMenu)return;spMenu.innerHTML="";' +
    'for(var i=0;i<SPEEDS.length;i++){(function(r){' +
    'spMenu.appendChild(ccBtn(speedLabel(r),r===prefs.speed,function(){setSpeed(r);}));})(SPEEDS[i]);}}' +
    'loadPrefs();ccOn=prefs.cc;subPick=prefs.lang;' +
    'if(btnCc)btnCc.classList.toggle("on",ccOn);' +
    'applySubSize();applyVolume();applySpeed();placeSubs();' +
    // How close to the last frame the Next button appears when the ending
    // was never marked. 90s covers a typical ED plus the preview card.
    'var nextToken=null,nextKind="episode",NEAR_END_SECONDS=90;' +
    'function fmt(s){if(!Number.isFinite(s)||s<0)return"00:00";' +
    'var m=Math.floor(s/60),sec=Math.floor(s%60);' +
    'return(m<10?"0":"")+m+":"+(sec<10?"0":"")+sec;}' +
    'var start=new URLSearchParams(window.location.search).get("start");' +
    'var pendingSeek=start!==null&&/^\\d+(?:\\.\\d+)?$/.test(start)?Number(start):null;' +
    'if(!Number.isFinite(pendingSeek)){pendingSeek=null;}' +
    'var hasMetadata=false;' +
    'function updateChapters(){var d=v.duration;if(!Number.isFinite(d)||d<=0)return;' +
    'if(sOp){if(opRange&&opRange[1]>opRange[0]&&opRange[0]<d){' +
    'sOp.style.left=Math.max(0,opRange[0]/d*100)+"%";' +
    'sOp.style.width=Math.min(100-opRange[0]/d*100,(opRange[1]-opRange[0])/d*100)+"%";' +
    'sOp.hidden=false;}else{sOp.hidden=true;}}' +
    'if(sEd){if(edRange&&edRange[1]>edRange[0]&&edRange[0]<d){' +
    'sEd.style.left=Math.max(0,edRange[0]/d*100)+"%";' +
    'sEd.style.width=Math.min(100-edRange[0]/d*100,(edRange[1]-edRange[0])/d*100)+"%";' +
    'sEd.hidden=false;}else{sEd.hidden=true;}}}' +
    // How far through a stretch the playhead is, 0..1. Null when the
    // stretch is missing or has no length.
    'function through(range,t){if(!range)return null;var span=range[1]-range[0];' +
    'if(!(span>0))return null;var p=(t-range[0])/span;' +
    'return Math.min(1,Math.max(0,p));}' +
    // The Skip action belongs to the opening only. The ending is where the
    // Next action lives, so a second skip there would be noise.
    'function updateBingeScrim(){var sc=document.getElementById("b-scrim");if(sc){' +
    'sc.hidden=(!btnSkip||btnSkip.hidden)&&(!btnNext||btnNext.hidden);}}' +
    'function updateSkipBtn(){if(!btnSkip)return;var t=v.currentTime;' +
    'if(opRange&&t>=opRange[0]&&t<opRange[1]){activeSkipEnd=opRange[1];' +
    'if(skipTime)skipTime.textContent=fmt(Math.max(0,opRange[1]-t));' +
    'var p=through(opRange,t);if(skipFill&&p!==null)skipFill.style.width=((1-p)*100)+"%";' +
    'btnSkip.hidden=false;updateBingeScrim();return;}' +
    'activeSkipEnd=null;btnSkip.hidden=true;updateBingeScrim();}' +
    // Next shows during the ending, or within the last 90s when nobody
    // marked one. No token means nothing follows, so it stays hidden.
    'function updateNextBtn(){if(!btnNext)return;' +
    'if(!nextToken&&nextKind!=="season"){btnNext.hidden=true;updateBingeScrim();return;}' +
    'var t=v.currentTime,d=v.duration;' +
    'if(!Number.isFinite(t)||!Number.isFinite(d)||d<=0){btnNext.hidden=true;updateBingeScrim();return;}' +
    'var inEnding=!!edRange&&t>=edRange[0]&&t<edRange[1];' +
    'var nearEnd=(d-t)<=NEAR_END_SECONDS;' +
    'if(!(inEnding||nearEnd)){btnNext.hidden=true;updateBingeScrim();return;}' +
    'if(nextLbl)nextLbl.textContent=nextKind==="season"?"Next season":"Next episode";' +
    'if(nextTok)nextTok.textContent=nextToken||"";' +
    'var p=inEnding?through(edRange,t):null;' +
    'if(p===null)p=1-Math.min(1,Math.max(0,(d-t)/NEAR_END_SECONDS));' +
    'if(nextFill)nextFill.style.width=((1-p)*100)+"%";' +
    'btnNext.hidden=false;updateBingeScrim();}' +
    'function updateUi(){var p=v.currentTime,d=v.duration;' +
    'if(Number.isFinite(p)&&Number.isFinite(d)&&d>0){' +
    'if(sFill&&!dragging)sFill.style.width=Math.min(100,Math.max(0,p/d*100))+"%";' +
    'if(timeLbl&&!dragging)timeLbl.textContent=fmt(p)+" / "+fmt(d);' +
    'if(scrub){scrub.setAttribute("aria-valuenow",String(Math.round(p)));' +
    'scrub.setAttribute("aria-valuemin","0");' +
    'scrub.setAttribute("aria-valuemax",String(Math.round(d)));}}' +
    'renderCues();updateSkipBtn();updateNextBtn();}' +
    'function applySeek(){if(!hasMetadata||pendingSeek===null||!Number.isFinite(v.duration)||v.duration<=0){return;}' +
    'try{v.currentTime=Math.min(pendingSeek,v.duration);pendingSeek=null;updateUi();}catch(e){}}' +
    'v.addEventListener("loadedmetadata",function(){hasMetadata=true;applySeek();updateChapters();updateUi();buildSpeedMenu();applySpeed();});' +
    'v.addEventListener("durationchange",function(){applySeek();updateChapters();updateUi();});' +
    'function trustedParent(origin){return origin==="https://everglow-1c6db.web.app"||' +
    'origin==="https://everglow-1c6db.firebaseapp.com"||' +
    '/^https:\\/\\/everglow-1c6db--[a-z0-9-]+\\.web\\.app$/.test(origin)||' +
    '/^https?:\\/\\/(?:localhost|127\\.0\\.0\\.1|\\[::1\\])(?::[0-9]+)?$/.test(origin);}' +
    'function nativeBridge(){return window.parent===window&&window.EverglowPlayer&&' +
    'window.location.origin.indexOf("https://")===0&&' +
    'window.location.pathname==="/proxyAnime";}' +
    'window.addEventListener("message",function(e){' +
    'if(e.source!==window.parent||(!trustedParent(e.origin)&&' +
    '!(nativeBridge()&&e.origin===window.location.origin))){return;}' +
    'var d=e.data;if(!d||typeof d!=="object"){return;}' +
    'if(d.type==="animex-seek"&&typeof d.seconds==="number"&&Number.isFinite(d.seconds)&&d.seconds>=0){' +
    'pendingSeek=d.seconds;applySeek();return;}' +
    // The app relays keys here when its own document has focus (she clicked
    // below the video), so the arrows work without clicking the frame first.
    'if(d.type==="everglow-key"){handleKey(d.key);return;}' +
    'if(d.type==="animex-player-state"||d.type==="animex-skip-times"){' +
    'opRange=Array.isArray(d.op)&&d.op.length===2&&Number.isFinite(d.op[0])&&Number.isFinite(d.op[1])?d.op:null;' +
    'edRange=Array.isArray(d.ed)&&d.ed.length===2&&Number.isFinite(d.ed[0])&&Number.isFinite(d.ed[1])?d.ed:null;' +
    'nextToken=typeof d.next==="string"&&d.next?d.next:null;' +
    'nextKind=d.nextKind==="season"?"season":"episode";' +
    'if(d.title&&hudTitle){hudTitle.textContent=String(d.title);}' +
    'updateChapters();updateUi();}});' +
    'function post(data){try{window.parent.postMessage(data,"*");}catch(e){}' +
    'try{if(nativeBridge()){window.EverglowPlayer.postMessage(' +
    'typeof data==="string"?data:JSON.stringify(data));}}catch(e){}}' +
    'var lastProgress=null;' +
    'function progress(force){var position=v.currentTime,duration=v.duration;' +
    'if(!Number.isFinite(position)||position<0||!Number.isFinite(duration)||' +
    'duration<=0||position>duration){return;}' +
    'var now=Date.now();if(!force&&lastProgress!==null&&now-lastProgress<1000){return;}' +
    'lastProgress=now;post({type:"animex-progress",position:position,duration:duration,episode:episode});}' +
    'v.addEventListener("timeupdate",function(){updateUi();progress(false);});' +
    'v.addEventListener("pause",function(){if(playP)playP.setAttribute("d","M5 3.5l12 6.5-12 6.5V3.5z");' +
    'if(buf)buf.hidden=true;progress(true);});' +
    'v.addEventListener("ended",function(){progress(true);});' +
    'function hideBoot(){boot.style.display="none";}' +
    'function showTap(){tapw.hidden=false;}' +
    'function tryPlay(){var p;try{p=v.play();}catch(e){showTap();return;}' +
    'if(p&&p.catch){p.catch(function(err){' +
    'if(err&&(err.name==="AbortError"||err.code===20))return;showTap();});}}' +
    // After a pick, a dead stream is one server's problem, not the source's:
    // posting here moves her off Yume entirely and overwrites the remembered
    // server. Reopen the picker instead — its rows sit above this overlay
    // (z-index 12 vs 8), so she can actually choose another one.
    'function giveUp(){hideBoot();tapw.hidden=true;dead.hidden=false;' +
    'if(pickSeq>0){if(svMenu){buildSvMenu();svMenu.hidden=false;}' +
    // The picker covers the right side of the card, including most of Retry.
    // Shift the card's content clear so both controls stay usable.
    'dead.style.paddingRight="190px";return;}' +
    'post("animex-content-error");}' +
    'tap.addEventListener("click",function(){tapw.hidden=true;tryPlay();});' +
    'var started=false;' +
    'v.addEventListener("playing",function(){started=true;hideBoot();tapw.hidden=true;' +
    'if(buf)buf.hidden=true;' +
    // The stalled card comes down only once a source actually plays, so a
    // pick that cannot start never leaves her looking at a blank frame.
    'if(dead){dead.hidden=true;dead.style.paddingRight="";}' +
    // Only a play that answers a pick closes the picker. `playing` also fires
    // when a stalled buffer resumes, and shutting the menu she opened by hand
    // mid-choice is the one thing the picker exists to prevent.
    'if(picking){picking=false;if(svMenu)svMenu.hidden=true;}' +
    'if(playP)playP.setAttribute("d","M4 3h3.5v14H4zM12.5 3H16v14h-3.5z");});' +
    'v.addEventListener("canplay",function(){if(buf)buf.hidden=true;});' +
    // Before the first frame the boot wave is the right thing to show. After
    // it, a stall is a hiccup, not a boot — a small ring, not the wordmark.
    'v.addEventListener("waiting",function(){' +
    'if(!started){if(dead.hidden)boot.style.display="flex";return;}' +
    'if(buf)buf.hidden=false;});' +
    'if(btnPlay)btnPlay.addEventListener("click",function(){if(v.paused)tryPlay();else v.pause();});' +
    'if(btnRew)btnRew.addEventListener("click",function(){if(Number.isFinite(v.currentTime))v.currentTime=Math.max(0,v.currentTime-10);updateUi();});' +
    'if(btnFf)btnFf.addEventListener("click",function(){if(Number.isFinite(v.currentTime)&&Number.isFinite(v.duration))v.currentTime=Math.min(v.duration,v.currentTime+10);updateUi();});' +
    'if(btnVol)btnVol.addEventListener("click",function(){v.muted=!v.muted;' +
    'prefs.muted=v.muted;savePrefs();' +
    'btnVol.style.opacity=v.muted?"0.45":"0.92";});' +
    'if(volRange)volRange.addEventListener("input",function(){' +
    'setVol(parseFloat(volRange.value));});' +
    'if(btnSkip)btnSkip.addEventListener("click",function(){if(activeSkipEnd!==null&&Number.isFinite(v.duration)){v.currentTime=Math.min(v.duration,activeSkipEnd);updateUi();}});' +
    'if(btnNext)btnNext.addEventListener("click",function(){post({type:"animex-action",action:"next-episode"});});' +
    'if(btnSub)btnSub.addEventListener("click",function(){post({type:"animex-action",action:"audio",audio:"sub"});});' +
    'if(btnDub)btnDub.addEventListener("click",function(){post({type:"animex-action",action:"audio",audio:"dub"});});' +
    'if(btnEps)btnEps.addEventListener("click",function(){post({type:"animex-action",action:"episodes"});});' +
    'if(btnCc&&ccMenu)btnCc.addEventListener("click",function(){' +
    'ccMenu.hidden=!ccMenu.hidden;' +
    'if(!ccMenu.hidden){buildCcMenu();if(qMenu)qMenu.hidden=true;if(spMenu)spMenu.hidden=true;}placeSubs();});' +
    'function toggleFs(){var doc=document;var root=doc.documentElement||v;' +
    'if(doc.fullscreenElement){if(doc.exitFullscreen)doc.exitFullscreen();}' +
    'else if(root.requestFullscreen){root.requestFullscreen();}' +
    'else if(v.webkitEnterFullscreen){v.webkitEnterFullscreen();}}' +
    'if(btnFs)btnFs.addEventListener("click",toggleFs);' +
    'if(btnQ&&qMenu)btnQ.addEventListener("click",function(){qMenu.hidden=!qMenu.hidden;' +
    'if(!qMenu.hidden){if(ccMenu)ccMenu.hidden=true;if(spMenu)spMenu.hidden=true;}placeSubs();});' +
    'if(btnSpeed&&spMenu)btnSpeed.addEventListener("click",function(){' +
    'spMenu.hidden=!spMenu.hidden;' +
    'if(!spMenu.hidden){buildSpeedMenu();if(qMenu)qMenu.hidden=true;if(ccMenu)ccMenu.hidden=true;}placeSubs();});' +
    // The server picker swaps the source in place. It keeps the playhead, so
    // a dead server costs a two-second reload instead of the whole episode.
    // A failure stays here: posting `animex-content-error` tells the app the
    // whole Yume server is dead, which moves her off it, overwrites her
    // remembered choice, and ends the picker — the exact thing it exists for.
    'var pickSeq=0;' +
    // A pick can land on a different provider, and each ships its own
    // captions (or none). Leaving the old <track> elements attached would
    // list MegaPlay's subtitles over a Yume stream and show nothing when
    // picked, so the picker swaps them with the source.
    'function setTracks(list){var old=v.querySelectorAll?v.querySelectorAll("track"):[];' +
    'for(var i=old.length-1;i>=0;i--){try{v.removeChild(old[i]);}catch(e){}}' +
    'cueList=[];cueTrack=-1;subPick=0;' +
    'var arr=Array.isArray(list)?list:[];' +
    'for(var k=0;k<arr.length&&k<8;k++){var t=arr[k];if(!t||!t.file)continue;' +
    'var el=document.createElement("track");el.kind="captions";el.src=String(t.file);' +
    'if(t.label)el.label=String(t.label);if(k===0)el.default=true;' +
    'try{v.appendChild(el);}catch(e){}}' +
    'buildCcMenu();syncCues();}' +
    'function buildSvMenu(){if(!svMenu)return;svMenu.innerHTML="";' +
    'for(var i=0;i<servers.length;i++){(function(s){' +
    'svMenu.appendChild(ccBtn(s.label,s.id===currentServer,function(){pickServer(s);}));})(servers[i]);}}' +
    'function pickFailed(){picking=false;if(btnSv){btnSv.textContent="Server failed";' +
    'setTimeout(function(){if(btnSv)btnSv.textContent="Servers";},2200);}' +
    'if(svMenu)svMenu.hidden=false;}' +
    // Tapping the server that is already playing is a retry, not a no-op: the
    // reason she opened the menu may be that this very stream stalled.
    'function pickServer(s){if(!s||!s.url)return;' +
    'var seq=++pickSeq;picking=true;' +
    // The picker stays open until a source actually plays. Closing it on the
    // tap left the card up with no reachable control when the pick resolved
    // but never started: the card covers the Servers chip, and Retry reloads
    // the original URL, which does not know about the pick.
    'if(btnSv)btnSv.textContent="Loading\u2026";' +
    'fetch(s.url,{credentials:"omit"}).then(function(r){return r.json();}).then(function(d){' +
    // A later tap wins: without this the slower response overwrites the
    // server she actually picked last.
    'if(seq!==pickSeq)return;' +
    'if(!d||!d.src)throw new Error("no src");' +
    'currentServer=s.id;' +
    // Read the playhead now, not before the fetch: a 3 s resolve used to
    // rewind her 3 s.
    'var at=Number.isFinite(v.currentTime)?v.currentTime:0;' +
    'pendingSeek=at>0?at:null;hasMetadata=false;' +
    // Revive the player before handing it a new source. After a dead stream
    // the old instance is destroyed and would swallow this silently.
    'if(window.Hls&&Hls.isSupported()){' +
    'if(!hlsInst||hlsDead){hlsInst=makeHls();hlsInst.attachMedia(v);}' +
    'hlsInst.loadSource(d.src);' +
    '}else{v.src=d.src;}' +
    'if(Array.isArray(d.tracks))setTracks(d.tracks);' +
    'if(btnSv)btnSv.textContent="Servers";buildSvMenu();' +
    '}).catch(function(){if(seq!==pickSeq)return;pickFailed();});}' +
    'if(btnSv&&svMenu)btnSv.addEventListener("click",function(){svMenu.hidden=!svMenu.hidden;' +
    'if(!svMenu.hidden){buildSvMenu();if(qMenu)qMenu.hidden=true;' +
    'if(ccMenu)ccMenu.hidden=true;if(spMenu)spMenu.hidden=true;}placeSubs();});' +
    // Picture-in-Picture is a browser feature, not ours: hand the element
    // over and let the OS window own it. Safari on iPad uses webkit presentation mode.
    'function pipSupported(){return !!(document.pictureInPictureEnabled||' +
    '(v.webkitSupportsPresentationMode&&typeof v.webkitSetPresentationMode==="function"));}' +
    'if(btnPip){if(!pipSupported()){btnPip.hidden=true;}else{' +
    'btnPip.addEventListener("click",function(){var d=document;' +
    'if(d.pictureInPictureElement){if(d.exitPictureInPicture){' +
    'var x=d.exitPictureInPicture();if(x&&x.catch)x.catch(function(){});}return;}' +
    'if(v.webkitPresentationMode&&v.webkitSetPresentationMode){' +
    'v.webkitSetPresentationMode(v.webkitPresentationMode==="picture-in-picture"?"inline":"picture-in-picture");return;}' +
    'if(v.requestPictureInPicture){var p=v.requestPictureInPicture();' +
    'if(p&&p.catch)p.catch(function(){});}});}}' +
    'function trackEls(){return v.querySelectorAll?v.querySelectorAll("track"):[];}' +
    'function trackCount(){var n=v.textTracks?v.textTracks.length:0;var e=trackEls();return e.length>n?e.length:n;}' +
    'function trackLabel(i){var tt=v.textTracks&&v.textTracks[i];if(tt&&tt.label)return tt.label;' +
    'var el=trackEls()[i];var lb=el&&(el.label||(el.getAttribute&&el.getAttribute("label")));return lb||("Track "+(i+1));}' +
    'function ccBtn(txt,on,fn){var b=document.createElement("button");b.type="button";' +
    'b.className="qi"+(on?" on":"");b.textContent=txt;b.onclick=fn;return b;}' +
    'function ccHead(txt){var d=document.createElement("div");' +
    'd.className="cc-h";d.textContent=txt;return d;}' +
    'function ccRow(){var d=document.createElement("div");d.className="cc-row";return d;}' +
    // The panel sits where the captions live, so tuning the delay would hide
    // the line being tuned. Lift the overlay by the panel's real height.
    'function placeSubs(){if(!subBox||!subBox.style||!subBox.style.setProperty)return;' +
    'var lift=0;' +
    'if(ccMenu&&!ccMenu.hidden&&ccMenu.getBoundingClientRect){' +
    'lift=Math.max(0,Math.round(ccMenu.getBoundingClientRect().height-18));}' +
    'subBox.style.setProperty("--sub-lift",lift+"px");}' +
    'function closeMenus(){if(ccMenu)ccMenu.hidden=true;if(qMenu)qMenu.hidden=true;' +
    'if(spMenu)spMenu.hidden=true;if(svMenu)svMenu.hidden=true;placeSubs();}' +
    'function fmtDelay(d){if(!d)return"0.0s";return(d>0?"+":"")+d.toFixed(1)+"s";}' +
    'function setDelay(next){if(!isFinite(next))return;' +
    'prefs.delay=Math.round(Math.max(-10,Math.min(10,next))*10)/10;' +
    'savePrefs();renderCues();buildCcMenu();}' +
    'function setSize(next){prefs.size=Math.max(0,Math.min(2,next));' +
    'savePrefs();applySubSize();buildCcMenu();}' +
    'function setCc(on){ccOn=!!on;prefs.cc=ccOn;savePrefs();' +
    'if(btnCc)btnCc.classList.toggle("on",ccOn);syncCues();buildCcMenu();}' +
    'function buildCcMenu(){var n=trackCount();' +
    'if(btnCc)btnCc.hidden=n===0;' +
    'if(n===0){if(ccMenu)ccMenu.hidden=true;placeSubs();return;}' +
    'if(subPick>=n)subPick=0;' +
    'if(!ccMenu)return;ccMenu.innerHTML="";' +
    'ccMenu.appendChild(ccBtn(ccOn?"Captions on":"Captions off",ccOn,' +
    'function(){setCc(!ccOn);}));' +
    'if(n>1){ccMenu.appendChild(ccHead("Language"));' +
    'for(var i=0;i<n;i++){(function(idx){' +
    'ccMenu.appendChild(ccBtn(trackLabel(idx),idx===subPick&&ccOn,function(){' +
    'subPick=idx;prefs.lang=idx;savePrefs();' +
    'if(!ccOn){setCc(true);}else{syncCues();buildCcMenu();}}));})(i);}}' +
    'ccMenu.appendChild(ccHead("Subtitle delay"));' +
    'var dr=ccRow();' +
    'dr.appendChild(ccBtn("\u2212",false,function(){setDelay(prefs.delay-0.1);}));' +
    'var dl=ccBtn(fmtDelay(prefs.delay),false,function(){setDelay(0);});' +
    'dl.title="Tap to reset";dr.appendChild(dl);' +
    'dr.appendChild(ccBtn("+",false,function(){setDelay(prefs.delay+0.1);}));' +
    'ccMenu.appendChild(dr);' +
    'ccMenu.appendChild(ccHead("Text size"));' +
    'var sz=ccRow();var sizes=["Small","Medium","Large"];' +
    'for(var k=0;k<3;k++){(function(idx){' +
    'sz.appendChild(ccBtn(sizes[idx],idx===prefs.size,function(){setSize(idx);}));})(k);}' +
    'ccMenu.appendChild(sz);}' +
    // Cues are rendered by hand, not by the browser, so the delay slider can
    // shift them. `oncuechange` still fires at the real cue boundary and is
    // kept as an extra redraw; renderCues is a pure function of currentTime,
    // so a redraw at the wrong moment can never show the wrong line.
    'var cueList=[],cueTrack=-1;' +
    'function readCues(){if(!v.textTracks)return;var n=v.textTracks.length;if(!n)return;' +
    'var pick=subPick;if(pick<0||pick>=n)pick=0;' +
    'if(cueTrack===pick&&cueList.length)return;var out=[];' +
    'try{var cs=v.textTracks[pick].cues;if(cs){for(var j=0;j<cs.length;j++){var c=cs[j];' +
    'if(!c||typeof c.startTime!=="number"||typeof c.endTime!=="number")continue;' +
    'out.push({s:c.startTime,e:c.endTime,t:String(c.text||"").replace(/<[^>]+>/g,"")});}}}catch(e){}' +
    'if(out.length){cueList=out;cueTrack=pick;}}' +
    'function renderCues(){if(!subTxt)return;' +
    'if(!ccOn){if(subTxt.textContent)subTxt.textContent="";return;}' +
    'readCues();' +
    'if(!cueList.length){if(subTxt.textContent)subTxt.textContent="";return;}' +
    'var t=v.currentTime-prefs.delay;if(!isFinite(t))return;var lines=[];' +
    'for(var i=0;i<cueList.length;i++){var c=cueList[i];' +
    'if(t>=c.s&&t<c.e&&c.t)lines.push(c.t);}' +
    'var next=lines.join("\\n");' +
    'if(subTxt.textContent!==next)subTxt.textContent=next;}' +
    'function syncCues(){if(!v.textTracks)return;var n=v.textTracks.length;' +
    'var pick=subPick;if(pick<0||pick>=n)pick=0;' +
    'cueList=[];cueTrack=-1;' +
    'for(var i=0;i<n;i++){var tr=v.textTracks[i];' +
    'if(i!==pick){tr.mode="disabled";tr.oncuechange=null;continue;}' +
    'tr.mode=ccOn?"hidden":"disabled";tr.oncuechange=renderCues;}' +
    'renderCues();}' +
    'v.addEventListener("loadedmetadata",function(){buildCcMenu();syncCues();});' +
    'if(v.textTracks&&v.textTracks.addEventListener)v.textTracks.addEventListener("addtrack",buildCcMenu);' +
    'var idleT=null;function wakeHud(){if(document.body&&document.body.classList){document.body.classList.remove("idle");}' +
    'if(typeof clearTimeout==="function"&&idleT)clearTimeout(idleT);' +
    'if(typeof setTimeout==="function"){idleT=setTimeout(function(){' +
    'if(!v.paused&&(!ccMenu||ccMenu.hidden)&&(!spMenu||spMenu.hidden)&&document.body&&document.body.classList){' +
    'document.body.classList.add("idle");if(qMenu)qMenu.hidden=true;}},2800);}}' +
    'window.addEventListener("mousemove",function(){if(finePointer)wakeHud();});' +
    // Touching the control bands wakes the HUD. A touch on the picture must
    // not, or the tap that hides the controls would re-show them first.
    'var botEl=document.querySelector?document.querySelector(".h-bot"):null;' +
    'var topEl=document.querySelector?document.querySelector(".h-top"):null;' +
    'if(botEl)botEl.addEventListener("touchstart",wakeHud,{passive:true});' +
    'if(topEl)topEl.addEventListener("touchstart",wakeHud,{passive:true});' +
    // Picture click toggles playback. A double click also fires two clicks
    // first, so pause+resume cancel out and fullscreen lands on the play
    // state she already had — no timer, no lag.
    'function togglePlay(){if(v.paused){tryPlay();}else{v.pause();}}' +
    'function seekBy(delta){if(!Number.isFinite(v.currentTime))return;' +
    'var d=Number.isFinite(v.duration)&&v.duration>0?v.duration:Infinity;' +
    'v.currentTime=Math.max(0,Math.min(d,v.currentTime+delta));updateUi();}' +
    'function seekTo(sec){if(!Number.isFinite(v.duration)||v.duration<=0||!Number.isFinite(sec))return;' +
    'v.currentTime=Math.max(0,Math.min(v.duration,sec));updateUi();}' +
    'function setVol(x){if(!Number.isFinite(x))return;' +
    'var n=Math.max(0,Math.min(1,x));v.volume=n;v.muted=n===0;' +
    'prefs.vol=n;prefs.muted=v.muted;savePrefs();' +
    'if(volRange&&volRange.value!==String(n))volRange.value=String(n);' +
    'if(btnVol)btnVol.style.opacity=v.muted?"0.45":"0.92";}' +
    // The bar is dragged, not clicked. Nothing is committed until the
    // pointer lifts, so a slow drag across a long film does not fire a seek
    // on every pixel and stall the buffer.
    'var dragging=false,dragPct=null;' +
    'function pctFromX(clientX){if(!scrub||!scrub.getBoundingClientRect)return null;' +
    'if(!Number.isFinite(v.duration)||v.duration<=0)return null;' +
    'var r=scrub.getBoundingClientRect();if(!(r.width>0))return null;' +
    'return Math.max(0,Math.min(1,(clientX-r.left)/r.width));}' +
    'function paintDrag(pct){if(pct===null)return;' +
    'if(sFill)sFill.style.width=(pct*100)+"%";' +
    'if(timeLbl&&Number.isFinite(v.duration))timeLbl.textContent=fmt(pct*v.duration)+" / "+fmt(v.duration);}' +
    'function endDrag(commit){if(!dragging)return;dragging=false;' +
    'var pct=dragPct;dragPct=null;' +
    'if(commit&&pct!==null&&Number.isFinite(v.duration)&&v.duration>0){' +
    'try{v.currentTime=pct*v.duration;}catch(e){}}' +
    'updateUi();}' +
    'if(scrub){' +
    'scrub.setAttribute("role","slider");scrub.setAttribute("tabindex","0");' +
    'scrub.setAttribute("aria-label","Seek");' +
    'scrub.addEventListener("pointerdown",function(e){' +
    'try{scrub.focus();}catch(fe){}' +
    'dragging=true;dragPct=pctFromX(e.clientX);paintDrag(dragPct);wakeHud();' +
    'if(scrub.setPointerCapture&&e.pointerId!==undefined){' +
    'try{scrub.setPointerCapture(e.pointerId);}catch(err){}}' +
    'if(e.preventDefault)e.preventDefault();});' +
    'window.addEventListener("pointermove",function(e){if(!dragging)return;' +
    'dragPct=pctFromX(e.clientX);paintDrag(dragPct);});' +
    'window.addEventListener("pointerup",function(){endDrag(true);});' +
    'window.addEventListener("pointercancel",function(){endDrag(false);});' +
    'scrub.addEventListener("keydown",function(e){var k=e.key;' +
    'if(k==="ArrowRight"){seekBy(10);}' +
    'else if(k==="ArrowLeft"){seekBy(-10);}' +
    'else if(k==="Home"){seekTo(0);}' +
    'else if(k==="End"){seekTo(v.duration);}' +
    'else{return;}' +
    // The window handler would seek again on the same bubbling key.
    'if(e.stopPropagation)e.stopPropagation();' +
    'if(e.preventDefault)e.preventDefault();});}' +
    // A phone has no hover and no fine pointer. There, a tap must never
    // pause: one tap toggles the controls, double tap on either side seeks.
    // Click-to-pause stays for anything with a real mouse.
    'var finePointer=false;' +
    'try{finePointer=!!(window.matchMedia&&' +
    'window.matchMedia("(hover:hover) and (pointer:fine)").matches);}catch(e){}' +
    'var lastTap={t:0,x:0},tapTimer=null;' +
    'function toggleHud(){if(!document.body||!document.body.classList)return;' +
    'if(document.body.classList.contains("idle")){wakeHud();return;}' +
    'document.body.classList.add("idle");closeMenus();' +
    'if(typeof clearTimeout==="function"&&idleT){clearTimeout(idleT);idleT=null;}}' +
    'function doubleTapSeek(x){' +
    'var r=scrub&&scrub.getBoundingClientRect?scrub.getBoundingClientRect():null;' +
    'var w=r&&r.width>0?r.width:(window.innerWidth||0);' +
    'if(!(w>0))return;var relX=r?(x-r.left):x;var third=w/3;' +
    'if(relX<third){seekBy(-10);}else if(relX>2*third){seekBy(10);}else{togglePlay();}}' +
    'function onPictureTap(e){' +
    'closeMenus();' +
    'var x=e&&typeof e.clientX==="number"?e.clientX:0;' +
    'if(finePointer){togglePlay();wakeHud();return;}' +
    'var now=Date.now();' +
    'if(now-lastTap.t<300&&Math.abs(x-lastTap.x)<80){' +
    'lastTap={t:0,x:0};' +
    'if(typeof clearTimeout==="function"&&tapTimer){clearTimeout(tapTimer);tapTimer=null;}' +
    'doubleTapSeek(x);return;}' +
    'lastTap={t:now,x:x};' +
    'if(typeof setTimeout!=="function")return;' +
    'if(tapTimer){clearTimeout(tapTimer);}' +
    'tapTimer=setTimeout(function(){tapTimer=null;toggleHud();},300);}' +
    'v.addEventListener("click",onPictureTap);' +
    // Double-click fullscreen belongs to the mouse. On touch the same two
    // taps are the seek gesture above.
    'v.addEventListener("dblclick",function(e){if(!finePointer)return;' +
    'if(e&&e.preventDefault)e.preventDefault();toggleFs();});' +
    // Keys only reach this document while the frame has focus, which a click
    // on the picture gives it. YouTube's bindings, plus 0-9 to jump. The same
    // handler serves keys the app relays from its own document.
    'function handleKey(k){if(typeof k!=="string"||!k)return false;var used=true;' +
    'if(k===" "||k==="k"||k==="K"){togglePlay();}' +
    'else if(k==="ArrowRight"||k==="l"||k==="L"){seekBy(10);}' +
    'else if(k==="ArrowLeft"||k==="j"||k==="J"){seekBy(-10);}' +
    'else if(k==="ArrowUp"){setVol((v.volume||0)+0.1);}' +
    'else if(k==="ArrowDown"){setVol((v.volume||0)-0.1);}' +
    'else if(k==="m"||k==="M"){v.muted=!v.muted;prefs.muted=v.muted;savePrefs();' +
    'if(btnVol)btnVol.style.opacity=v.muted?"0.45":"0.92";}' +
    'else if(k==="f"||k==="F"){toggleFs();}' +
    'else if(k==="c"||k==="C"){setCc(!ccOn);}' +
    'else if(k==="n"||k==="N"){if(btnNext&&!btnNext.hidden)btnNext.click();}' +
    'else if(/^[0-9]$/.test(k)){seekTo((v.duration||0)*Number(k)/10);}' +
    'else{used=false;}' +
    'if(used)wakeHud();return used;}' +
    'window.addEventListener("keydown",function(e){' +
    'if(!e||e.ctrlKey||e.metaKey||e.altKey)return;' +
    'var tag=e.target&&e.target.tagName;' +
    'if(tag==="INPUT"||tag==="TEXTAREA"||tag==="SELECT")return;' +
    'if(handleKey(e.key)){if(e.preventDefault)e.preventDefault();}});' +
    'if(window.Hls&&Hls.isSupported()){' +
    'var fatal=0;' +
    // A destroyed hls.js instance cannot be revived: loadSource() on it is a
    // silent no-op (checked against hls.js 1.7.4 — no event, no throw), so a
    // pick after a dead stream must build a fresh one or nothing plays and
    // nothing reports why. Everything below is per-instance, so it lives here.
    'makeHls=function(){' +
    (token
      ? 'var h=new Hls({maxBufferLength:30,xhrSetup:function(x){try{x.setRequestHeader("Authorization","Bearer "+' + JSON.stringify(String(token)) + ');}catch(e){}}});'
      : 'var h=new Hls({maxBufferLength:30});') +
    'hlsInst=h;hlsDead=false;fatal=0;' +
    'h.on(Hls.Events.ERROR,function(ev,data){' +
    'if(!data||!data.fatal){return;}fatal++;' +
    'if(fatal>3){hlsDead=true;try{h.destroy();}catch(e){}giveUp();return;}' +
    'var ET=Hls.ErrorTypes||{};' +
    'try{' +
    'if(data.type===ET.NETWORK_ERROR){h.startLoad();}' +
    'else if(data.type===ET.MEDIA_ERROR){h.recoverMediaError();}' +
    'else if(fatal<3){h.startLoad();}' +
    'else{hlsDead=true;h.destroy();giveUp();}' +
    '}catch(e){hlsDead=true;try{h.destroy();}catch(x){}giveUp();}});' +
    'h.on(Hls.Events.MANIFEST_PARSED,function(){' +
    'if(qMenu&&btnQ&&Array.isArray(h.levels)&&h.levels.length>0){' +
    'qMenu.innerHTML="";var mk=function(lbl,lvl){var b=document.createElement("button");' +
    'b.className="qi"+(h.currentLevel===lvl?" on":"");b.textContent=lbl;' +
    'b.onclick=function(){h.currentLevel=lvl;btnQ.textContent=lvl===-1?"Auto":lbl;qMenu.hidden=true;};qMenu.appendChild(b);};' +
    'mk("Auto",-1);h.levels.forEach(function(lv,idx){if(lv&&lv.height)mk(lv.height+"p",idx);});}' +
    'tryPlay();});' +
    'return h;};' +
    'var h=makeHls();' +
    'h.loadSource(src);h.attachMedia(v);' +
    '}else{' +
    'v.src=src;' +
    'v.addEventListener("loadedmetadata",function(){tryPlay();});' +
    'v.addEventListener("error",function(){giveUp();});' +
    '}})();</' + 'script></body></html>'
  );
}

module.exports = { escHtml, hlsPlayerHtml };
