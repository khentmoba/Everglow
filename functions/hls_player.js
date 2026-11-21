'use strict';

function escHtml(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function safeScriptJson(val) {
  const serialized = JSON.stringify(val);
  return (serialized === undefined ? 'undefined' : serialized)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

const SEEK_ARC = {
  rew: '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
  ff: '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>',
};
const FLASH_ICONS = {
  play: '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M7 4.5l13 7.5-13 7.5z"/></svg>',
  pause: '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M6 4h4v16H6zM14 4h4v16h-4z"/></svg>',
  rew: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + SEEK_ARC.rew + '</svg><b>10</b>',
  ff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + SEEK_ARC.ff + '</svg><b>10</b>',
};

function hlsPlayerHtml({ src, title, tracks, token, ep, audio, kind, servers, current, hasEpisodes, poster }) {
  const isCinema = kind === 'cinema';
  const showEps = !isCinema || !!hasEpisodes;
  const posterUrl = /^https:\/\//i.test(String(poster || '').trim()) ? String(poster).trim() : '';
  const serverList = (Array.isArray(servers) ? servers : [])
    .filter((s) => s && s.id && s.url)
    .map((s) => ({ id: String(s.id), label: String(s.label || s.id), url: String(s.url) }));
  const currentServer = serverList.some((s) => s.id === current) ? current : serverList[0]?.id || '';
  const trackTags = (Array.isArray(tracks) ? tracks : [])
    .filter((t) => t && t.file)
    .slice(0, 40)
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
  const rawTitle = String(title || (epNum ? 'Episode ' + epNum : 'Everglow'));
  const sepAt = rawTitle.lastIndexOf(' \u00b7 ');
  const displayTitle = escHtml(rawTitle);
  const hudMain = sepAt > 0 ? escHtml(rawTitle.slice(0, sepAt)) : displayTitle;
  const hudEp = sepAt > 0 ? escHtml(rawTitle.slice(sepAt)) : '';
  return (
    '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<meta name="referrer" content="no-referrer">' +
    '<title>' + displayTitle + '</title>' +
    '<link rel="preconnect" href="https://fonts.googleapis.com">' +
    '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' +
    '<link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=DM+Sans:wght@500;600;700;800&display=swap" rel="stylesheet">' +
    '<style>' +
    ':root{--acc:#c2185b;--acc2:#e91e63;--acc-hi:#ff8caf;--acc-soft:rgba(194,24,91,.34);' +
    '--acc-hover:rgba(255,111,145,.16);--acc-ring:rgba(255,140,175,.45);--acc-glow:rgba(194,24,91,.42);' +
    '--bg-base:#08060e;--bg-hud-top:rgba(10,6,14,.86);--bg-hud-bot:rgba(14,7,18,.97);--bg-menu:rgba(16,9,20,.94)}' +
    'body.is-cinema{--acc:#e50914;--acc2:#b20710;--acc-hi:#ff6b6b;--acc-soft:rgba(229,9,20,.34);' +
    '--acc-hover:rgba(229,9,20,.16);--acc-ring:rgba(229,9,20,.55);--acc-glow:rgba(229,9,20,.4);' +
    '--bg-base:#08080a;--bg-hud-top:rgba(8,8,10,.86);--bg-hud-bot:rgba(10,10,12,.97);--bg-menu:rgba(18,18,22,.95)}' +
    '*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}' +
    'html,body{margin:0;height:100%;background:var(--bg-base);overflow:hidden;' +
    'font-family:"DM Sans",-apple-system,BlinkMacSystemFont,sans-serif;color:#fff5f5;user-select:none}' +
    'video{width:100%;height:100%;background:#000;display:block;object-fit:contain;transition:object-fit .15s ease,transform .18s ease}' +
    'video.fill{object-fit:cover}' +
    'video.zoom{object-fit:cover;transform:scale(1.18)}' +
    '@keyframes egfs{from{opacity:.86;transform:scale(.982)}to{opacity:1;transform:scale(1)}}' +
    'body.fs-settle video,body.fs-settle #hud{animation:egfs .22s cubic-bezier(.22,1,.36,1)}' +
    '@media (prefers-reduced-motion:reduce){body.fs-settle video,body.fs-settle #hud{animation:none}}' +
    'video::cue{background:transparent!important;background-color:transparent!important;' +
    'color:#fff;font-family:"DM Sans",sans-serif;font-weight:800;' +
    'text-shadow:-1.5px -1.5px 0 rgba(0,0,0,.96),1.5px -1.5px 0 rgba(0,0,0,.96),' +
    '-1.5px 1.5px 0 rgba(0,0,0,.96),1.5px 1.5px 0 rgba(0,0,0,.96),' +
    '0 2px 6px rgba(0,0,0,.98),0 0 12px rgba(0,0,0,.88)}' +
    '#sub-box{position:fixed;left:50%;transform:translateX(-50%);bottom:calc(100px + var(--sub-lift,0px) + var(--sub-pos,0px));width:78%;' +
    'text-align:center;z-index:6;pointer-events:none;transition:bottom .24s cubic-bezier(.22,1,.36,1)}' +
    'body.idle #sub-box,body.locked #sub-box{bottom:calc(24px + var(--sub-idle-lift,0px) + var(--sub-pos,0px))}' +
    'body.sub-top #sub-box{top:62px;bottom:auto}body.sub-top.idle #sub-box,body.sub-top.locked #sub-box{top:24px;bottom:auto}' +
    '#sub-txt{display:inline-block;max-width:100%;background:transparent;color:var(--sub-color,#fff);' +
    'font-size:calc(clamp(15px,2.4vw,42px)*var(--sub-scale,1));' +
    'font-weight:800;line-height:1.35;letter-spacing:.01em;white-space:pre-line;border-radius:6px;padding:1px 6px;' +
    'text-shadow:-1.5px -1.5px 0 rgba(0,0,0,.96),1.5px -1.5px 0 rgba(0,0,0,.96),' +
    '-1.5px 1.5px 0 rgba(0,0,0,.96),1.5px 1.5px 0 rgba(0,0,0,.96),' +
    '0 2px 6px rgba(0,0,0,.98),0 0 12px rgba(0,0,0,.88)}' +
    '#sub-txt:empty{display:none}' +
    '#sub-txt.bg-pill{background:rgba(10,6,14,.84);padding:3px 10px;text-shadow:0 2px 6px rgba(0,0,0,.95)}' +
    'body.is-cinema #sub-txt.bg-pill{background:rgba(12,12,16,.84)}' +
    '#sub-txt.bg-box{background:rgba(0,0,0,.92);padding:4px 12px;text-shadow:none}' +
    '.ov{position:fixed;inset:0;display:flex;align-items:center;' +
    'justify-content:center;background:rgba(8,6,14,.74);backdrop-filter:blur(4px);z-index:8}' +
    '#tapw{flex-direction:column;gap:14px;padding:24px;text-align:center;overflow:hidden;' +
    'background:radial-gradient(circle at 50% 45%,var(--acc-soft) 0%,var(--bg-base) 72%)}' +
    '#tap-art{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;opacity:.24;filter:blur(7px) saturate(1.1);pointer-events:none;z-index:0}' +
    '#tapw>*:not(#tap-art){position:relative;z-index:1}' +
    '#tap-opts{display:flex;align-items:center;justify-content:center;gap:10px;flex-wrap:wrap}' +
    '#tap-title{font-size:clamp(16px,2.2vw,24px);font-weight:800;color:#fff;max-width:min(520px,86vw);' +
    'text-shadow:0 2px 14px rgba(0,0,0,.8)}' +
    '#tap-sub{font-size:12px;font-weight:600;color:rgba(255,255,255,.68);letter-spacing:.03em;text-transform:uppercase}' +
    '.ov[hidden]{display:none!important}[hidden]{display:none!important}' +
    '.eg-wave{display:inline-flex;font-family:"Bebas Neue",Impact,sans-serif;' +
    'font-size:clamp(34px,6vw,50px);letter-spacing:.1em;line-height:1}' +
    '.wc{display:inline-block;animation:egw 1.3s ease-in-out infinite}' +
    '.wc.e{color:#f8f8f8;text-shadow:0 4px 16px rgba(0,0,0,.75)}' +
    '.wc.g{color:var(--acc);text-shadow:0 4px 20px var(--acc-glow)}' +
    '.wc:nth-child(1){animation-delay:0s}.wc:nth-child(2){animation-delay:.09s}' +
    '.wc:nth-child(3){animation-delay:.18s}.wc:nth-child(4){animation-delay:.27s}' +
    '.wc:nth-child(5){animation-delay:.36s}.wc:nth-child(6){animation-delay:.45s}' +
    '.wc:nth-child(7){animation-delay:.54s}.wc:nth-child(8){animation-delay:.63s}' +
    '@keyframes egw{0%,100%{transform:translateY(0);opacity:.72}' +
    '45%{transform:translateY(-9px);opacity:1}}' +
    '#tap{cursor:pointer;border:0;border-radius:999px;padding:13px 28px;' +
    'font-size:15px;font-weight:700;color:#fff;background:var(--acc);' +
    'box-shadow:0 8px 24px var(--acc-glow);transition:transform .16s ease,filter .16s ease}' +
    '#tap:hover{filter:brightness(1.1);transform:scale(1.03)}' +
    '#dead{flex-direction:column;text-align:center;color:#f8f8f8;padding:0 28px}' +
    '.dead-acts{display:flex;gap:10px;flex-wrap:wrap;justify-content:center;margin-top:16px}' +
    '#dead button{cursor:pointer;border:1px solid var(--acc-ring);' +
    'border-radius:999px;padding:9px 22px;font-size:13.5px;font-weight:700;color:#fff;background:rgba(18,10,24,.72);font-family:inherit;transition:background .15s ease,border-color .15s ease}' +
    '#dead button:hover{background:var(--acc-soft);border-color:var(--acc-hi)}' +
    '#dead-sv{background:linear-gradient(135deg,var(--acc),var(--acc2))!important;border-color:transparent!important;box-shadow:0 4px 16px var(--acc-glow)}' +
    '#hud{position:fixed;inset:0;display:flex;flex-direction:column;justify-content:space-between;' +
    'background:linear-gradient(180deg,var(--bg-hud-top) 0%,rgba(10,6,14,.38) 18%,transparent 32%,' +
    'transparent 54%,rgba(14,7,18,.58) 76%,var(--bg-hud-bot) 100%);' +
    'z-index:5;transition:opacity .3s cubic-bezier(.22,1,.36,1);pointer-events:none}' +
    '.h-top,.h-bot{pointer-events:auto}' +
    'body.idle #hud,body.preplay #hud,body.preplay #binge{opacity:0;pointer-events:none}' +
    'body.idle .h-top,body.idle .h-bot,body.preplay .h-top,body.preplay .h-bot{pointer-events:none}' +
    'body.idle{cursor:none}' +
    '.h-top,.h-bot{transition:transform .34s cubic-bezier(.22,1,.36,1)}' +
    'body.idle .h-top{transform:translateY(-14px)}body.idle .h-bot{transform:translateY(14px)}' +
    '.h-top{padding:18px 26px;display:flex;justify-content:space-between;align-items:center;gap:12px}' +
    '.h-top-l{display:flex;align-items:center;gap:9px;min-width:0;max-width:62%;flex:0 1 auto;background:rgba(14,8,18,.54);backdrop-filter:blur(8px);padding:4px 12px 4px 8px;border-radius:999px;border:1px solid rgba(255,255,255,.12)}' +
    'body.is-cinema .h-top-l{background:rgba(12,12,16,.58);padding:4px 14px}' +
    '.h-title-wrap{display:flex;align-items:baseline;min-width:0;flex:0 1 auto}' +
    '#hud-title{display:block;min-width:0;max-width:100%;font-size:16px;font-weight:800;letter-spacing:.01em;color:#fff;' +
    'text-shadow:0 2px 10px rgba(0,0,0,.85);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
    '#hud-ep{flex-shrink:0;white-space:pre;font-size:16px;font-weight:800;letter-spacing:.01em;color:rgba(255,255,255,.88);' +
    'text-shadow:0 2px 10px rgba(0,0,0,.85)}' +
    '.h-top-r{display:flex;align-items:center;gap:8px;flex-shrink:0;margin-left:auto}' +
    '.sd-box{display:flex;background:rgba(18,10,24,.58);border-radius:999px;padding:2px;' +
    'border:1px solid var(--acc-ring);backdrop-filter:blur(10px)}' +
    '.sd-b{border:0;background:transparent;padding:3px 10px;font-size:10.5px;font-weight:800;' +
    'border-radius:999px;color:#e4bfd0;cursor:pointer;font-family:inherit;transition:background .15s ease,color .15s ease}' +
    '.sd-b:hover{color:#fff}' +
    '.sd-b.on{background:linear-gradient(135deg,var(--acc),var(--acc2));color:#fff;box-shadow:0 2px 10px var(--acc-glow)}' +
    '.h-bot{padding:0 26px 16px;display:flex;flex-direction:column;gap:10px}' +
    '.bar-row{display:flex;align-items:center;gap:14px}' +
    '#c-transport{position:fixed;top:46%;left:50%;transform:translate(-50%,-50%);display:none;align-items:center;gap:24px;z-index:6;pointer-events:auto}' +
    'body.idle #c-transport,body.preplay #c-transport,body.buffering #c-transport,body.locked #c-transport{opacity:0;pointer-events:none}' +
    '.c-sec{width:46px;height:46px;border-radius:50%;border:1px solid rgba(255,255,255,.16);background:rgba(12,8,16,.54);backdrop-filter:blur(8px);' +
    'color:#fff;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;transition:transform .16s ease,background .15s ease}' +
    '.c-sec:active{transform:scale(.88)}.c-sec svg{width:22px;height:22px}' +
    '.cplay{width:64px;height:64px;' +
    'border-radius:50%;border:2px solid var(--acc-ring);background:rgba(14,7,18,.58);backdrop-filter:blur(8px);' +
    'color:#fff;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;' +
    'box-shadow:0 0 28px var(--acc-glow);pointer-events:auto;' +
    'transition:transform .2s cubic-bezier(.34,1.56,.64,1),background .15s ease}' +
    '.cplay:active{transform:scale(.88)}.cplay svg{width:28px;height:28px}' +
    '#flash{position:fixed;top:50%;left:50%;width:84px;height:84px;margin:-42px 0 0 -42px;' +
    'border-radius:50%;display:flex;flex-direction:column;align-items:center;justify-content:center;' +
    'background:rgba(14,7,18,.52);border:2px solid var(--acc-ring);' +
    'box-shadow:0 0 30px var(--acc-glow);color:#fff;z-index:6;pointer-events:none;opacity:0}' +
    '#flash.l{left:26%}#flash.r{left:74%}' +
    '#flash svg{width:32px;height:32px}' +
    '#flash b{font-size:12px;font-weight:800;margin-top:1px;color:var(--acc-hi)}' +
    '#flash.go{animation:egflash .62s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egflash{0%{opacity:0;transform:scale(.6)}25%{opacity:1;transform:scale(1.06)}' +
    '60%{opacity:1;transform:scale(1)}100%{opacity:0;transform:scale(1.2)}}' +
    '#binge{position:fixed;left:0;right:0;bottom:112px;padding:0 26px;z-index:7;' +
    'display:flex;justify-content:flex-end;align-items:center;min-height:34px;' +
    'pointer-events:none;transition:bottom .26s cubic-bezier(.22,1,.36,1)}' +
    'body.idle #binge{bottom:28px}' +
    'body.menu-open #binge{opacity:0;pointer-events:none}' +
    '#binge .b-act{pointer-events:auto}' +
    '.b-scrim{position:absolute;right:-20px;bottom:-14px;width:340px;height:120px;' +
    'pointer-events:none;background:radial-gradient(ellipse at 78% 62%,' +
    'rgba(10,5,16,.72) 0%,rgba(10,5,16,.35) 45%,transparent 72%)}' +
    '#b-scrim[hidden]{display:none!important}' +
    '.b-act{position:relative;display:inline-flex;align-items:center;gap:8px;' +
    'padding:8px 16px 10px;border:1px solid var(--acc-ring);border-radius:999px;' +
    'background:var(--bg-menu);backdrop-filter:blur(12px);font-family:inherit;' +
    'font-size:13.5px;font-weight:800;letter-spacing:.01em;color:#fff;cursor:pointer;' +
    'box-shadow:0 8px 24px rgba(0,0,0,.58),0 0 18px var(--acc-glow);' +
    'transition:color .15s ease,background .15s ease,border-color .15s ease,transform .16s ease}' +
    '.b-act:hover{color:#fff;background:rgba(32,14,34,.92);border-color:var(--acc-hi);transform:translateY(-1px)}' +
    '.b-act:active{transform:scale(.96)}' +
    '.b-act:not([hidden]){animation:egbin .38s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egbin{from{opacity:0;transform:translateX(18px)}to{opacity:1;transform:none}}' +
    '.b-ico{display:inline-flex}' +
    '.b-skip .b-ico{color:#f5c97b}' +
    '.b-next .b-ico{color:var(--acc-hi)}' +
    '.b-t{color:#f5c97b;font-variant-numeric:tabular-nums;font-weight:800}' +
    '.b-next .b-t{color:rgba(255,245,245,.72)}' +
    '.b-u{position:absolute;left:14px;right:14px;bottom:4px;height:2px;border-radius:2px;' +
    'overflow:hidden;background:rgba(255,255,255,.16)}' +
    '.b-next{gap:4px;padding:0 10px 0 0;cursor:default}' +
    '.b-main{border:0;background:transparent;color:inherit;font:inherit;letter-spacing:inherit;display:inline-flex;align-items:center;gap:8px;padding:8px 4px 10px 16px;cursor:pointer;border-radius:999px}' +
    '.b-x{border:0;font-family:inherit;padding:0;display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;margin-left:2px;border-radius:50%;' +
    'background:rgba(255,255,255,.12);color:rgba(255,255,255,.82);font-size:10px;line-height:1;cursor:pointer;transition:background .15s ease,color .15s ease}' +
    '.b-x:hover{background:rgba(255,255,255,.26);color:#fff}' +
    'svg [hidden]{display:none!important}' +
    '.b-u i{display:block;height:100%;width:100%;transition:width .2s linear}' +
    '.b-skip .b-u i{background:#f5c97b}' +
    '.b-next .b-u i{background:linear-gradient(90deg,var(--acc),var(--acc2))}' +
    '#scrub-wrap{position:relative;flex:1;min-width:0;padding:6px 8px 2px}' +
    '#scrub-prev{position:absolute;bottom:22px;left:0;transform:translateX(-50%);' +
    'width:168px;pointer-events:none;z-index:10;display:flex;flex-direction:column;' +
    'align-items:center;gap:6px;transition:opacity .12s ease}' +
    '#scrub-prev[hidden]{display:none!important}' +
    '#scrub-prev:not([hidden]){animation:egprev .18s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egprev{from{opacity:0;transform:translateX(-50%) translateY(8px) scale(.9)}' +
    'to{opacity:1;transform:translateX(-50%)}}' +
    '.pv-box{position:relative;width:100%;aspect-ratio:16/9;border-radius:8px;overflow:hidden;' +
    'background:#120916;border:1.5px solid var(--acc-ring);' +
    'box-shadow:0 12px 30px rgba(0,0,0,.86),0 0 20px var(--acc-glow)}' +
    '#pv,#pv-c{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:block}' +
    '#pv-c[hidden]{display:none!important}' +
    '#pv-load{position:absolute;left:0;right:0;bottom:0;height:2.5px;overflow:hidden;' +
    'background:rgba(255,255,255,.12);opacity:0;transition:opacity .15s ease}' +
    '#scrub-prev.loading #pv-load{opacity:1}' +
    '#pv-load i{display:block;width:45%;height:100%;' +
    'background:linear-gradient(90deg,transparent,var(--acc2),transparent);' +
    'animation:egpv 1s ease-in-out infinite}' +
    '@keyframes egpv{0%{transform:translateX(-100%)}100%{transform:translateX(260%)}}' +
    '.pv-meta{display:inline-flex;align-items:center;gap:6px;padding:2px 9px;border-radius:999px;' +
    'background:var(--bg-menu);border:1px solid var(--acc-ring);' +
    'box-shadow:0 4px 12px rgba(0,0,0,.65)}' +
    '#pv-time{font-size:11.5px;font-weight:800;font-variant-numeric:tabular-nums;' +
    'color:#fff;letter-spacing:.02em}' +
    '#pv-tag{font-size:9.5px;font-weight:800;letter-spacing:.05em;text-transform:uppercase;color:var(--acc-hi)}' +
    '#pv-tag[hidden]{display:none!important}' +
    '#scrub{position:relative;height:4px;border-radius:999px;background:rgba(255,245,245,.22);' +
    'cursor:pointer;outline:none;touch-action:none;transition:height .14s cubic-bezier(.22,1,.36,1)}' +
    '#scrub::before{content:"";position:absolute;left:0;right:0;top:-11px;bottom:-11px}' +
    '#scrub:hover,body.scrubbing #scrub{height:7px}' +
    '#scrub:focus-visible{box-shadow:0 0 0 3px var(--acc-ring)}' +
    '#s-buf{position:absolute;left:0;top:0;bottom:0;width:0%;background:rgba(255,230,240,.28);border-radius:999px}' +
    '#s-hover{position:absolute;left:0;top:0;bottom:0;width:0%;background:var(--acc-soft);' +
    'border-radius:999px;pointer-events:none;z-index:1}' +
    '#s-fill{position:absolute;left:0;top:0;bottom:0;width:0%;' +
    'background:linear-gradient(90deg,var(--acc) 0%,var(--acc2) 100%);' +
    'box-shadow:0 0 10px var(--acc-glow);z-index:2;border-radius:999px}' +
    '#s-thumb{position:absolute;top:50%;left:0%;width:12px;height:12px;border-radius:50%;' +
    'background:var(--acc2);border:2px solid #fff;' +
    'box-shadow:0 0 0 3px var(--acc-soft),0 2px 8px rgba(0,0,0,.6);' +
    'transform:translate(-50%,-50%) scale(.82);opacity:0;z-index:4;pointer-events:none;' +
    'transition:transform .14s ease,opacity .14s ease}' +
    '#scrub:hover #s-thumb,body.scrubbing #s-thumb,#scrub:focus-visible #s-thumb{' +
    'opacity:1;transform:translate(-50%,-50%) scale(1.08)}' +
    '@media (hover:none),(pointer:coarse),(max-width:640px),(max-height:430px){#scrub{height:5px}#s-thumb{width:14px;height:14px;opacity:1;transform:translate(-50%,-50%) scale(1)}}' +
    '.s-chap{position:absolute;top:0;bottom:0;background:rgba(245,201,123,.62);' +
    'border-left:1px solid #f5c97b;border-right:1px solid #f5c97b;z-index:3;pointer-events:none}' +
    '.ctrl-r{display:flex;justify-content:space-between;align-items:center;gap:14px;font-size:12px;color:#f5dce4}' +
    '.ctrl-l,.ctrl-rt{display:flex;align-items:center;gap:18px}' +
    '.ctrl-rt{gap:14px}' +
    '.ib{border:0;background:transparent;color:#fff;display:inline-flex;align-items:center;' +
    'justify-content:center;cursor:pointer;padding:6px;border-radius:50%;opacity:.94;' +
    'transition:transform .2s cubic-bezier(.34,1.56,.64,1),color .15s ease,background .15s ease,opacity .15s ease}' +
    '.ib svg{width:26px;height:26px;overflow:visible}' +
    '.ib:hover{opacity:1;color:var(--acc-hi);background:var(--acc-hover);transform:scale(1.14)}' +
    '.ib:active{transform:scale(.86)}' +
    '.ib.on{color:var(--acc-hi)}' +
    '.ib:focus-visible,.chip:focus-visible,.sd-b:focus-visible,.qi:focus-visible,.b-act:focus-visible,.b-main:focus-visible,.b-x:focus-visible,#tap:focus-visible,#dead button:focus-visible,#time-lbl:focus-visible,#unlock-btn:focus-visible,.menu-x:focus-visible{outline:2px solid var(--acc-hi);outline-offset:2px}' +
    '@media (hover:hover) and (pointer:fine) and (min-width:641px) and (min-height:431px){#btn-lock{display:none}}' +
    '@media (hover:hover) and (pointer:fine){body.is-paused #c-transport{display:flex;pointer-events:none}' +
    'body.is-paused #c-transport .c-sec{display:none}body.is-paused #cplay{width:56px;height:56px;opacity:.9;pointer-events:auto}}' +
    '#btn-back{display:none;padding:4px;margin-right:2px}body.is-fs #btn-back{display:inline-flex}' +
    '.ib.pop svg{animation:egpop .34s cubic-bezier(.34,1.56,.64,1)}' +
    '.ib.spin-l svg{animation:egsl .5s cubic-bezier(.22,1,.36,1)}' +
    '.ib.spin-r svg{animation:egsr .5s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egpop{0%{transform:scale(.6)}100%{transform:scale(1)}}' +
    '@keyframes egsl{0%{transform:rotate(0)}40%{transform:rotate(-50deg)}100%{transform:rotate(0)}}' +
    '@keyframes egsr{0%{transform:rotate(0)}40%{transform:rotate(50deg)}100%{transform:rotate(0)}}' +
    '#vol-wrap{display:flex;align-items:center;gap:6px}' +
    '#vol-range{width:58px;opacity:.82;height:16px;margin:0;padding:0;accent-color:var(--acc2);' +
    'background:transparent;cursor:pointer;overflow:hidden;' +
    'transition:width .2s cubic-bezier(.22,1,.36,1),opacity .18s ease}' +
    '#vol-wrap:hover #vol-range,#vol-wrap:focus-within #vol-range{width:76px;opacity:1}' +
    'body.is-muted #vol-range{width:42px;opacity:.45}' +
    '@media (hover:none),(pointer:coarse){#vol-range{display:none}}' +
    '#btn-speed{min-width:32px}' +
    '#buf{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;' +
    'z-index:6;pointer-events:none}' +
    '.buf-ring{width:38px;height:38px;border-radius:50%;' +
    'border:3px solid rgba(255,245,245,.18);border-top-color:var(--acc2);' +
    'animation:egspin .85s linear infinite}' +
    '@keyframes egspin{to{transform:rotate(360deg)}}' +
    '#time-lbl{border:1px solid rgba(255,255,255,.12);font-family:inherit;line-height:1.2;font-variant-numeric:tabular-nums;font-weight:700;color:rgba(255,245,245,.96);font-size:13.5px;white-space:nowrap;cursor:pointer;padding:3px 8px;border-radius:999px;background:rgba(14,8,18,.64);backdrop-filter:blur(8px);transition:background .15s ease}' +
    'body.is-cinema #time-lbl{background:rgba(12,12,16,.72)}#time-lbl:hover{background:rgba(28,16,36,.82)}' +
    '#stats-card{position:fixed;top:62px;left:26px;padding:8px 12px;border-radius:10px;background:rgba(10,10,16,.84);backdrop-filter:blur(10px);' +
    'border:1px solid rgba(255,255,255,.14);font-size:11px;line-height:1.5;color:#e5e7eb;font-variant-numeric:tabular-nums;z-index:9;pointer-events:none}' +
    '#stats-card[hidden]{display:none!important}' +
    '#toast{position:fixed;top:22px;left:50%;transform:translateX(-50%) translateY(-8px);' +
    'display:inline-flex;align-items:center;gap:8px;padding:6px 14px;border-radius:999px;background:var(--bg-menu);backdrop-filter:blur(12px);' +
    'border:1px solid var(--acc-ring);color:#fff;font-size:12px;font-weight:700;' +
    'z-index:11;pointer-events:none;opacity:0;transition:opacity .18s ease,transform .18s ease}' +
    '#toast.on{opacity:1;transform:translateX(-50%) translateY(0)}' +
    'body.is-fs #toast{top:56px}' +
    '#toast.act{pointer-events:auto}' +
    '#toast button{border:0;background:var(--acc-soft);color:#fff;padding:2px 9px;border-radius:999px;font-size:11px;font-weight:800;cursor:pointer;font-family:inherit}' +
    '#toast button:hover{background:var(--acc2)}' +
    '#gesture-hud{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);display:flex;align-items:center;gap:10px;' +
    'padding:10px 16px;border-radius:999px;background:var(--bg-menu);backdrop-filter:blur(12px);' +
    'border:1px solid var(--acc-ring);color:#fff;font-size:13px;font-weight:800;z-index:10;pointer-events:none}' +
    '.g-bar{width:72px;height:4px;border-radius:999px;background:rgba(255,255,255,.2);overflow:hidden}' +
    '.g-bar i{display:block;height:100%;background:linear-gradient(90deg,var(--acc),var(--acc2));border-radius:999px}' +
    'body.locked #hud,body.locked #binge,body.locked #q-menu,body.locked #cc-menu,body.locked #sp-menu,body.locked #more-menu,body.locked #sv-menu{opacity:0!important;pointer-events:none!important}' +
    'body.buffering .cplay{opacity:0;pointer-events:none}' +
    '#menu-backdrop{position:fixed;inset:0;background:rgba(6,3,10,.56);backdrop-filter:blur(2px);z-index:11}' +
    '#menu-backdrop[hidden]{display:none!important}' +
    '#speed-pill{position:fixed;top:18px;left:50%;transform:translateX(-50%);padding:6px 14px;border-radius:999px;' +
    'background:var(--bg-menu);border:1px solid var(--acc-ring);color:#fff;font-size:12px;font-weight:800;' +
    'z-index:12;pointer-events:none;box-shadow:0 6px 20px rgba(0,0,0,.6)}' +
    '#speed-pill[hidden]{display:none!important}' +
    '.menu-head{display:flex;align-items:center;justify-content:space-between;padding:2px 4px 6px;margin-bottom:4px;border-bottom:1px solid rgba(255,255,255,.12)}' +
    '.menu-head span{font-size:11.5px;font-weight:800;letter-spacing:.04em;color:#fff}' +
    '.menu-x{border:0;background:rgba(255,255,255,.08);color:#fff;width:28px;height:28px;border-radius:50%;cursor:pointer;font-size:14px;display:inline-flex;align-items:center;justify-content:center}' +
    '.menu-x:hover{background:var(--acc-soft)}' +
    '#unlock-w{position:fixed;left:50%;bottom:14px;transform:translateX(-50%);z-index:13;transition:opacity .2s ease}' +
    '#unlock-btn{border:1px solid var(--acc-ring);background:var(--bg-menu);backdrop-filter:blur(12px);' +
    'color:#fff;border-radius:999px;padding:6px 14px;font-size:11.5px;font-weight:800;cursor:pointer;font-family:inherit;' +
    'display:inline-flex;align-items:center;gap:6px;box-shadow:0 8px 24px rgba(0,0,0,.65)}' +
    '#unlock-btn:hover{background:var(--acc-soft)}' +
    '.chip{border:1px solid var(--acc-ring);background:rgba(18,10,24,.56);' +
    'backdrop-filter:blur(10px);color:#fff;border-radius:999px;padding:4px 11px;' +
    'font-size:11px;font-weight:700;cursor:pointer;font-family:inherit;font-variant-numeric:tabular-nums;' +
    'transition:background .15s ease,border-color .15s ease,color .15s ease,transform .2s cubic-bezier(.34,1.56,.64,1)}' +
    '.chip:active{transform:scale(.92)}' +
    '.chip:hover{background:var(--acc-soft);border-color:var(--acc-hi)}' +
    '.chip.on{border-color:var(--acc-hi);background:var(--acc-soft)}' +
    '#btn-sv::after,#tap-sv::after{content:" \\25be";opacity:.75;font-size:10px}' +
    '#btn-sv[data-sv]:not([data-sv=""])::after,#tap-sv[data-sv]:not([data-sv=""])::after{content:" \\00b7\\00a0" attr(data-sv) " \\25be";opacity:.88;font-size:10.5px}' +
    '#keys-menu{position:fixed;left:50%;top:50%;transform:translate(-50%,-50%);width:min(380px,calc(100vw - 24px));' +
    'background:var(--bg-menu);backdrop-filter:blur(18px);border:1px solid var(--acc-ring);border-radius:14px;' +
    'padding:10px 12px 12px;z-index:13;box-shadow:0 18px 42px rgba(0,0,0,.84)}' +
    '.k-grid{display:grid;grid-template-columns:1fr 1fr;gap:6px 14px;padding-top:4px}' +
    '.k-row{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:11px;color:#eae2e8}' +
    '.k-key{padding:2px 6px;border-radius:5px;background:rgba(255,255,255,.09);border:1px solid rgba(255,255,255,.14);' +
    'font-size:10px;font-weight:800;color:#fff;white-space:nowrap}' +
    '.ctrl-rt .chip{border-color:rgba(255,255,255,.16);background:rgba(255,255,255,.05);backdrop-filter:none;' +
    'border-radius:6px;padding:4px 8px;font-size:13.5px;font-weight:800;color:rgba(255,245,245,.9)}' +
    '.ctrl-rt .chip:hover{background:var(--acc-hover);border-color:transparent;color:#fff}' +
    '.ctrl-rt .chip.on{color:var(--acc-hi);background:var(--acc-soft);border-color:var(--acc-ring)}' +
    '.eg-badge{display:inline-flex;align-items:center;gap:6px;margin-left:8px;padding-left:8px;border-left:1px solid rgba(255,255,255,.18);opacity:.94}' +
    '.eg-cat{width:16px;height:16px;border-radius:50%;object-fit:cover;' +
    'border:1.5px solid var(--acc-ring);flex-shrink:0}' +
    '.eg-w{font-family:"Bebas Neue",Impact,sans-serif;font-size:13.5px;letter-spacing:.07em;line-height:1}' +
    '.eg-w b{color:#fff;font-weight:400}' +
    '.eg-w i{color:var(--acc-hi);font-style:normal;text-shadow:0 2px 10px var(--acc-glow)}' +
    '#q-menu,#cc-menu,#sp-menu,#sv-menu,#more-menu{position:fixed;right:26px;bottom:94px;width:196px;' +
    'background:var(--bg-menu);backdrop-filter:blur(18px);' +
    'border:1px solid var(--acc-ring);border-radius:12px;' +
    'padding:8px;z-index:12;box-shadow:0 16px 36px rgba(0,0,0,.78);transform-origin:bottom right}' +
    '#q-menu:not([hidden]),#cc-menu:not([hidden]),#sp-menu:not([hidden]),#more-menu:not([hidden]){animation:egmenu .22s cubic-bezier(.22,1,.36,1)}' +
    '#sv-menu{top:62px;bottom:auto;transform-origin:top right}' +
    '#sv-menu:not([hidden]){animation:egmenud .22s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egmenu{from{opacity:0;transform:translateY(10px) scale(.95)}to{opacity:1;transform:none}}' +
    '@keyframes egmenud{from{opacity:0;transform:translateY(-10px) scale(.95)}to{opacity:1;transform:none}}' +
    '.qi{display:flex;justify-content:space-between;align-items:center;width:100%;border:0;' +
    'background:transparent;color:#eae2e8;padding:6px 8px;border-radius:6px;font-size:11.5px;' +
    'font-weight:600;cursor:pointer;font-family:inherit;text-align:left;' +
    'transition:background .12s ease,color .12s ease,transform .16s cubic-bezier(.34,1.56,.64,1)}' +
    '.qi:active{transform:scale(.96)}' +
    '.qi:hover{background:var(--acc-hover);color:#fff}' +
    '.qi.on{background:var(--acc-soft);color:#fff}' +
    '#cc-menu{width:min(460px,calc(100vw - 24px));max-height:70vh;overflow-y:auto}' +
    '.cc-langs{max-height:176px;overflow-y:auto;margin-bottom:4px;padding:0 2px 10px 0;scrollbar-width:thin;scrollbar-color:rgba(255,255,255,.28) transparent;-webkit-mask-image:linear-gradient(to bottom,#000 calc(100% - 22px),transparent);mask-image:linear-gradient(to bottom,#000 calc(100% - 22px),transparent)}' +
    '.cc-filter{width:100%;border:1px solid rgba(255,255,255,.14);background:rgba(255,255,255,.06);color:#fff;' +
    'border-radius:7px;padding:5px 8px;font-size:11px;font-family:inherit;margin-bottom:4px;outline:none}' +
    '.cc-filter:focus{border-color:var(--acc-hi)}' +
    '#more-menu{width:min(416px,calc(100vw - 24px));max-height:calc(100vh - 96px);overflow-y:auto}' +
    '.more-grid{display:grid;grid-template-columns:1fr 1fr;gap:4px 12px;align-items:start}' +
    '.more-col{min-width:0}' +
    '#sv-menu{max-height:calc(100vh - 76px);overflow-y:auto}' +
    '@media (hover:none),(pointer:coarse){#c-transport{display:flex}#btn-play,#btn-rew,#btn-ff{display:none}}' +
    '@media (prefers-reduced-motion:reduce){*:not(.wc):not(.buf-ring):not(#pv-load i){animation:none!important;transition:none!important}}' +
    '.cc-h{font-size:9.5px;font-weight:800;letter-spacing:.09em;text-transform:uppercase;' +
    'color:rgba(255,255,255,.6);padding:6px 6px 3px}' +
    '.cc-row{display:flex;gap:4px;align-items:center;padding:0 2px 4px;flex-wrap:wrap}' +
    '.cc-row .qi,#more-menu .qi{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.08)}' +
    '.cc-row .qi.on,#more-menu .qi.on{background:var(--acc-soft);border-color:var(--acc-ring)}' +
    '.cc-row .qi{width:auto;flex:1 1 auto;min-width:30px;justify-content:center;padding:5px 6px;text-align:center;white-space:nowrap}' +
    '#more-menu .cc-row .qi{min-width:0;padding:5px 4px}' +
    '.chip[hidden]{display:none}#btn-more{display:inline-flex}' +
    '@media (max-width:640px),(max-height:430px){.h-top{padding:8px 12px}.h-top-r{gap:5px}.eg-cat{width:17px;height:17px}.sd-b{padding:2px 7px;font-size:10px}#btn-sv{padding:2px 7px;font-size:10px;max-width:136px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}body.ios-vol #btn-vol{display:none}.h-top-l{flex:0 1 auto;gap:6px;min-width:0;max-width:none;padding:3px 9px 3px 5px}' +
    'body.is-cinema .h-top-l{padding:4px 11px}.eg-badge{display:none}#hud-title,#hud-ep{font-size:12.5px}.h-bot{padding:0 12px 6px;gap:2px}' +
    '#c-transport{display:flex;top:46%;gap:20px}.cplay{width:50px;height:50px}.cplay svg{width:22px;height:22px}.c-sec{width:38px;height:38px}.c-sec svg{width:18px;height:18px}.ctrl-r{gap:4px}#btn-play,#btn-rew,#btn-ff,#vol-range,#btn-pip,#btn-q{display:none}' +
    '.ctrl-l{gap:4px}.ctrl-rt{justify-content:flex-end;gap:4px}' +
    '.ib{padding:6px;min-width:44px;min-height:40px}.ib svg{width:20px;height:20px}#btn-lock{position:relative;background:rgba(14,8,18,.58);backdrop-filter:blur(8px);border:1px solid var(--acc-ring);min-width:32px;min-height:32px;width:32px;height:32px;padding:0}#btn-lock::before{content:"";position:absolute;inset:-6px}body.is-cinema #btn-lock{border-color:rgba(255,255,255,.16)}.bar-row{gap:12px}#scrub-wrap{padding:6px 10px 2px 8px}' +
    '#time-lbl{font-size:11px;padding:2px 6px}#binge{padding:0 12px;bottom:92px}body.idle #binge{bottom:12px}' +
    '.b-act{padding:5px 11px 7px;font-size:11.5px;gap:6px}.b-next{padding:0 8px 0 0;gap:3px}.b-main{padding:5px 3px 7px 11px;gap:6px}.b-u{left:12px;right:12px;bottom:3px}' +
    '#sub-box{width:90%;bottom:calc(62px + var(--sub-lift,0px) + var(--sub-pos,0px))}body.idle #sub-box,body.locked #sub-box{bottom:calc(12px + var(--sub-idle-lift,0px) + var(--sub-pos,0px))}' +
    '#sub-txt{font-size:calc(clamp(12px,3.2vw,17px)*var(--sub-scale,1))}' +
    '#scrub-prev{width:124px;bottom:20px}.pv-meta{padding:1px 7px}#pv-time{font-size:10.5px}' +
    '#q-menu,#sp-menu{right:12px;bottom:64px}#sv-menu{right:12px;top:46px}' +
    '.chip{padding:3px 8px;font-size:10.5px}.ctrl-rt .chip{padding:3px 6px;font-size:12px}' +
    '#cc-menu,#more-menu{left:50%;top:50%;right:auto;bottom:auto;transform:translate(-50%,-50%);width:min(416px,calc(100vw - 14px));max-height:calc(100vh - 14px);padding:8px 10px 12px;border-radius:14px}' +
    '#cc-menu .qi,#more-menu .qi{min-height:36px;padding:5px 4px;font-size:10.5px}.menu-x{width:32px;height:32px;font-size:14px}.cc-row .qi{min-width:0}#cc-menu .cc-langs{max-height:92px}' +
    '#more-menu .cc-h,#cc-menu .cc-h{padding:4px 4px 2px;font-size:8.5px}' +
    '#cc-menu:not([hidden]),#more-menu:not([hidden]){animation:egsheet .18s cubic-bezier(.22,1,.36,1)}}' +
    '@keyframes egsheet{from{opacity:0;transform:translate(-50%,-46%) scale(.96)}to{opacity:1;transform:translate(-50%,-50%) scale(1)}}' +
    '@media (max-height:320px){#cc-menu,#more-menu{max-height:calc(100vh - 8px);padding:5px 10px 8px;overflow-y:auto;scrollbar-width:thin;scrollbar-color:rgba(255,255,255,.3) transparent}' +
    '#cc-menu .cc-langs{max-height:74px;scrollbar-width:thin;scrollbar-color:rgba(255,255,255,.3) transparent}' +
    '#more-menu .menu-head,#cc-menu .menu-head{padding:0 2px 3px;margin-bottom:2px}.menu-x{width:32px;height:32px;font-size:13px}' +
    '#more-menu .cc-h,#cc-menu .cc-h{padding:2px 4px 1px;font-size:8px}#more-menu .cc-row,#cc-menu .cc-row{padding:0 2px 2px}' +
    '#more-menu .qi,#cc-menu .qi{min-height:29px;padding:2px 5px;font-size:10.5px}}' +
    '@media (max-width:480px){#btn-sv[data-sv]:not([data-sv=""]){font-size:0}#btn-sv[data-sv]:not([data-sv=""])::after{content:attr(data-sv) " \\25be";font-size:10px}#btn-speed:not(.on){display:none}.ctrl-r{gap:0}.ctrl-l{flex:0 0 auto}.ctrl-rt{flex:1;justify-content:space-between;padding-left:20px;gap:2px}.ib{min-width:44px;min-height:40px}}' +
    '@media (max-height:300px){#c-transport{top:30%;gap:20px}.cplay{width:38px;height:38px}.cplay svg{width:17px;height:17px}' +
    '.c-sec{width:32px;height:32px}.c-sec svg{width:15px;height:15px}' +
    '#binge{bottom:76px}body.idle #binge{bottom:12px}' +
    '#sub-txt{font-size:calc(clamp(11px,2.8vw,13px)*var(--sub-scale,1));line-height:1.28}' +
    '#unlock-w{bottom:6px}#unlock-btn{padding:4px 10px;font-size:11px}' +
    'body.sub-top #sub-box{top:44px;bottom:auto}' +
    '#flash{width:58px;height:58px;margin:-29px 0 0 -29px}#flash svg{width:22px;height:22px}#stats-card{top:44px;left:12px}}' +
    '</style></head><body' + (isCinema ? ' class="is-cinema"' : '') + '>' +
    '<video id="v" playsinline autoplay preload="auto" crossorigin="anonymous">' +
    (trackTags ? '\n    ' + trackTags : '') +
    '</video>\n' +
    '<div id="sub-box"><span id="sub-txt"></span></div>\n' +
    '<div id="toast" role="status" aria-live="polite"></div>\n' +
    '<div id="speed-pill" hidden>2\u00d7 Speed &raquo;</div>\n' +
    '<div id="gesture-hud" hidden></div>\n' +
    '<div id="menu-backdrop" hidden></div>\n' +
    '<div id="unlock-w" hidden><button type="button" id="unlock-btn" aria-label="Unlock controls"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;color:var(--acc-hi)"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg><span>Tap to unlock</span></button></div>\n' +
    '<div id="stats-card" hidden></div>\n' +
    '<div id="hud">' +
    '<div class="h-top">' +
    '<div class="h-top-l">' +
    '<button type="button" class="ib" id="btn-back" aria-label="Exit fullscreen" title="Exit fullscreen">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:18px;height:18px"><path d="M15 18l-6-6 6-6"/></svg></button>' +
    (isCinema ? '' : '<img class="eg-cat" src="https://everglow-1c6db.web.app/favicon.png" alt="">') +
    '<span class="h-title-wrap"><span id="hud-title">' + hudMain + '</span><span id="hud-ep"' + (hudEp ? '' : ' hidden') + '>' + hudEp + '</span></span>' +
    (isCinema ? '' : '<span class="eg-badge"><span class="eg-w"><b>EVER</b><i>GLOW</i></span></span>') +
    '</div>' +
    '<div class="h-top-r">' +
    '<button type="button" class="chip" id="btn-sv" aria-haspopup="true"' +
    (serverList.length > 1 ? '' : ' hidden') + '>Servers</button>' +
    (isCinema
      ? ''
      : '<div class="sd-box" role="group" aria-label="Audio language">' +
        '<button type="button" class="sd-b' + (isDub ? '' : ' on') + '" id="btn-sub" aria-pressed="' + (!isDub) + '">SUB</button>' +
        '<button type="button" class="sd-b' + (isDub ? ' on' : '') + '" id="btn-dub" aria-pressed="' + (!!isDub) + '">DUB</button>' +
        '</div>') +
    '<button type="button" class="ib" id="btn-lock" aria-label="Lock screen" title="Lock screen">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:18px;height:18px"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg></button>' +
    '</div></div>' +
    '<div id="c-transport">' +
    '<button type="button" class="c-sec" id="c-rew" aria-label="Rewind 10 seconds">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">' + SEEK_ARC.rew + '<text id="c-rew-lbl" x="12" y="15.3" text-anchor="middle" fill="currentColor" stroke="none" font-family="system-ui,sans-serif" font-size="7.5" font-weight="800">10</text></svg></button>' +
    '<button type="button" class="cplay" id="cplay" aria-label="Play or pause">' +
    '<svg viewBox="0 0 20 20"><path id="cplay-p" fill="currentColor" d="M4 3h3.5v14H4zM12.5 3H16v14h-3.5z"/></svg></button>' +
    '<button type="button" class="c-sec" id="c-ff" aria-label="Forward 10 seconds">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">' + SEEK_ARC.ff + '<text id="c-ff-lbl" x="12" y="15.3" text-anchor="middle" fill="currentColor" stroke="none" font-family="system-ui,sans-serif" font-size="7.5" font-weight="800">10</text></svg></button>' +
    '</div>' +
    '<div class="h-bot">' +
    '<div class="bar-row">' +
    '<div id="scrub-wrap">' +
    '<div id="scrub-prev" hidden>' +
    '<div class="pv-box"><video id="pv" muted playsinline preload="none" crossorigin="anonymous"></video><canvas id="pv-c" hidden></canvas><div id="pv-load"><i></i></div></div>' +
    '<div class="pv-meta"><span id="pv-time">00:00</span><span id="pv-tag" hidden></span></div>' +
    '</div>' +
    '<div id="scrub" role="slider" tabindex="0" aria-label="Seek timeline" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" aria-valuetext="00:00">' +
    '<div id="s-buf"></div>' +
    '<div id="s-hover"></div>' +
    '<div id="s-fill"></div>' +
    '<div class="s-chap" id="s-op" hidden></div>' +
    '<div class="s-chap" id="s-ed" hidden></div>' +
    '<div id="s-thumb"></div>' +
    '</div>' +
    '</div>' +
    '<button type="button" id="time-lbl" aria-label="Toggle elapsed or remaining time" title="Tap to toggle elapsed / -remaining">00:00</button>' +
    '</div>' +
    '<div class="ctrl-r">' +
    '<div class="ctrl-l">' +
    '<button type="button" class="ib" id="btn-play" aria-label="Play or pause" title="Play / Pause (Space)">' +
    '<svg viewBox="0 0 20 20"><path id="play-p" fill="currentColor" d="M4 3h3.5v14H4zM12.5 3H16v14h-3.5z"/></svg></button>' +
    '<button type="button" class="ib" id="btn-rew" aria-label="Rewind 10 seconds" title="Rewind (J / \u2190)">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><text id="rew-lbl" x="12" y="15.3" text-anchor="middle" fill="currentColor" stroke="none" font-family="system-ui,sans-serif" font-size="7.5" font-weight="800">10</text></svg></button>' +
    '<button type="button" class="ib" id="btn-ff" aria-label="Forward 10 seconds" title="Forward (L / \u2192)">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><text id="ff-lbl" x="12" y="15.3" text-anchor="middle" fill="currentColor" stroke="none" font-family="system-ui,sans-serif" font-size="7.5" font-weight="800">10</text></svg></button>' +
    '<span id="vol-wrap">' +
    '<button type="button" class="ib" id="btn-vol" aria-label="Mute or unmute" title="Mute (M)">' +
    '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><polygon points="9 4 5 7.5 2 7.5 2 12.5 5 12.5 9 16 9 4" fill="currentColor"/><path id="vol-w" d="M12.5 7a4 4 0 0 1 0 6M15 4.8a7.2 7.2 0 0 1 0 10.4"/><path id="vol-x" d="M12.5 7.5l4.5 5M17 7.5l-4.5 5" hidden/></svg></button>' +
    '<input type="range" id="vol-range" min="0" max="1" step="0.01" value="1" aria-label="Volume">' +
    '</span>' +
    '</div>' +
    '<div class="ctrl-rt">' +
    '<button type="button" class="ib" id="btn-nx" aria-label="Next episode" title="Next episode (N)" hidden>' +
    '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M4 5l10 7-10 7zM16 5h3v14h-3z"/></svg></button>' +
    (showEps
      ? '<button type="button" class="ib" id="btn-eps" aria-label="Episodes" title="Episodes">' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6h11M4 11h11M4 16h7"/><polygon points="15 13 20 16.5 15 20" fill="currentColor" stroke="none"/></svg></button>'
      : '') +
    '<button type="button" class="ib on" id="btn-cc" aria-label="Subtitles" title="Subtitles & Audio (C)" aria-haspopup="true"' +
    (trackTags ? '' : ' hidden') + '>' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"><path d="M4 5h16v11H9l-5 4z"/><path d="M8 9.5h3M13 9.5h3M8 12.5h6" stroke-linecap="round"/></svg></button>' +
    '<button type="button" class="chip" id="btn-speed" aria-label="Playback speed" title="Speed ([ / ])" aria-haspopup="true">1x</button>' +
    '<button type="button" class="chip" id="btn-q" aria-label="Quality" title="Video quality">Auto</button>' +
    '<button type="button" class="ib" id="btn-pip" aria-label="Picture in picture" title="Picture-in-Picture">' +
    '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="4" width="15" height="12" rx="2"/><rect x="10.2" y="9.4" width="6" height="4.8" rx="1" fill="currentColor" stroke="none"/></svg></button>' +
    '<button type="button" class="ib" id="btn-more" aria-label="Player settings" title="Settings & Shortcuts (?)" aria-haspopup="true">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h.09a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v.09a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg></button>' +
    '<button type="button" class="ib" id="btn-fs" aria-label="Fullscreen" title="Fullscreen (F)">' +
    '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path id="fs-p" d="M3 7V3h4M17 7V3h-4M3 13v4h4M17 13v4h-4"/></svg></button>' +
    '</div></div></div></div>\n' +
    '<div id="flash"></div>\n' +
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
    '<div class="b-act b-next" id="btn-next" role="region" aria-label="Up next" hidden>' +
    '<button type="button" class="b-main" id="btn-next-go">' +
    '<span class="b-ico"><svg width="15" height="15" viewBox="0 0 20 20" fill="none" ' +
    'stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">' +
    '<polygon points="5 4.5 13 10 5 15.5 5 4.5" fill="currentColor" stroke="none"/></svg></span>' +
    '<span id="next-lbl">Next episode</span>' +
    '<span class="b-t" id="next-tok"></span>' +
    '<span class="b-t" id="next-cd"></span>' +
    '</button>' +
    '<button type="button" id="btn-next-x" class="b-x" aria-label="Dismiss next episode" title="Dismiss">\u2715</button>' +
    '<span class="b-u"><i id="next-fill"></i></span>' +
    '</div>' +
    '</div>\n' +
    '<div id="q-menu" role="menu" aria-label="Video quality" hidden></div>\n' +
    '<div id="cc-menu" role="menu" aria-label="Subtitles and audio" hidden></div>\n' +
    '<div id="sp-menu" role="menu" aria-label="Playback speed" hidden></div>\n' +
    '<div id="more-menu" role="menu" aria-label="Player settings" hidden></div>\n' +
    '<div id="sv-menu" role="menu" aria-label="Stream mirrors" hidden></div>\n' +
    '<div id="keys-menu" role="dialog" aria-label="Keyboard shortcuts" hidden></div>\n' +
    '<div id="buf" hidden><div class="buf-ring"></div></div>\n' +
    '<div class="ov" id="boot">' +
    (isCinema
      ? '<div class="buf-ring" style="width:44px;height:44px" aria-label="Loading stream"></div>'
      : '<div class="eg-wave" aria-label="Everglow loading">' +
        '<span class="wc e">E</span><span class="wc e">V</span><span class="wc e">E</span><span class="wc e">R</span>' +
        '<span class="wc g">G</span><span class="wc g">L</span><span class="wc g">O</span><span class="wc g">W</span>' +
        '</div>') +
    '</div>\n' +
    '<div class="ov" id="tapw" hidden>' +
    '<img id="tap-art" alt=""' + (posterUrl ? ' src="' + escHtml(posterUrl) + '"' : ' hidden') + '>' +
    '<div id="tap-sub">' + (isCinema ? 'Cinema Stream' : 'Ready to Watch') + '</div>' +
    '<div id="tap-title">' + displayTitle + '</div>' +
    '<button id="tap">&#9654; <span>Tap to play</span></button>' +
    ((serverList.length > 1 || !isCinema)
      ? '<div id="tap-opts">' +
        (serverList.length > 1
          ? '<button type="button" class="chip" id="tap-sv">Servers</button>'
          : '') +
        (isCinema
          ? ''
          : '<div class="sd-box" role="group" aria-label="Audio language">' +
            '<button type="button" class="sd-b' + (isDub ? '' : ' on') + '" id="tap-sub-b">SUB</button>' +
            '<button type="button" class="sd-b' + (isDub ? ' on' : '') + '" id="tap-dub-b">DUB</button>' +
            '</div>') +
        '</div>'
      : '') +
    '</div>\n' +
    '<div class="ov" id="dead" hidden>' +
    '<p style="font-size:15px;margin:0 0 6px">This stream stalled.</p>' +
    '<p style="font-size:12px;color:#d5adb9;margin:0">' +
    (serverList.length > 1
      ? 'Switch to another server or retry playback.'
      : 'Try another server below or retry playback.') + '</p>' +
    '<div class="dead-acts">' +
    (serverList.length > 1
      ? '<button type="button" id="dead-sv">Switch server</button>'
      : '') +
    '<button type="button" onclick="location.reload()">Retry</button></div></div>\n' +
    '<script src="https://cdn.jsdelivr.net/npm/hls.js@1"></script>\n' +
    '<script>(function(){var src=' + safeScriptJson(src) + ';var v=' +
    'document.getElementById("v");' +
    'var servers=' + safeScriptJson(serverList) + ';' +
    'var currentServer=' + safeScriptJson(currentServer) + ';' +
    'var btnSv=document.getElementById("btn-sv");' +
    'var svMenu=document.getElementById("sv-menu");' +
    'var boot=document.getElementById("boot");' +
    'var tapw=document.getElementById("tapw");' +
    'var tapArt=document.getElementById("tap-art");' +
    'var tap=document.getElementById("tap");' +
    'var dead=document.getElementById("dead");' +
    'var hudTitle=document.getElementById("hud-title");var hudEp=document.getElementById("hud-ep");' +
    'var scrubWrap=document.getElementById("scrub-wrap");' +
    'var scrubPrev=document.getElementById("scrub-prev");' +
    'var pv=document.getElementById("pv");' +
    'var pvCanvas=document.getElementById("pv-c");' +
    'var pvTime=document.getElementById("pv-time");' +
    'var pvTag=document.getElementById("pv-tag");' +
    'var sFill=document.getElementById("s-fill");' +
    'var sBuf=document.getElementById("s-buf");' +
    'var sHover=document.getElementById("s-hover");' +
    'var sThumb=document.getElementById("s-thumb");' +
    'var sOp=document.getElementById("s-op");' +
    'var sEd=document.getElementById("s-ed");' +
    'var scrub=document.getElementById("scrub");' +
    'var activeSrc=src;' +
    'var timeLbl=document.getElementById("time-lbl");' +
    'var btnPlay=document.getElementById("btn-play");' +
    'var playP=document.getElementById("play-p");' +
    'var btnRew=document.getElementById("btn-rew");' +
    'var btnFf=document.getElementById("btn-ff");' +
    'var rewLbl=document.getElementById("rew-lbl");' +
    'var ffLbl=document.getElementById("ff-lbl");' +
    'var cRew=document.getElementById("c-rew");' +
    'var cFf=document.getElementById("c-ff");' +
    'var cRewLbl=document.getElementById("c-rew-lbl");' +
    'var cFfLbl=document.getElementById("c-ff-lbl");' +
    'var statsCard=document.getElementById("stats-card");' +
    'var tapTitle=document.getElementById("tap-title");' +
    'var btnVol=document.getElementById("btn-vol");' +
    'var volW=document.getElementById("vol-w");' +
    'var volX=document.getElementById("vol-x");' +
    'var btnCc=document.getElementById("btn-cc");' +
    'var ccMenu=document.getElementById("cc-menu");' +
    'var btnSpeed=document.getElementById("btn-speed");' +
    'var spMenu=document.getElementById("sp-menu");' +
    'var btnMore=document.getElementById("btn-more");' +
    'var moreMenu=document.getElementById("more-menu");' +
    'var keysMenu=document.getElementById("keys-menu");' +
    'var nextCd=document.getElementById("next-cd");' +
    'var btnPip=document.getElementById("btn-pip");' +
    'var volRange=document.getElementById("vol-range");' +
    'var buf=document.getElementById("buf");' +
    'var btnQ=document.getElementById("btn-q");' +
    'var qMenu=document.getElementById("q-menu");' +
    'var btnFs=document.getElementById("btn-fs");' +
    'var fsP=document.getElementById("fs-p");' +
    'var btnSkip=document.getElementById("btn-skip");' +
    'var btnNext=document.getElementById("btn-next");' +
    'var btnNextX=document.getElementById("btn-next-x");' +
    'var btnSub=document.getElementById("btn-sub");' +
    'var btnDub=document.getElementById("btn-dub");' +
    'var btnEps=document.getElementById("btn-eps");' +
    'var btnNx=document.getElementById("btn-nx");' +
    'var deadSv=document.getElementById("dead-sv");' +
    'var toastEl=document.getElementById("toast");' +
    'var speedPill=document.getElementById("speed-pill");' +
    'var menuBackdrop=document.getElementById("menu-backdrop");' +
    'var gestureHud=document.getElementById("gesture-hud");' +
    'var btnLock=document.getElementById("btn-lock");' +
    'var btnBack=document.getElementById("btn-back");' +
    'var unlockW=document.getElementById("unlock-w");' +
    'var unlockBtn=document.getElementById("unlock-btn");' +
    'var cplay=document.getElementById("cplay");' +
    'var cplayP=document.getElementById("cplay-p");' +
    'var flashEl=document.getElementById("flash");' +
    'var FLASH=' + JSON.stringify(FLASH_ICONS) + ';' +
    'var isCinema=' + JSON.stringify(isCinema) + ';' +
    'var screenLocked=false,unlockHideT=null,audioTracks=[],inTheater=false,lastMenuBtn=null,statsOn=false,ccQuery="",nextDismissed=false;' +
    'var isIos=false;try{isIos=/iPad|iPhone|iPod/.test(navigator.userAgent||"")||(navigator.platform==="MacIntel"&&(navigator.maxTouchPoints||0)>1);}catch(e){}' +
    'var volLocked=isIos;' +
    'if(volLocked&&document.body&&document.body.classList)document.body.classList.add("ios-vol");' +
    'function compactSheet(){var w=window.innerWidth||0,h=window.innerHeight||0;return (w>0&&w<=640)||(h>0&&h<=430);}' +
    'if(document.body&&document.body.classList&&v.paused)document.body.classList.add("is-paused");' +
    'function kick(el,cls){if(!el||!el.classList)return;el.classList.remove(cls);' +
    'void el.offsetWidth;el.classList.add(cls);}' +
    'var toastT=null;function showToast(msg,actLabel,actFn){if(!toastEl)return;toastEl.innerHTML="";' +
    'var sp=document.createElement("span");sp.textContent=msg;toastEl.appendChild(sp);' +
    'if(actLabel&&actFn){var ab=document.createElement("button");ab.type="button";ab.textContent=actLabel;' +
    'ab.onclick=function(){if(toastEl.classList){toastEl.classList.remove("on");toastEl.classList.remove("act");}actFn();};toastEl.appendChild(ab);}' +
    'if(toastEl.classList){toastEl.classList.add("on");toastEl.classList.toggle("act",!!(actLabel&&actFn));}' +
    'if(typeof clearTimeout==="function"&&toastT)clearTimeout(toastT);' +
    'if(typeof setTimeout==="function"){toastT=setTimeout(function(){' +
    'if(toastEl.classList){toastEl.classList.remove("on");toastEl.classList.remove("act");}},actLabel?4000:1400);}}' +
    'function flash(kind,lbl){if(!flashEl||!flashEl.classList||!FLASH[kind])return;' +
    'if((kind==="play"||kind==="pause")&&!finePointer)return;' +
    'var html=FLASH[kind];if((kind==="rew"||kind==="ff")&&(lbl||(prefs&&prefs.seek!==10))){html=html.replace(">10<",">"+(lbl||prefs.seek)+"<");}' +
    'flashEl.innerHTML=html;flashEl.className=kind==="rew"?"l":kind==="ff"?"r":"";' +
    'kick(flashEl,"go");}' +
    'var subTxt=document.getElementById("sub-txt");' +
    'var subBox=document.getElementById("sub-box");' +
    'var skipTime=document.getElementById("skip-time");' +
    'var skipFill=document.getElementById("skip-fill");' +
    'var nextLbl=document.getElementById("next-lbl");' +
    'var nextTok=document.getElementById("next-tok");' +
    'var nextFill=document.getElementById("next-fill");' +
    'var episode=' + JSON.stringify(epNum) + ';' +
    'var opRange=null,edRange=null,activeSkipEnd=null,autoSkippedOp=false,autoSkippedEd=false,hlsInst=null,hlsDead=false,makeHls=null,picking=false;' +
    'var prefs={cc:true,lang:0,delay:0,size:1,subBg:1,subColor:0,subPos:0,seek:10,autoSkip:false,autoSkipEd:false,timeElapsed:true,fit:0,bright:1,vol:1,muted:false,speed:1};' +
    'var ccOn=true,subPick=0;' +
    'function loadPrefs(){try{' +
    'var raw=window.localStorage&&window.localStorage.getItem("everglow.player.prefs");' +
    'if(!raw)return;var o=JSON.parse(raw);if(!o||typeof o!=="object")return;' +
    'if(typeof o.cc==="boolean")prefs.cc=o.cc;' +
    'if(typeof o.lang==="number"&&o.lang>=0)prefs.lang=Math.floor(o.lang);' +
    'if(typeof o.delay==="number"&&isFinite(o.delay))prefs.delay=Math.max(-10,Math.min(10,o.delay));' +
    'if(typeof o.size==="number")prefs.size=Math.max(0,Math.min(2,Math.floor(o.size)));' +
    'if(typeof o.subBg==="number")prefs.subBg=Math.max(0,Math.min(2,Math.floor(o.subBg)));' +
    'if(typeof o.subColor==="number")prefs.subColor=Math.max(0,Math.min(2,Math.floor(o.subColor)));' +
    'if(typeof o.subPos==="number")prefs.subPos=Math.max(0,Math.min(3,Math.floor(o.subPos)));' +
    'if(o.seek===5||o.seek===10)prefs.seek=o.seek;' +
    'if(typeof o.autoSkip==="boolean")prefs.autoSkip=o.autoSkip;' +
    'if(typeof o.autoSkipEd==="boolean")prefs.autoSkipEd=o.autoSkipEd;' +
    'if(typeof o.timeElapsed==="boolean")prefs.timeElapsed=o.timeElapsed;' +
    'if(typeof o.fit==="boolean")prefs.fit=o.fit?1:0;' +
    'else if(typeof o.fit==="number")prefs.fit=Math.max(0,Math.min(2,Math.floor(o.fit)));' +
    'if(typeof o.bright==="number"&&isFinite(o.bright))prefs.bright=Math.max(0.4,Math.min(1.25,o.bright));' +
    'if(typeof o.vol==="number"&&isFinite(o.vol))prefs.vol=Math.max(0,Math.min(1,o.vol));' +
    'if(typeof o.muted==="boolean")prefs.muted=o.muted;' +
    'if(typeof o.speed==="number"&&isFinite(o.speed)&&o.speed>=0.25&&o.speed<=2)prefs.speed=o.speed;}catch(e){}}' +
    'function savePrefs(){try{if(window.localStorage){' +
    'window.localStorage.setItem("everglow.player.prefs",JSON.stringify(prefs));}}catch(e){}}' +
    'function applySubSize(){if(!subTxt||!subTxt.style)return;' +
    'var s=[0.84,1,1.3][prefs.size]||1;' +
    'if(subTxt.style.setProperty){subTxt.style.setProperty("--sub-scale",String(s));' +
    'subTxt.style.setProperty("--sub-color",["#fff","#fde68a","#facc15"][prefs.subColor]||"#fff");}' +
    'else{subTxt.style.fontSize=(16*s)+"px";}' +
    'if(subBox&&subBox.style&&subBox.style.setProperty)subBox.style.setProperty("--sub-pos",([0,22,44,0][prefs.subPos]||0)+"px");' +
    'if(document.body&&document.body.classList)document.body.classList.toggle("sub-top",prefs.subPos===3);' +
    'if(subTxt.classList){subTxt.classList.toggle("bg-pill",prefs.subBg===1);' +
    'subTxt.classList.toggle("bg-box",prefs.subBg===2);}}' +
    'function applyFit(){if(!v||!v.classList)return;' +
    'v.classList.toggle("fill",prefs.fit===1);v.classList.toggle("zoom",prefs.fit===2);}' +
    'function applyBright(){if(v&&v.style)v.style.filter=Math.abs(prefs.bright-1)<0.02?"":("brightness("+prefs.bright.toFixed(2)+")");}' +
    'function setFit(mode){prefs.fit=typeof mode==="boolean"?(mode?1:0):Math.max(0,Math.min(2,Math.floor(mode||0)));' +
    'savePrefs();applyFit();buildMoreMenu();showToast("Screen: "+(["Fit","Fill","Zoom"][prefs.fit]||"Fit"));}' +
    'function setBright(b){if(!isFinite(b))return;prefs.bright=Math.round(Math.max(0.4,Math.min(1.25,b))*100)/100;savePrefs();applyBright();buildMoreMenu();showToast("Brightness: "+Math.round(prefs.bright*100)+"%");}' +
    'function applySeekStep(){var s=String(prefs.seek);' +
    'if(rewLbl)rewLbl.textContent=s;if(ffLbl)ffLbl.textContent=s;' +
    'if(cRewLbl)cRewLbl.textContent=s;if(cFfLbl)cFfLbl.textContent=s;' +
    'if(btnRew&&btnRew.setAttribute)btnRew.setAttribute("aria-label","Rewind "+s+" seconds");' +
    'if(btnFf&&btnFf.setAttribute)btnFf.setAttribute("aria-label","Forward "+s+" seconds");' +
    'if(cRew&&cRew.setAttribute)cRew.setAttribute("aria-label","Rewind "+s+" seconds");' +
    'if(cFf&&cFf.setAttribute)cFf.setAttribute("aria-label","Forward "+s+" seconds");}' +
    'function setSeekStep(n){if(n!==5&&n!==10)return;prefs.seek=n;savePrefs();applySeekStep();buildSpeedMenu();buildMoreMenu();showToast("Skip: "+n+"s");}' +
    'function setAutoSkip(on){prefs.autoSkip=!!on;savePrefs();buildMoreMenu();post({type:"animex-pref",key:"autoSkip",value:prefs.autoSkip});showToast(prefs.autoSkip?"Auto-skip intro: On":"Auto-skip intro: Off");}' +
    'function setAutoSkipEd(on){prefs.autoSkipEd=!!on;savePrefs();buildMoreMenu();post({type:"animex-pref",key:"autoNext",value:prefs.autoSkipEd});showToast(prefs.autoSkipEd?(isCinema?"Auto next: On":"Auto-next ending: On"):(isCinema?"Auto next: Off":"Auto-next ending: Off"));}' +
    'function updateStats(){if(!statsCard||!statsOn)return;' +
    'var res=(v.videoWidth&&v.videoHeight)?(v.videoWidth+"\u00d7"+v.videoHeight):"\u2014";' +
    'var lv=(hlsInst&&Array.isArray(hlsInst.levels)&&hlsInst.currentLevel>=0&&hlsInst.levels[hlsInst.currentLevel])?hlsInst.levels[hlsInst.currentLevel]:null;' +
    'var qual=lv&&lv.height?(lv.height+"p"+(lv.bitrate?" \u00b7 "+(lv.bitrate/1e6).toFixed(1)+" Mbps":"")):"Auto";' +
    'var bufSec=0;if(v.buffered){var ct=v.currentTime||0;for(var i=0;i<v.buffered.length;i++){try{if(ct>=v.buffered.start(i)-0.5&&v.buffered.end(i)-ct>bufSec)bufSec=v.buffered.end(i)-ct;}catch(e){}}}' +
    'var drop=0;try{var q=v.getVideoPlaybackQuality&&v.getVideoPlaybackQuality();if(q&&typeof q.droppedVideoFrames==="number")drop=q.droppedVideoFrames;}catch(e){}' +
    'statsCard.innerHTML="<b>Stream</b> "+res+" ("+qual+")<br><b>Buffer</b> "+bufSec.toFixed(1)+"s \u00b7 <b>Speed</b> "+speedLabel(prefs.speed)+(drop>0?" \u00b7 <b>Dropped</b> "+drop:"");}' +
    'function toggleStats(on){statsOn=on===undefined?!statsOn:!!on;if(statsCard)statsCard.hidden=!statsOn;if(statsOn)updateStats();if(moreMenu&&!moreMenu.hidden)buildMoreMenu();}' +
    'function setSvgVis(el,show){if(!el)return;el.hidden=!show;if(el.style)el.style.display=show?"":"none";if(show&&el.removeAttribute)el.removeAttribute("hidden");else if(!show&&el.setAttribute)el.setAttribute("hidden","");}' +
    'function syncVolIcon(){var muted=!!(v.muted||v.volume===0);' +
    'setSvgVis(volW,!muted);setSvgVis(volX,muted);' +
    'if(document.body&&document.body.classList)document.body.classList.toggle("is-muted",muted);' +
    'if(volRange){volRange.value=muted?"0":String(Number.isFinite(v.volume)?v.volume:prefs.vol);}' +
    'if(btnVol){btnVol.style.opacity=muted?"0.72":"0.94";if(btnVol.setAttribute)btnVol.setAttribute("aria-label",muted?"Unmute (M)":"Mute (M)");}}' +
    'function applyVolume(){try{v.volume=prefs.vol;v.muted=prefs.muted;}catch(e){}' +
    'if(volRange)volRange.value=String(prefs.vol);syncVolIcon();}' +
    'if(v&&v.addEventListener)v.addEventListener("volumechange",syncVolIcon);' +
    'var SPEEDS=[0.25,0.5,0.75,1,1.25,1.5,1.75,2];' +
    'function speedLabel(s){return(s===1?"1":String(s))+"x";}' +
    'function applySpeed(){try{v.playbackRate=prefs.speed;}catch(e){}' +
    'if(btnSpeed){btnSpeed.textContent=speedLabel(prefs.speed);' +
    'btnSpeed.classList.toggle("on",prefs.speed!==1);}}' +
    'function setSpeed(s){if(!isFinite(s))return;prefs.speed=s;savePrefs();' +
    'applySpeed();buildSpeedMenu();buildMoreMenu();}' +
    'function buildSpeedMenu(){if(!spMenu)return;spMenu.innerHTML="";' +
    'for(var i=0;i<SPEEDS.length;i++){(function(r){' +
    'spMenu.appendChild(ccBtn(speedLabel(r),r===prefs.speed,function(){setSpeed(r);}));})(SPEEDS[i]);}}' +
    'function mkCol(){var d=document.createElement("div");d.className="more-col";return d;}' +
    'function addMenuHeader(menu,label){' +
    'var hd=document.createElement("div");hd.className="menu-head";' +
    'var sp=document.createElement("span");sp.textContent=label;' +
    'var xb=document.createElement("button");xb.type="button";xb.className="menu-x";xb.textContent="\u2715";xb.setAttribute("aria-label","Close "+label);' +
    'xb.onclick=function(){closeMenus();};hd.appendChild(sp);hd.appendChild(xb);menu.appendChild(hd);}' +
    'function buildMoreMenu(){if(!moreMenu)return;moreMenu.innerHTML="";' +
    'addMenuHeader(moreMenu,"Player settings");' +
    'var narrow=compactSheet();' +
    'var grid=document.createElement("div");grid.className="more-grid";' +
    'var c1=mkCol(),c2=mkCol();' +
    'if(narrow){c1.appendChild(ccHead("Speed"));' +
    'var sr=ccRow();[0.75,1,1.25,1.5,2].forEach(function(r){' +
    'sr.appendChild(ccBtn(speedLabel(r),r===prefs.speed,function(){setSpeed(r);}));});c1.appendChild(sr);}' +
    'c1.appendChild(ccHead("Skip interval"));' +
    'var sk=ccRow();sk.appendChild(ccBtn("5s",prefs.seek===5,function(){setSeekStep(5);}));' +
    'sk.appendChild(ccBtn("10s",prefs.seek===10,function(){setSeekStep(10);}));c1.appendChild(sk);' +
    'function appendScreen(host){host.appendChild(ccHead("Screen"));' +
    'var ft=ccRow();[["Fit",0],["Fill",1],["Zoom",2]].forEach(function(pair){' +
    'ft.appendChild(ccBtn(pair[0],prefs.fit===pair[1],function(){setFit(pair[1]);}));});host.appendChild(ft);}' +
    'if(narrow)appendScreen(c1);' +
    'if(!isCinema){c1.appendChild(ccHead("Binge skip"));' +
    'var bgRow=ccRow();bgRow.appendChild(ccBtn(prefs.autoSkip?"Intro: Auto \u2713":"Intro: Off",prefs.autoSkip,function(){setAutoSkip(!prefs.autoSkip);}));' +
    'if(nextToken||nextKind==="season"){bgRow.appendChild(ccBtn(prefs.autoSkipEd?"Auto next: On":"Auto next: Off",prefs.autoSkipEd,function(){setAutoSkipEd(!prefs.autoSkipEd);}));}' +
    'if(!opRange){bgRow.appendChild(ccBtn("+85s",false,function(){closeMenus();seekBy(85);showToast("Jumped +85s");}));}' +
    'c1.appendChild(bgRow);}' +
    'else if(nextToken||nextKind==="season"){c1.appendChild(ccHead("Binge"));' +
    'var cbRow=ccRow();cbRow.appendChild(ccBtn(prefs.autoSkipEd?"Auto next: On":"Auto next: Off",prefs.autoSkipEd,function(){setAutoSkipEd(!prefs.autoSkipEd);}));' +
    'c1.appendChild(cbRow);}' +
    'c2.appendChild(ccHead("Brightness"));' +
    'var br=ccRow();[[0.5,"50%"],[0.75,"75%"],[1,"100%"],[1.25,"125%"]].forEach(function(pair){' +
    'br.appendChild(ccBtn(pair[1],Math.abs(prefs.bright-pair[0])<0.06,function(){setBright(pair[0]);}));});' +
    'c2.appendChild(br);' +
    'if(!narrow)appendScreen(c2);' +
    'if(!narrow){c2.appendChild(ccHead("Screen lock"));' +
    'var lkRow=ccRow();lkRow.appendChild(ccBtn("Lock screen",false,function(){closeMenus();setLocked(true);}));' +
    'c2.appendChild(lkRow);}' +
    'function isAutoQual(h){return !h||(typeof h.autoLevelEnabled==="boolean"?h.autoLevelEnabled:(typeof h.manualLevel==="number"?h.manualLevel===-1:h.currentLevel===-1));}' +
    'if(narrow){c2.appendChild(ccHead("Quality"));var qr=ccRow();' +
    'if(hlsInst&&Array.isArray(hlsInst.levels)&&hlsInst.levels.length>0){var autoQ=isAutoQual(hlsInst);' +
    'qr.appendChild(ccBtn("Auto",autoQ,function(){hlsInst.currentLevel=-1;if(btnQ)btnQ.textContent="Auto";buildMoreMenu();}));' +
    'var seenH={};hlsInst.levels.forEach(function(lv,idx){if(lv&&lv.height&&!seenH[lv.height]){seenH[lv.height]=1;' +
    'qr.appendChild(ccBtn(lv.height+"p",!autoQ&&hlsInst.currentLevel===idx,function(){hlsInst.currentLevel=idx;if(btnQ)btnQ.textContent=lv.height+"p";buildMoreMenu();}));}});' +
    '}else{qr.appendChild(ccBtn("Auto",true,function(){showToast("Adaptive quality");}));}' +
    'c2.appendChild(qr);}' +
    'var toolHost=narrow?c2:c1;toolHost.appendChild(ccHead("Tools"));var tr=ccRow();' +
    'if(narrow&&(nextToken||nextKind==="season")&&(!btnNx||btnNx.hidden)&&(!btnNext||btnNext.hidden))tr.appendChild(ccBtn("Next ep",false,function(){closeMenus();post({type:"animex-action",action:"next-episode"});}));' +
    'if(narrow&&pipSupported())tr.appendChild(ccBtn("PiP",false,function(){closeMenus();triggerPip();}));' +
    'if(!narrow&&keysMenu)tr.appendChild(ccBtn("Shortcuts (?)",false,function(){closeMenus();openKeysMenu();}));' +
    'tr.appendChild(ccBtn(statsOn?"Stats: On":"Stats: Off",statsOn,function(){toggleStats();}));toolHost.appendChild(tr);' +
    'grid.appendChild(c1);grid.appendChild(c2);moreMenu.appendChild(grid);}' +
    'function openKeysMenu(){if(!keysMenu)return;var wasOpen=!keysMenu.hidden;closeMenus();if(wasOpen)return;' +
    'keysMenu.innerHTML="";addMenuHeader(keysMenu,"Keyboard shortcuts");' +
    'var kg=document.createElement("div");kg.className="k-grid";' +
    '[["Space / K","Play / Pause"],["J / L","\u00b110s Seek"],["\u2190 / \u2192","Seek step"],["\u2191 / \u2193","Volume"],["M","Mute"],["F","Fullscreen"],["C","Captions"],["G / H","Sub delay"],["[ / ]","Speed"],["Z","Screen fit"],["I","Stream stats"],[", / .","Frame step"],(isCinema&&!opRange?["N","Next episode"]:["S / N","Skip / Next"]),["?","This guide"]].forEach(function(p){' +
    'var r=document.createElement("div");r.className="k-row";' +
    'var sp=document.createElement("span");sp.textContent=p[1];' +
    'var kb=document.createElement("span");kb.className="k-key";kb.textContent=p[0];' +
    'r.appendChild(sp);r.appendChild(kb);kg.appendChild(r);});' +
    'keysMenu.appendChild(kg);keysMenu.hidden=false;syncAria();' +
    'if(keysMenu.querySelector){var kx=keysMenu.querySelector("button");if(kx&&kx.focus)try{kx.focus();}catch(e){}}}' +
    'loadPrefs();ccOn=prefs.cc;subPick=prefs.lang;' +
    'if(btnCc)btnCc.classList.toggle("on",ccOn);' +
    'applySubSize();applyFit();applyBright();applySeekStep();applyVolume();applySpeed();placeSubs();' +
    'var nextToken=null,nextKind="episode",NEAR_END_SECONDS=90;' +
    'function fmt(s){if(!Number.isFinite(s)||s<0)return"00:00";' +
    'var h=Math.floor(s/3600),m=Math.floor(s%3600/60),sec=Math.floor(s%60);' +
    'return(h?h+":":"")+(m<10?"0":"")+m+":"+(sec<10?"0":"")+sec;}' +
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
    'function through(range,t){if(!range)return null;var span=range[1]-range[0];' +
    'if(!(span>0))return null;var p=(t-range[0])/span;' +
    'return Math.min(1,Math.max(0,p));}' +
    'function updateBingeScrim(){var has=((btnSkip&&!btnSkip.hidden)||(btnNext&&!btnNext.hidden));var sc=document.getElementById("b-scrim");if(sc){' +
    'sc.hidden=!has;}if(document.body&&document.body.classList)document.body.classList.toggle("has-binge",!!has);placeSubs();}' +
    'function updateSkipBtn(){if(!btnSkip)return;var t=v.currentTime;' +
    'if(opRange&&t>=opRange[0]&&t<opRange[1]){activeSkipEnd=opRange[1];' +
    'if(prefs.autoSkip&&!autoSkippedOp&&Number.isFinite(v.duration)){autoSkippedOp=true;' +
    'v.currentTime=Math.min(v.duration,opRange[1]);showToast("Skipped opening");btnSkip.hidden=true;updateBingeScrim();return;}' +
    'if(skipTime)skipTime.textContent=fmt(Math.max(0,opRange[1]-t));' +
    'var p=through(opRange,t);if(skipFill&&p!==null)skipFill.style.width=((1-p)*100)+"%";' +
    'btnSkip.hidden=false;updateBingeScrim();return;}' +
    'autoSkippedOp=false;activeSkipEnd=null;btnSkip.hidden=true;updateBingeScrim();}' +
    'function updateNextBtn(){var hasNext=!!nextToken||nextKind==="season";' +
    'if(!btnNext){if(btnNx)btnNx.hidden=!hasNext;return;}' +
    'if(!hasNext||nextDismissed){btnNext.hidden=true;if(btnNx)btnNx.hidden=!hasNext;updateBingeScrim();return;}' +
    'var t=v.currentTime,d=v.duration;' +
    'if(!Number.isFinite(t)||!Number.isFinite(d)||d<=0){btnNext.hidden=true;if(btnNx)btnNx.hidden=false;updateBingeScrim();return;}' +
    'var inEnding=!!edRange&&t>=edRange[0]&&t<edRange[1];' +
    'var nearEnd=(d-t)<=NEAR_END_SECONDS;' +
    'if(inEnding&&prefs.autoSkipEd&&!autoSkippedEd){autoSkippedEd=true;post({type:"animex-action",action:"next-episode"});return;}' +
    'if(!inEnding)autoSkippedEd=false;' +
    'if(!(inEnding||nearEnd)){btnNext.hidden=true;if(btnNx)btnNx.hidden=false;updateBingeScrim();return;}' +
    'if(nextLbl)nextLbl.textContent=nextKind==="season"?"Next season":"Next episode";' +
    'if(nextTok)nextTok.textContent=nextToken||"";' +
    'if(nextCd)nextCd.textContent=fmt(Math.max(0,d-t));' +
    'var p=inEnding?through(edRange,t):null;' +
    'if(p===null)p=1-Math.min(1,Math.max(0,(d-t)/NEAR_END_SECONDS));' +
    'if(nextFill)nextFill.style.width=((1-p)*100)+"%";' +
    'btnNext.hidden=false;if(btnNx)btnNx.hidden=true;updateBingeScrim();}' +
    'function updateBuffer(){if(!sBuf||!v.buffered||!Number.isFinite(v.duration)||v.duration<=0)return;' +
    'var t=Number.isFinite(v.currentTime)?v.currentTime:0,end=0;' +
    'for(var i=0;i<v.buffered.length;i++){try{if(t>=v.buffered.start(i)-0.5&&v.buffered.end(i)>end)end=v.buffered.end(i);}catch(e){}}' +
    'if(!end&&v.buffered.length>0){try{end=v.buffered.end(v.buffered.length-1);}catch(e){}}' +
    'sBuf.style.width=Math.min(100,Math.max(0,end/v.duration*100))+"%";}' +
    'v.addEventListener("progress",updateBuffer);' +
    'function formatTimeLabel(p,d){return prefs.timeElapsed?(fmt(p)+" / "+fmt(d)):("-"+fmt(Math.max(0,d-p)));}' +
    'if(timeLbl)timeLbl.addEventListener("click",function(){prefs.timeElapsed=!prefs.timeElapsed;savePrefs();updateUi();});' +
    'function updateUi(){var p=v.currentTime,d=v.duration;' +
    'if(Number.isFinite(p)&&Number.isFinite(d)&&d>0){' +
    'var pctStr=Math.min(100,Math.max(0,p/d*100))+"%";' +
    'if(sFill&&!dragging)sFill.style.width=pctStr;' +
    'if(sThumb&&!dragging)sThumb.style.left=pctStr;' +
    'if(timeLbl&&!dragging)timeLbl.textContent=formatTimeLabel(p,d);' +
    'if(scrub){scrub.setAttribute("aria-valuenow",String(Math.round(p)));' +
    'scrub.setAttribute("aria-valuemin","0");' +
    'scrub.setAttribute("aria-valuemax",String(Math.round(d)));' +
    'scrub.setAttribute("aria-valuetext",fmt(p)+" of "+fmt(d));}}' +
    'updateBuffer();renderCues();updateSkipBtn();updateNextBtn();updateStats();}' +
    'function applySeek(){if(!hasMetadata||pendingSeek===null||!Number.isFinite(v.duration)||v.duration<=0){return;}' +
    'var target=Math.min(pendingSeek,v.duration);' +
    'try{v.currentTime=target;pendingSeek=null;updateUi();' +
    'if(target>15)showToast("Resumed from "+fmt(target),"Restart",function(){seekTo(0);});}catch(e){}}' +
    'v.addEventListener("loadedmetadata",function(){hasMetadata=true;applySeek();updateChapters();updateUi();buildSpeedMenu();buildMoreMenu();applySpeed();syncMediaSession();});' +
    'v.addEventListener("durationchange",function(){applySeek();updateChapters();updateUi();});' +
    'function setHudTitle(raw){var s=String(raw||""),i=s.lastIndexOf(" \u00b7 ");' +
    'if(hudEp&&i>0){if(hudTitle)hudTitle.textContent=s.slice(0,i);hudEp.textContent=s.slice(i);hudEp.hidden=false;}' +
    'else{if(hudTitle)hudTitle.textContent=s;if(hudEp){hudEp.textContent="";hudEp.hidden=true;}}}' +
    'function syncMediaSession(){try{if(!("mediaSession" in navigator)||!navigator.mediaSession)return;' +
    'var t=(((hudTitle&&hudTitle.textContent)||"")+((hudEp&&!hudEp.hidden&&hudEp.textContent)||""))||document.title||(isCinema?"Cinema":"Everglow");' +
    'if(typeof MediaMetadata==="function"){navigator.mediaSession.metadata=new MediaMetadata(isCinema?{title:t,artist:"Cinema"}:{title:t,artist:"Everglow",artwork:[{src:"https://everglow-1c6db.web.app/favicon.png",sizes:"192x192",type:"image/png"}]});}' +
    'navigator.mediaSession.setActionHandler("play",function(){tryPlay();});' +
    'navigator.mediaSession.setActionHandler("pause",function(){v.pause();});' +
    'navigator.mediaSession.setActionHandler("seekbackward",function(){seekBy(-prefs.seek);});' +
    'navigator.mediaSession.setActionHandler("seekforward",function(){seekBy(prefs.seek);});' +
    'navigator.mediaSession.setActionHandler("nexttrack",function(){if(nextToken||nextKind==="season")post({type:"animex-action",action:"next-episode"});});}catch(e){}}' +
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
    'if(d.type==="everglow-key"){handleKey(d.key);return;}' +
    'if(d.type==="animex-player-state"||d.type==="animex-skip-times"){' +
    'opRange=Array.isArray(d.op)&&d.op.length===2&&Number.isFinite(d.op[0])&&Number.isFinite(d.op[1])?d.op:null;' +
    'edRange=Array.isArray(d.ed)&&d.ed.length===2&&Number.isFinite(d.ed[0])&&Number.isFinite(d.ed[1])?d.ed:null;' +
    'var nextTokVal=typeof d.next==="string"&&d.next?d.next:null;' +
    'var nextKindVal=d.nextKind==="season"?"season":"episode";' +
    'if(nextTokVal!==nextToken||nextKindVal!==nextKind){nextDismissed=false;}' +
    'nextToken=nextTokVal;nextKind=nextKindVal;' +
    'if(d.title)setHudTitle(d.title);' +
    'if(d.title&&tapTitle){tapTitle.textContent=String(d.title);}' +
    'if(tapArt&&typeof d.poster==="string"&&/^https:\\/\\//i.test(d.poster)){tapArt.src=d.poster;tapArt.hidden=false;}' +
    'if(typeof d.autoSkip==="boolean"){prefs.autoSkip=d.autoSkip;savePrefs();}' +
    'if(typeof d.autoNext==="boolean"){prefs.autoSkipEd=d.autoNext;savePrefs();}' +
    'if(typeof d.theater==="boolean"){inTheater=d.theater;if(typeof syncFsUi==="function")syncFsUi();}' +
    'if(d.hasEpisodes&&!btnEps&&document.createElement){var crt=document.querySelector&&document.querySelector(".ctrl-rt");' +
    'if(crt){btnEps=document.createElement("button");btnEps.type="button";btnEps.className="ib";btnEps.setAttribute("id","btn-eps");btnEps.setAttribute("aria-label","Episodes");btnEps.setAttribute("title","Episodes");' +
    'btnEps.innerHTML="<svg viewBox=\\"0 0 24 24\\" fill=\\"none\\" stroke=\\"currentColor\\" stroke-width=\\"1.9\\" stroke-linecap=\\"round\\" stroke-linejoin=\\"round\\"><path d=\\"M4 6h11M4 11h11M4 16h7\\"/><polygon points=\\"15 13 20 16.5 15 20\\" fill=\\"currentColor\\" stroke=\\"none\\"/></svg>";' +
    'btnEps.addEventListener("click",function(){post({type:"animex-action",action:"episodes"});});' +
    'if(btnCc&&btnCc.parentNode===crt)crt.insertBefore(btnEps,btnCc);else crt.appendChild(btnEps);}}' +
    'syncMediaSession();updateChapters();updateUi();}});' +
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
    'function setBuffering(on){if(buf)buf.hidden=!on;if(document.body&&document.body.classList)document.body.classList.toggle("buffering",!!on);}' +
    'v.addEventListener("pause",function(){if(playP)playP.setAttribute("d","M5 3.5l12 6.5-12 6.5V3.5z");' +
    'if(cplayP)cplayP.setAttribute("d","M5 3.5l12 6.5-12 6.5V3.5z");' +
    'if(document.body&&document.body.classList)document.body.classList.add("is-paused");' +
    'setBuffering(false);progress(true);});' +
    'v.addEventListener("ended",function(){progress(true);});' +
    'function hideBoot(){boot.style.display="none";}' +
    'function showTap(){hideBoot();tapw.hidden=false;if(document.body&&document.body.classList)document.body.classList.add("preplay");}' +
    'function tryPlay(){var p;try{p=v.play();}catch(e){showTap();return;}' +
    'if(p&&p.catch){p.catch(function(err){' +
    'if(err&&(err.name==="AbortError"||err.code===20))return;showTap();});}}' +
    'function showUnlockHint(){if(!unlockW)return;unlockW.hidden=false;placeSubs();' +
    'if(typeof clearTimeout==="function"&&unlockHideT)clearTimeout(unlockHideT);' +
    'if(typeof setTimeout==="function"){unlockHideT=setTimeout(function(){if(screenLocked&&unlockW){unlockW.hidden=true;placeSubs();}},2400);}}' +
    'function setLocked(on){screenLocked=!!on;' +
    'if(document.body&&document.body.classList)document.body.classList.toggle("locked",screenLocked);' +
    'if(screenLocked){closeMenus();showUnlockHint();}else{if(unlockW)unlockW.hidden=true;placeSubs();wakeHud();}}' +
    'if(btnLock)btnLock.addEventListener("click",function(){setLocked(true);});' +
    'if(unlockBtn)unlockBtn.addEventListener("click",function(){setLocked(false);});' +
    'function giveUp(){hideBoot();tapw.hidden=true;dead.hidden=false;' +
    'if(document.body&&document.body.classList)document.body.classList.remove("preplay");' +
    'if(pickSeq>0){if(svMenu){buildSvMenu();svMenu.hidden=false;}' +
    'if(!(window.innerWidth&&window.innerWidth<=600))dead.style.paddingRight="190px";return;}' +
    'post("animex-content-error");}' +
    'if(deadSv)deadSv.addEventListener("click",function(){if(svMenu){buildSvMenu();svMenu.hidden=false;}' +
    'if(dead&&!(window.innerWidth&&window.innerWidth<=600))dead.style.paddingRight="190px";});' +
    'tap.addEventListener("click",function(){tapw.hidden=true;if(document.body&&document.body.classList)document.body.classList.remove("preplay");tryPlay();});' +
    'var started=false;' +
    'var stallT=null;' +
    'function clearStall(){if(typeof clearTimeout==="function"&&stallT){clearTimeout(stallT);stallT=null;}}' +
    'function armStall(){clearStall();if(typeof setTimeout==="function"){' +
    'stallT=setTimeout(function(){stallT=null;if(!v.paused&&!v.ended)giveUp();},15000);}}' +
    'v.addEventListener("playing",function(){started=true;clearStall();hideBoot();tapw.hidden=true;' +
    'if(document.body&&document.body.classList){document.body.classList.remove("preplay");document.body.classList.remove("is-paused");}' +
    'setBuffering(false);' +
    'if(dead){dead.hidden=true;dead.style.paddingRight="";}' +
    'if(picking){picking=false;if(svMenu)svMenu.hidden=true;}' +
    'if(playP)playP.setAttribute("d","M4 3h3.5v14H4zM12.5 3H16v14h-3.5z");' +
    'if(cplayP)cplayP.setAttribute("d","M4 3h3.5v14H4zM12.5 3H16v14h-3.5z");});' +
    'v.addEventListener("canplay",function(){clearStall();setBuffering(false);});' +
    'v.addEventListener("pause",clearStall);v.addEventListener("ended",clearStall);' +
    'v.addEventListener("waiting",function(){' +
    'if(!v.paused&&!v.ended)armStall();' +
    'if(!started){if(dead.hidden&&tapw.hidden)boot.style.display="flex";return;}' +
    'setBuffering(true);});' +
    'if(btnPlay)btnPlay.addEventListener("click",function(){togglePlay();kick(btnPlay,"pop");});' +
    'if(cplay)cplay.addEventListener("click",function(){togglePlay();kick(cplay,"pop");wakeHud();});' +
    'if(btnRew)btnRew.addEventListener("click",function(){seekBy(-prefs.seek);kick(btnRew,"spin-l");});' +
    'if(btnFf)btnFf.addEventListener("click",function(){seekBy(prefs.seek);kick(btnFf,"spin-r");});' +
    'if(cRew)cRew.addEventListener("click",function(){seekBy(-prefs.seek);kick(cRew,"spin-l");wakeHud();});' +
    'if(cFf)cFf.addEventListener("click",function(){seekBy(prefs.seek);kick(cFf,"spin-r");wakeHud();});' +
    'if(btnNx)btnNx.addEventListener("click",function(){post({type:"animex-action",action:"next-episode"});});' +
    'if(btnVol)btnVol.addEventListener("click",function(){v.muted=!v.muted;' +
    'prefs.muted=v.muted;savePrefs();syncVolIcon();});' +
    'if(volRange)volRange.addEventListener("input",function(){' +
    'setVol(parseFloat(volRange.value));});' +
    'if(btnSkip)btnSkip.addEventListener("click",function(){if(activeSkipEnd!==null&&Number.isFinite(v.duration)){v.currentTime=Math.min(v.duration,activeSkipEnd);updateUi();}});' +
    'var btnNextGo=document.getElementById("btn-next-go");' +
    'if(btnNextGo)btnNextGo.addEventListener("click",function(e){if(e&&e.stopPropagation)e.stopPropagation();post({type:"animex-action",action:"next-episode"});});' +
    'if(btnNext)btnNext.addEventListener("click",function(){post({type:"animex-action",action:"next-episode"});});' +
    'if(btnNextX)btnNextX.addEventListener("click",function(e){if(e&&e.stopPropagation)e.stopPropagation();if(e&&e.preventDefault)e.preventDefault();nextDismissed=true;updateNextBtn();});' +
    'if(btnSub)btnSub.addEventListener("click",function(){post({type:"animex-action",action:"audio",audio:"sub"});});' +
    'if(btnDub)btnDub.addEventListener("click",function(){post({type:"animex-action",action:"audio",audio:"dub"});});' +
    'var tapSv=document.getElementById("tap-sv"),tapSubB=document.getElementById("tap-sub-b"),tapDubB=document.getElementById("tap-dub-b");' +
    'if(tapSv&&svMenu)tapSv.addEventListener("click",function(){openOnlyMenu(svMenu,tapSv,buildSvMenu);});' +
    'if(tapSubB)tapSubB.addEventListener("click",function(){post({type:"animex-action",action:"audio",audio:"sub"});});' +
    'if(tapDubB)tapDubB.addEventListener("click",function(){post({type:"animex-action",action:"audio",audio:"dub"});});' +
    'if(btnEps)btnEps.addEventListener("click",function(){post({type:"animex-action",action:"episodes"});});' +
    'function anyMenuOpen(){return (ccMenu&&!ccMenu.hidden)||(qMenu&&!qMenu.hidden)||(spMenu&&!spMenu.hidden)||(moreMenu&&!moreMenu.hidden)||(svMenu&&!svMenu.hidden)||(keysMenu&&!keysMenu.hidden);}' +
    'function syncAria(){var pairs=[[btnCc,ccMenu],[btnQ,qMenu],[btnSpeed,spMenu],[btnMore,moreMenu],[btnSv,svMenu]];' +
    'for(var i=0;i<pairs.length;i++){var b=pairs[i][0],m=pairs[i][1];if(b&&b.setAttribute&&m)b.setAttribute("aria-expanded",String(!m.hidden));}' +
    'if(menuBackdrop)menuBackdrop.hidden=!((keysMenu&&!keysMenu.hidden)||(compactSheet()&&anyMenuOpen()));' +
    'if(document.body&&document.body.classList)document.body.classList.toggle("menu-open",anyMenuOpen());}' +
    'if(menuBackdrop)menuBackdrop.addEventListener("click",function(){closeMenus();});' +
    'function openOnlyMenu(menu,btn,builder){var open=menu.hidden;if(open){if(builder)builder();lastMenuBtn=btn;}' +
    'if(ccMenu&&ccMenu!==menu)ccMenu.hidden=true;if(qMenu&&qMenu!==menu)qMenu.hidden=true;' +
    'if(spMenu&&spMenu!==menu)spMenu.hidden=true;if(moreMenu&&moreMenu!==menu)moreMenu.hidden=true;if(svMenu&&svMenu!==menu)svMenu.hidden=true;if(keysMenu&&keysMenu!==menu)keysMenu.hidden=true;' +
    'menu.hidden=!open;syncAria();placeSubs();' +
    'if(!menu.hidden&&menu.querySelector){var first=menu.querySelector("[role=menuitem],button.qi");if(first&&first.focus)try{first.focus();}catch(e){}}}' +
    'if(btnCc&&ccMenu)btnCc.addEventListener("click",function(){openOnlyMenu(ccMenu,btnCc,buildCcMenu);});' +
    'var fsT=null;function isFs(){var d=document;return !!(d.fullscreenElement||d.webkitFullscreenElement);}' +
    'function syncFsUi(){var on=isFs()||inTheater;if(document.body&&document.body.classList){' +
    'document.body.classList.toggle("is-fs",on);document.body.classList.remove("fs-settle");' +
    'document.body.classList.add("fs-settle");' +
    'if(typeof clearTimeout==="function"&&fsT)clearTimeout(fsT);' +
    'if(typeof setTimeout==="function"){fsT=setTimeout(function(){' +
    'if(document.body&&document.body.classList)document.body.classList.remove("fs-settle");},240);}}' +
    'if(btnFs){btnFs.setAttribute("aria-label",on?"Exit fullscreen":"Fullscreen");' +
    'btnFs.classList.toggle("on",on);' +
    'if(fsP)fsP.setAttribute("d",on?"M7 3v4H3M13 3v4h4M7 17v-4H3M13 17v-4h4":"M3 7V3h4M17 7V3h-4M3 13v4h4M17 13v4h-4");}' +
    'placeSubs();if(typeof wakeHud==="function")wakeHud();}' +
    'function toggleFs(){if(inTheater&&!isFs()){post({type:"animex-action",action:"exit-theater"});return;}' +
    'var doc=document;var root=doc.documentElement||v;' +
    'if(isFs()){if(doc.exitFullscreen)doc.exitFullscreen();else if(doc.webkitExitFullscreen)doc.webkitExitFullscreen();}' +
    'else if(root.requestFullscreen){root.requestFullscreen();}' +
    'else if(root.webkitRequestFullscreen){root.webkitRequestFullscreen();}' +
    'else if(v.webkitEnterFullscreen){v.webkitEnterFullscreen();}}' +
    'if(document.addEventListener){document.addEventListener("fullscreenchange",syncFsUi);' +
    'document.addEventListener("webkitfullscreenchange",syncFsUi);}' +
    'if(btnFs)btnFs.addEventListener("click",toggleFs);' +
    'if(btnBack)btnBack.addEventListener("click",toggleFs);' +
    'function inOpenMenu(t){while(t){if((t===ccMenu||t===svMenu||t===qMenu||t===spMenu||t===moreMenu||t===keysMenu)&&!t.hidden)return true;t=t.parentNode||t.parentElement;}return false;}' +
    'window.addEventListener("wheel",function(e){if(!e||isFs()||inOpenMenu(e.target))return;' +
    'var dx=Number(e.deltaX)||0,dy=Number(e.deltaY)||0;if(!dx&&!dy)return;' +
    'post({type:"everglow-embed-scroll",deltaX:dx,deltaY:dy,deltaMode:Number(e.deltaMode)||0});},{passive:true});' +
    'if(btnQ&&qMenu)btnQ.addEventListener("click",function(){openOnlyMenu(qMenu,btnQ,null);});' +
    'if(btnSpeed&&spMenu)btnSpeed.addEventListener("click",function(){openOnlyMenu(spMenu,btnSpeed,buildSpeedMenu);});' +
    'if(btnMore&&moreMenu)btnMore.addEventListener("click",function(){openOnlyMenu(moreMenu,btnMore,buildMoreMenu);});' +
    'var pickSeq=0;' +
    'function setTracks(list){var old=v.querySelectorAll?v.querySelectorAll("track"):[];' +
    'for(var i=old.length-1;i>=0;i--){try{v.removeChild(old[i]);}catch(e){}}' +
    'cueList=[];cueTrack=-1;cueFetching=-1;cueFetchSeq++;' +
    'var arr=Array.isArray(list)?list:[],added=0;' +
    'for(var k=0;k<arr.length&&added<40;k++){var t=arr[k];if(!t||!t.file)continue;' +
    'var el=document.createElement("track");el.kind="captions";el.src=String(t.file);' +
    'if(t.label)el.label=String(t.label);if(added===0)el.default=true;added++;' +
    'try{v.appendChild(el);}catch(e){}}' +
    'buildCcMenu();syncCues();}' +
    'function syncSvHint(){var cur=null;for(var i=0;i<servers.length;i++){if(servers[i]&&servers[i].id===currentServer){cur=servers[i];break;}}' +
    'var hint=cur&&cur.label?("Server: "+cur.label):"Switch server";' +
    'if(btnSv&&btnSv.setAttribute){btnSv.setAttribute("title",hint);btnSv.setAttribute("aria-label",hint);if(cur&&cur.label)btnSv.setAttribute("data-sv",cur.label);else if(btnSv.removeAttribute)btnSv.removeAttribute("data-sv");}' +
    'var tsv=document.getElementById("tap-sv");if(tsv&&tsv.setAttribute){tsv.setAttribute("title",hint);if(cur&&cur.label)tsv.setAttribute("data-sv",cur.label);else if(tsv.removeAttribute)tsv.removeAttribute("data-sv");}}' +
    'function buildSvMenu(){if(!svMenu)return;svMenu.innerHTML="";syncSvHint();' +
    'for(var i=0;i<servers.length;i++){(function(s){' +
    'svMenu.appendChild(ccBtn(s.label,s.id===currentServer,function(){pickServer(s);}));})(servers[i]);}' +
    'var on=null,k=svMenu.children||[];' +
    'for(var j=0;j<k.length;j++){if((" "+k[j].className+" ").indexOf(" on ")>=0){on=k[j];break;}}' +
    'if(on&&on.scrollIntoView)on.scrollIntoView({block:"nearest"});}' +
    'function pickFailed(){picking=false;if(btnSv){btnSv.textContent="Server failed";' +
    'setTimeout(function(){if(btnSv)btnSv.textContent="Servers";},2200);}' +
    'if(svMenu)svMenu.hidden=false;}' +
    'function pickServer(s){if(!s||!s.url)return;' +
    'var seq=++pickSeq;picking=true;' +
    'if(btnSv)btnSv.textContent="Loading\u2026";' +
    'fetch(s.url,{credentials:"omit"}).then(function(r){return r.json();}).then(function(d){' +
    'if(seq!==pickSeq)return;' +
    'if(!d||!d.src)throw new Error("no src");' +
    'currentServer=s.id;' +
    'activeSrc=d.src;if(typeof resetPreview==="function")resetPreview();' +
    'var at=Number.isFinite(v.currentTime)?v.currentTime:0;' +
    'pendingSeek=at>0?at:null;hasMetadata=false;' +
    'if(window.Hls&&Hls.isSupported()){' +
    'if(!hlsInst||hlsDead){hlsInst=makeHls();hlsInst.attachMedia(v);}' +
    'hlsInst.loadSource(d.src);' +
    '}else{v.src=d.src;}' +
    'if(Array.isArray(d.tracks))setTracks(d.tracks);' +
    'if(btnSv)btnSv.textContent="Servers";buildSvMenu();' +
    '}).catch(function(){if(seq!==pickSeq)return;pickFailed();});}' +
    'if(btnSv&&svMenu)btnSv.addEventListener("click",function(){openOnlyMenu(svMenu,btnSv,buildSvMenu);});' +
    'syncSvHint();' +
    'function pipSupported(){return !!(document.pictureInPictureEnabled||' +
    '(v.webkitSupportsPresentationMode&&typeof v.webkitSetPresentationMode==="function"));}' +
    'function triggerPip(){var d=document;' +
    'if(d.pictureInPictureElement){if(d.exitPictureInPicture){' +
    'var x=d.exitPictureInPicture();if(x&&x.catch)x.catch(function(){});}return;}' +
    'if(v.webkitPresentationMode&&v.webkitSetPresentationMode){' +
    'v.webkitSetPresentationMode(v.webkitPresentationMode==="picture-in-picture"?"inline":"picture-in-picture");return;}' +
    'if(v.requestPictureInPicture){var p=v.requestPictureInPicture();' +
    'if(p&&p.catch)p.catch(function(){});}}' +
    'if(btnPip){if(!pipSupported()){btnPip.hidden=true;}else{btnPip.addEventListener("click",triggerPip);}}' +
    'function cleanTrackLabel(lb){var s=String(lb||"").trim();' +
    'if(!s)return"";' +
    's=s.replace(/^([^-]+?)\\s*-\\s*\\1\\b/i,"$1");' +
    's=s.replace(/\\s+Hi\\d+$/i," (CC)");' +
    'if(!/track\\s+\\d+$/i.test(s)){s=s.replace(/([A-Za-z])\\d+$/,"$1");}' +
    'return s;}' +
    'function trackEls(){return v.querySelectorAll?v.querySelectorAll("track"):[];}' +
    'function trackCount(){var n=v.textTracks?v.textTracks.length:0;var e=trackEls();return e.length>n?e.length:n;}' +
    'function trackLabel(i){var tt=v.textTracks&&v.textTracks[i];if(tt&&tt.label)return cleanTrackLabel(tt.label);' +
    'var el=trackEls()[i];var lb=el&&(el.label||(el.getAttribute&&el.getAttribute("label")));return cleanTrackLabel(lb)||("Track "+(i+1));}' +
    'function ccBtn(txt,on,fn){var b=document.createElement("button");b.type="button";' +
    'b.className="qi"+(on?" on":"");b.textContent=txt;if(b.setAttribute)b.setAttribute("role","menuitem");b.onclick=fn;return b;}' +
    'function ccHead(txt){var d=document.createElement("div");' +
    'd.className="cc-h";d.textContent=txt;return d;}' +
    'function ccRow(){var d=document.createElement("div");d.className="cc-row";return d;}' +
    'function placeSubs(){if(!subBox||!subBox.style||!subBox.style.setProperty)return;' +
    'var lift=0,idleLift=0;' +
    'var narrow=(window.innerWidth||0)>0&&(window.innerWidth||0)<=600;' +
    'if(!narrow){' +
    'var openM=(ccMenu&&!ccMenu.hidden&&ccMenu)||(spMenu&&!spMenu.hidden&&spMenu)||(qMenu&&!qMenu.hidden&&qMenu)||(moreMenu&&!moreMenu.hidden&&moreMenu);' +
    'if(openM&&openM.getBoundingClientRect){var mr=openM.getBoundingClientRect(),sr=subTxt&&subTxt.getBoundingClientRect?subTxt.getBoundingClientRect():null;' +
    'var srW=sr&&sr.width?sr.width:0,srR=sr?(typeof sr.right==="number"?sr.right:((sr.left||sr.x||0)+srW)):0,mrL=mr&&typeof mr.left==="number"?mr.left:((mr&&mr.x)||0);' +
    'if(!srW||srR+12>=mrL){lift=Math.max(0,Math.round(mr.height-18));}}' +
    'if(scrubPrev&&!scrubPrev.hidden){lift=Math.max(lift,128);}}' +
    'var hasBinge=(btnSkip&&!btnSkip.hidden)||(btnNext&&!btnNext.hidden);' +
    'var compactH=(window.innerHeight||0)>0&&(window.innerHeight||0)<=300;' +
    'var bingeLeft=!!(hasBinge&&narrow&&compactH&&!screenLocked);' +
    'if(document.body&&document.body.classList)document.body.classList.toggle("binge-left",bingeLeft);' +
    'if(hasBinge&&narrow){lift=Math.max(lift,compactH?47:46);idleLift=Math.max(idleLift,compactH?38:42);}' +
    'if(screenLocked&&unlockW&&!unlockW.hidden){idleLift=Math.max(idleLift,compactH?30:50);}' +
    'subBox.style.setProperty("--sub-lift",lift+"px");' +
    'subBox.style.setProperty("--sub-idle-lift",idleLift+"px");}' +
    'function closeMenus(restoreFocus){if(ccMenu)ccMenu.hidden=true;if(qMenu)qMenu.hidden=true;' +
    'if(spMenu)spMenu.hidden=true;if(moreMenu)moreMenu.hidden=true;if(svMenu)svMenu.hidden=true;if(keysMenu)keysMenu.hidden=true;syncAria();placeSubs();' +
    'if(restoreFocus&&lastMenuBtn&&lastMenuBtn.focus){try{lastMenuBtn.focus();}catch(e){}}lastMenuBtn=null;}' +
    'function fmtDelay(d){if(!d)return"0.0s";return(d>0?"+":"")+d.toFixed(1)+"s";}' +
    'function setDelay(next){if(!isFinite(next))return;' +
    'prefs.delay=Math.round(Math.max(-10,Math.min(10,next))*10)/10;' +
    'savePrefs();renderCues();buildCcMenu();}' +
    'function setSize(next){prefs.size=Math.max(0,Math.min(2,next));' +
    'savePrefs();applySubSize();buildCcMenu();}' +
    'function setSubBg(next){prefs.subBg=Math.max(0,Math.min(2,next));' +
    'savePrefs();applySubSize();buildCcMenu();}' +
    'function setSubColor(next){prefs.subColor=Math.max(0,Math.min(2,next));' +
    'savePrefs();applySubSize();buildCcMenu();}' +
    'function setSubPos(next){prefs.subPos=Math.max(0,Math.min(3,next));' +
    'savePrefs();applySubSize();buildCcMenu();}' +
    'function setCc(on){ccOn=!!on;prefs.cc=ccOn;savePrefs();' +
    'if(btnCc)btnCc.classList.toggle("on",ccOn);syncCues();buildCcMenu();}' +
    'function buildCcMenu(){var n=trackCount(),hasAud=audioTracks.length>1;' +
    'if(btnCc)btnCc.hidden=(n===0&&!hasAud);' +
    'if(n===0&&!hasAud){if(ccMenu)ccMenu.hidden=true;placeSubs();return;}' +
    'if(subPick>=n)subPick=0;' +
    'if(!ccMenu)return;ccMenu.innerHTML="";' +
    'addMenuHeader(ccMenu,hasAud?(n>0?"Subtitles & Audio":"Audio track"):"Subtitles");' +
    'var twoCol=n>1||(n>0&&hasAud);' +
    'var c1=ccMenu,c2=ccMenu;' +
    'if(twoCol){var grid=document.createElement("div");grid.className="more-grid";c1=mkCol();c2=mkCol();grid.appendChild(c1);grid.appendChild(c2);ccMenu.appendChild(grid);}' +
    'if(n>0){c1.appendChild(ccHead("Captions"));' +
    'var capRow=ccRow();capRow.appendChild(ccBtn("Off",!ccOn,function(){setCc(false);}));' +
    'capRow.appendChild(ccBtn("On",ccOn,function(){setCc(true);}));c1.appendChild(capRow);}' +
    'if(n>1){c1.appendChild(ccHead("Language"));' +
    'var fi=null;' +
    'if(n>6&&document.createElement){fi=document.createElement("input");fi.type="search";fi.className="cc-filter";fi.placeholder="Filter languages\u2026";if(fi.setAttribute)fi.setAttribute("aria-label","Filter subtitle languages");fi.value=ccQuery;c1.appendChild(fi);}' +
    'var langParent=c1;' +
    'if(document.createElement){var lw=document.createElement("div");if(n>4)lw.className="cc-langs";c1.appendChild(lw);langParent=lw;}' +
    'function renderLangs(){langParent.innerHTML="";var q=ccQuery.trim().toLowerCase(),order=[];' +
    'if(ccOn&&subPick>=0&&subPick<n)order.push(subPick);' +
    'for(var i=0;i<n;i++){if(i!==subPick||!ccOn)order.push(i);}' +
    'for(var k=0;k<order.length;k++){(function(idx){var lb=trackLabel(idx);' +
    'if(q&&lb.toLowerCase().indexOf(q)<0)return;' +
    'langParent.appendChild(ccBtn(lb,idx===subPick&&ccOn,function(){' +
    'subPick=idx;prefs.lang=idx;savePrefs();' +
    'if(!ccOn){setCc(true);}else{syncCues();buildCcMenu();}}));})(order[k]);}}' +
    'if(fi)fi.oninput=function(){ccQuery=String(fi.value||"");renderLangs();};' +
    'renderLangs();}' +
    'if(hasAud){c1.appendChild(ccHead("Audio track"));' +
    'var ar=ccRow();audioTracks.forEach(function(tr,idx){' +
    'ar.appendChild(ccBtn(tr.name||tr.lang||("Audio "+(idx+1)),hlsInst&&hlsInst.audioTrack===idx,function(){if(hlsInst){hlsInst.audioTrack=idx;buildCcMenu();}}));});' +
    'c1.appendChild(ar);}' +
    'if(n===0)return;' +
    'c2.appendChild(ccHead("Subtitle delay"));' +
    'var dr=ccRow();' +
    'dr.appendChild(ccBtn("\u2212",false,function(){setDelay(prefs.delay-0.1);}));' +
    'var dl=ccBtn(fmtDelay(prefs.delay),false,function(){setDelay(0);});' +
    'dl.title="Tap to reset";dr.appendChild(dl);' +
    'dr.appendChild(ccBtn("+",false,function(){setDelay(prefs.delay+0.1);}));' +
    'c2.appendChild(dr);' +
    'c2.appendChild(ccHead("Text size"));' +
    'var sz=ccRow();["Small","Medium","Large"].forEach(function(lbl,idx){sz.appendChild(ccBtn(lbl,idx===prefs.size,function(){setSize(idx);}));});' +
    'c2.appendChild(sz);' +
    'c2.appendChild(ccHead("Caption style"));' +
    'var bg=ccRow();["Outline","Pill","Box"].forEach(function(lbl,idx){bg.appendChild(ccBtn(lbl,idx===prefs.subBg,function(){setSubBg(idx);}));});' +
    'c2.appendChild(bg);' +
    'c2.appendChild(ccHead("Caption color"));' +
    'var cl=ccRow();["White","Warm","Yellow"].forEach(function(lbl,idx){cl.appendChild(ccBtn(lbl,idx===prefs.subColor,function(){setSubColor(idx);}));});' +
    'c2.appendChild(cl);' +
    'c2.appendChild(ccHead("Position"));' +
    'var ps=ccRow();["Low","Mid","High","Top"].forEach(function(lbl,idx){ps.appendChild(ccBtn(lbl,idx===prefs.subPos,function(){setSubPos(idx);}));});' +
    'c2.appendChild(ps);}' +
    'var cueList=[],cueTrack=-1,cueFetching=-1,cueFetchSeq=0;' +
    'function cleanCueText(s){return String(s||"").replace(/\\{\\\\[^}]*\\}/g,"").replace(/<(?!\\/?(i|b)\\b)[^>]+>/gi,"").trim();}' +
    'function stripRich(s){return String(s||"").replace(/<\\/?(i|b)\\b[^>]*>/gi,"");}' +
    'function paintCueText(next){if(!subTxt)return;' +
    'if(!/<(i|b)\\b/i.test(next)||typeof document.createTextNode!=="function"){if(subTxt.textContent!==next)subTxt.textContent=stripRich(next);return;}' +
    'subTxt.innerHTML="";var parts=next.split(/(<\\/?(?:i|b)\\b[^>]*>)/i),mode="";' +
    'for(var i=0;i<parts.length;i++){var p=parts[i];if(!p)continue;' +
    'if(/^<i\\b/i.test(p)){mode="i";continue;}if(/^<b\\b/i.test(p)){mode="b";continue;}' +
    'if(/^<\\/(i|b)>/i.test(p)){mode="";continue;}' +
    'if(mode==="i"||mode==="b"){var el=document.createElement(mode);el.textContent=p;subTxt.appendChild(el);}else{subTxt.appendChild(document.createTextNode(p));}}}' +
    'function parseVttTime(s){var m=String(s||"").trim().match(/^(?:(\\d+):)?(\\d{1,2}):(\\d{2}(?:[.,]\\d+)?)$/);' +
    'if(!m)return NaN;var h=m[1]?Number(m[1]):0,mn=Number(m[2]),sc=Number(m[3].replace(",","."));' +
    'return h*3600+mn*60+sc;}' +
    'function parseVtt(txt){var blocks=String(txt||"").replace(/\\r\\n?/g,"\\n").split(/\\n\\n+/),out=[];' +
    'for(var i=0;i<blocks.length;i++){var lines=blocks[i].split("\\n"),ti=-1;' +
    'for(var j=0;j<lines.length;j++){if(lines[j].indexOf("-->")>=0){ti=j;break;}}' +
    'if(ti<0)continue;var parts=lines[ti].split("-->");' +
    'var s=parseVttTime(parts[0]),e=parseVttTime((parts[1]||"").trim().split(/\\s+/)[0]);' +
    'if(!isFinite(s)||!isFinite(e)||e<=s)continue;' +
    'var body=cleanCueText(lines.slice(ti+1).join("\\n"));' +
    'if(body)out.push({s:s,e:e,t:body});}return out;}' +
    'function fetchVtt(pick){if(typeof fetch!=="function")return;' +
    'var el=trackEls()[pick];var src=el&&(el.src||(el.getAttribute&&el.getAttribute("src")));' +
    'if(!src||cueFetching===pick)return;cueFetching=pick;var seq=++cueFetchSeq;' +
    'fetch(src).then(function(r){return r&&r.ok?r.text():"";}).then(function(txt){' +
    'if(seq!==cueFetchSeq||subPick!==pick)return;' +
    'var parsed=parseVtt(txt);if(parsed.length){cueList=parsed;cueTrack=pick;renderCues();}' +
    '}).catch(function(){});}' +
    'function readCues(){var n=trackCount();if(!n)return;' +
    'var pick=subPick;if(pick<0||pick>=n)pick=0;' +
    'if(cueTrack===pick&&cueList.length)return;var out=[];' +
    'try{var cs=v.textTracks&&v.textTracks[pick]&&v.textTracks[pick].cues;' +
    'if(cs){for(var j=0;j<cs.length;j++){var c=cs[j];' +
    'if(!c||typeof c.startTime!=="number"||typeof c.endTime!=="number")continue;' +
    'var tx=cleanCueText(c.text);if(tx)out.push({s:c.startTime,e:c.endTime,t:tx});}}}catch(e){}' +
    'if(out.length){cueList=out;cueTrack=pick;}else if(ccOn){fetchVtt(pick);}}' +
    'function renderCues(){if(!subTxt)return;' +
    'if(!ccOn){if(subTxt.textContent)subTxt.textContent="";return;}' +
    'readCues();' +
    'if(!cueList.length){if(subTxt.textContent)subTxt.textContent="";return;}' +
    'var t=v.currentTime-prefs.delay;if(!isFinite(t))return;var lines=[];' +
    'for(var i=0;i<cueList.length;i++){var c=cueList[i];' +
    'if(t>=c.s&&t<c.e&&c.t)lines.push(c.t);}' +
    'var next=lines.join("\\n");' +
    'paintCueText(next);}' +
    'function syncCues(){var n=trackCount();' +
    'var pick=subPick;if(pick<0||pick>=n)pick=0;' +
    'cueList=[];cueTrack=-1;cueFetching=-1;cueFetchSeq++;' +
    'if(v.textTracks){for(var i=0;i<v.textTracks.length;i++){var tr=v.textTracks[i];' +
    'if(i!==pick){tr.mode="disabled";tr.oncuechange=null;continue;}' +
    'tr.mode=ccOn?"hidden":"disabled";tr.oncuechange=renderCues;}}' +
    'renderCues();}' +
    'v.addEventListener("loadedmetadata",function(){buildCcMenu();syncCues();});' +
    'if(v.textTracks&&v.textTracks.addEventListener)v.textTracks.addEventListener("addtrack",buildCcMenu);' +
    'var hoveringScrub=false,dragging=false,dragPct=null;' +
    'var idleT=null;function wakeHud(){if(document.body&&document.body.classList){document.body.classList.remove("idle");}' +
    'if(typeof clearTimeout==="function"&&idleT)clearTimeout(idleT);' +
    'if(typeof setTimeout==="function"){idleT=setTimeout(function(){' +
    'if(!v.paused&&!hoveringScrub&&!dragging&&(!ccMenu||ccMenu.hidden)&&(!spMenu||spMenu.hidden)&&(!moreMenu||moreMenu.hidden)&&document.body&&document.body.classList){' +
    'document.body.classList.add("idle");if(qMenu)qMenu.hidden=true;if(typeof hidePreview==="function")hidePreview();}},2800);}}' +
    'window.addEventListener("mousemove",function(){if(finePointer)wakeHud();});' +
    'var botEl=document.querySelector?document.querySelector(".h-bot"):null;' +
    'var topEl=document.querySelector?document.querySelector(".h-top"):null;' +
    'if(botEl)botEl.addEventListener("touchstart",wakeHud,{passive:true});' +
    'if(topEl)topEl.addEventListener("touchstart",wakeHud,{passive:true});' +
    'if(cplay)cplay.addEventListener("touchstart",wakeHud,{passive:true});' +
    'function togglePlay(){if(v.paused){flash("play");tryPlay();}else{flash("pause");v.pause();}}' +
    'function seekBy(delta){if(!Number.isFinite(v.currentTime))return;' +
    'flash(delta<0?"rew":"ff");' +
    'var d=Number.isFinite(v.duration)&&v.duration>0?v.duration:Infinity;' +
    'v.currentTime=Math.max(0,Math.min(d,v.currentTime+delta));updateUi();}' +
    'function seekTo(sec){if(!Number.isFinite(v.duration)||v.duration<=0||!Number.isFinite(sec))return;' +
    'v.currentTime=Math.max(0,Math.min(v.duration,sec));updateUi();}' +
    'function setVol(x){if(!Number.isFinite(x))return;' +
    'var n=Math.max(0,Math.min(1,x));v.volume=n;v.muted=n===0;' +
    'prefs.vol=n;prefs.muted=v.muted;savePrefs();' +
    'if(volRange&&volRange.value!==String(n))volRange.value=String(n);' +
    'syncVolIcon();}' +
    'var pvHls=null,pvReady=false,pvFailed=false,pvLoadedSrc=null,pvTimer=null,pvPending=null;' +
    'var pvCache=Object.create?Object.create(null):{},pvOrder=[];' +
    'function pvStep(d){if(!Number.isFinite(d)||d<=0)return 2;return Math.max(1,Math.min(10,Math.round(d/300)));}' +
    'function pvBucket(sec,d){var s=pvStep(d);return Math.round(sec/s)*s;}' +
    'function drawFrameFrom(el,canvas){if(!el||!canvas||!canvas.getContext)return false;' +
    'try{if((el.readyState||0)<2)return false;var w=canvas.width||240,h=canvas.height||135;' +
    'if(el.videoWidth&&el.videoHeight){w=240;h=Math.max(90,Math.round(240*el.videoHeight/el.videoWidth));}' +
    'if(canvas.width!==w)canvas.width=w;if(canvas.height!==h)canvas.height=h;' +
    'var ctx=canvas.getContext("2d");if(!ctx)return false;ctx.drawImage(el,0,0,w,h);return true;}catch(e){return false;}}' +
    'function paintCached(snap){if(!snap||!pvCanvas||!pvCanvas.getContext)return false;' +
    'try{if(pvCanvas.width!==snap.width)pvCanvas.width=snap.width;if(pvCanvas.height!==snap.height)pvCanvas.height=snap.height;' +
    'var ctx=pvCanvas.getContext("2d");if(!ctx)return false;ctx.drawImage(snap,0,0,snap.width,snap.height);' +
    'pvCanvas.hidden=false;return true;}catch(e){return false;}}' +
    'function storeCache(bucket){if(!pv||!document.createElement)return null;' +
    'var c=document.createElement("canvas");if(!c||!c.getContext)return null;' +
    'if(!drawFrameFrom(pv,c))return null;' +
    'if(!pvCache[bucket]){if(pvOrder.length>=48){delete pvCache[pvOrder.shift()];}pvOrder.push(bucket);}' +
    'pvCache[bucket]=c;return c;}' +
    'function resetPreview(){pvReady=false;pvFailed=false;pvLoadedSrc=null;pvPending=null;' +
    'if(typeof clearTimeout==="function"&&pvTimer){clearTimeout(pvTimer);pvTimer=null;}' +
    'pvCache=Object.create?Object.create(null):{};pvOrder=[];' +
    'if(pvCanvas){pvCanvas.hidden=true;if(pvCanvas.getContext){try{var pc=pvCanvas.getContext("2d");if(pc)pc.clearRect(0,0,pvCanvas.width||0,pvCanvas.height||0);}catch(e){}}}' +
    'if(scrubPrev&&scrubPrev.classList)scrubPrev.classList.remove("loading");' +
    'if(pvHls){try{pvHls.destroy();}catch(e){}pvHls=null;}' +
    'if(pv&&pv.removeAttribute){try{pv.removeAttribute("src");if(pv.load)pv.load();}catch(e){}}}' +
    'function ensurePreview(){if(!pv||!activeSrc||pvFailed)return;try{if(navigator&&navigator.connection&&navigator.connection.saveData)return;}catch(e){}if(pvLoadedSrc===activeSrc&&(pvHls||!window.Hls||!Hls.isSupported()))return;' +
    'pvLoadedSrc=activeSrc;pvReady=false;' +
    'if(window.Hls&&Hls.isSupported()){' +
    'if(pvHls){try{pvHls.destroy();}catch(e){}pvHls=null;}' +
    'try{' +
    (token
      ? 'pvHls=new Hls({startLevel:0,capLevelToPlayerSize:true,maxBufferLength:2,maxMaxBufferLength:3,backBufferLength:0,xhrSetup:function(x,u){try{if(new URL(u,location.href).origin===location.origin){x.setRequestHeader("Authorization","Bearer "+' + safeScriptJson(String(token)) + ');}}catch(e){}}});'
      : 'pvHls=new Hls({startLevel:0,capLevelToPlayerSize:true,maxBufferLength:2,maxMaxBufferLength:3,backBufferLength:0});') +
    'pvHls.on(Hls.Events.ERROR,function(ev,data){if(data&&data.fatal){pvFailed=true;try{pvHls.destroy();}catch(e){}pvHls=null;pvReady=false;if(scrubPrev&&scrubPrev.classList)scrubPrev.classList.remove("loading");}});' +
    'pvHls.attachMedia(pv);pvHls.loadSource(activeSrc);' +
    '}catch(e){pvHls=null;pvFailed=true;if(scrubPrev&&scrubPrev.classList)scrubPrev.classList.remove("loading");}}else{try{pv.preload="metadata";pv.src=activeSrc;if(pv.load)pv.load();}catch(e){pvFailed=true;if(scrubPrev&&scrubPrev.classList)scrubPrev.classList.remove("loading");}}}' +
    'if(pv&&pv.addEventListener){' +
    'pv.addEventListener("loadedmetadata",function(){pvReady=true;' +
    'if(pvPending!==null){try{pv.currentTime=pvPending;}catch(e){}}});' +
    'pv.addEventListener("error",function(){if(!pvLoadedSrc)return;pvFailed=true;pvReady=false;' +
    'if(scrubPrev&&scrubPrev.classList)scrubPrev.classList.remove("loading");});' +
    'pv.addEventListener("seeked",function(){' +
    'var d=Number.isFinite(v.duration)&&v.duration>0?v.duration:(Number.isFinite(pv.duration)?pv.duration:0);' +
    'if(d>0)storeCache(pvBucket(pv.currentTime,d));' +
    'if(pvCanvas){if(drawFrameFrom(pv,pvCanvas)){pvCanvas.hidden=false;}else{pvCanvas.hidden=true;}}' +
    'if(scrubPrev&&scrubPrev.classList)scrubPrev.classList.remove("loading");});}' +
    'function hidePreview(){hoveringScrub=false;pvPending=null;' +
    'if(typeof clearTimeout==="function"&&pvTimer){clearTimeout(pvTimer);pvTimer=null;}' +
    'if(sHover)sHover.style.width="0%";' +
    'if(scrubPrev){scrubPrev.hidden=true;if(scrubPrev.classList)scrubPrev.classList.remove("loading");}placeSubs();}' +
    'function showPreviewAt(pct){if(!scrubPrev||pct===null||!Number.isFinite(v.duration)||v.duration<=0)return;' +
    'pct=Math.max(0,Math.min(1,pct));var t=pct*v.duration;' +
    'if(pvTime)pvTime.textContent=fmt(t);' +
    'if(pvTag){if(opRange&&t>=opRange[0]&&t<opRange[1]){pvTag.textContent="Intro";pvTag.hidden=false;}' +
    'else if(edRange&&t>=edRange[0]&&t<edRange[1]){pvTag.textContent="Ending";pvTag.hidden=false;}' +
    'else{pvTag.hidden=true;}}' +
    'scrubPrev.hidden=false;placeSubs();' +
    'var wrapW=(scrubWrap&&scrubWrap.offsetWidth)||(scrub&&scrub.offsetWidth)||0;' +
    'var boxW=scrubPrev.offsetWidth||168;' +
    'if(wrapW>0&&boxW>0){var half=boxW/2;' +
    'scrubPrev.style.left=Math.max(half,Math.min(wrapW-half,pct*wrapW))+"px";' +
    '}else{scrubPrev.style.left=(pct*100)+"%";}' +
    'if(sHover&&!dragging)sHover.style.width=(pct*100)+"%";' +
    'var bucket=pvBucket(t,v.duration);' +
    'if(pvCache[bucket]&&paintCached(pvCache[bucket])){if(scrubPrev.classList)scrubPrev.classList.remove("loading");return;}' +
    'if(pvCanvas&&Number.isFinite(v.currentTime)&&Math.abs(t-v.currentTime)<=1.2&&drawFrameFrom(v,pvCanvas)){' +
    'pvCanvas.hidden=false;if(scrubPrev.classList)scrubPrev.classList.remove("loading");return;}' +
    'if(pvReady&&(pv.readyState||0)>=2&&!pv.seeking&&Math.abs((pv.currentTime||0)-bucket)<=0.15){' +
    'if(scrubPrev.classList)scrubPrev.classList.remove("loading");return;}' +
    'if(pvFailed){if(scrubPrev.classList)scrubPrev.classList.remove("loading");return;}' +
    'if(!finePointer&&!dragging){if(scrubPrev.classList)scrubPrev.classList.remove("loading");return;}' +
    'if(scrubPrev.classList)scrubPrev.classList.add("loading");' +
    'ensurePreview();pvPending=Math.max(0,Math.min(v.duration,bucket));' +
    'if(typeof setTimeout==="function"){if(pvTimer)clearTimeout(pvTimer);' +
    'pvTimer=setTimeout(function(){pvTimer=null;if(pv&&pvReady&&pvPending!==null){try{pv.currentTime=pvPending;}catch(e){}}},45);' +
    '}else if(pv&&pvReady&&pvPending!==null){try{pv.currentTime=pvPending;}catch(e){}}}' +
    'function pctFromX(clientX){if(!scrub||!scrub.getBoundingClientRect)return null;' +
    'if(!Number.isFinite(v.duration)||v.duration<=0)return null;' +
    'var r=scrub.getBoundingClientRect();if(!(r.width>0))return null;' +
    'return Math.max(0,Math.min(1,(clientX-r.left)/r.width));}' +
    'function paintDrag(pct){if(pct===null)return;var w=(pct*100)+"%";' +
    'if(sFill)sFill.style.width=w;if(sThumb)sThumb.style.left=w;' +
    'if(timeLbl&&Number.isFinite(v.duration))timeLbl.textContent=formatTimeLabel(pct*v.duration,v.duration);' +
    'if(scrub&&Number.isFinite(v.duration)&&v.duration>0){var curS=pct*v.duration;' +
    'scrub.setAttribute("aria-valuenow",String(Math.round(curS)));' +
    'scrub.setAttribute("aria-valuemin","0");scrub.setAttribute("aria-valuemax",String(Math.round(v.duration)));' +
    'scrub.setAttribute("aria-valuetext",fmt(curS)+" of "+fmt(v.duration));}' +
    'showPreviewAt(pct);}' +
    'function endDrag(commit,e){if(!dragging)return;dragging=false;' +
    'if(document.body&&document.body.classList)document.body.classList.remove("scrubbing");' +
    'var pct=dragPct;dragPct=null;' +
    'if(commit&&pct!==null&&Number.isFinite(v.duration)&&v.duration>0){' +
    'try{v.currentTime=pct*v.duration;}catch(err){}}' +
    'if(e&&typeof e.clientX==="number"&&typeof e.clientY==="number"&&scrub&&scrub.getBoundingClientRect){' +
    'var r=scrub.getBoundingClientRect();' +
    'if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top-12||e.clientY>r.bottom+12){hoveringScrub=false;}}' +
    'if(!hoveringScrub)hidePreview();' +
    'updateUi();wakeHud();}' +
    'if(scrub){' +
    'scrub.setAttribute("role","slider");scrub.setAttribute("tabindex","0");' +
    'scrub.setAttribute("aria-label","Seek timeline");' +
    'function onHoverMove(e){if(dragging)return;if(e&&e.pointerType==="touch")return;' +
    'var p=pctFromX(e.clientX);if(p===null)return;' +
    'hoveringScrub=true;showPreviewAt(p);wakeHud();}' +
    'scrub.addEventListener("pointermove",onHoverMove);' +
    'scrub.addEventListener("pointerleave",function(){hoveringScrub=false;if(!dragging)hidePreview();});' +
    'scrub.addEventListener("pointerdown",function(e){' +
    'try{scrub.focus();}catch(fe){}' +
    'dragging=true;if(document.body&&document.body.classList)document.body.classList.add("scrubbing");' +
    'if(sHover)sHover.style.width="0%";' +
    'dragPct=pctFromX(e.clientX);paintDrag(dragPct);wakeHud();' +
    'if(scrub.setPointerCapture&&e.pointerId!==undefined){' +
    'try{scrub.setPointerCapture(e.pointerId);}catch(err){}}' +
    'if(e.preventDefault)e.preventDefault();});' +
    'window.addEventListener("pointermove",function(e){if(!dragging)return;' +
    'dragPct=pctFromX(e.clientX);paintDrag(dragPct);});' +
    'window.addEventListener("pointerup",function(e){endDrag(true,e);});' +
    'window.addEventListener("pointercancel",function(e){endDrag(false,e);});' +
    'scrub.addEventListener("keydown",function(e){var k=e.key;' +
    'if(k==="ArrowRight"){seekBy(prefs.seek);}' +
    'else if(k==="ArrowLeft"){seekBy(-prefs.seek);}' +
    'else if(k==="Home"){seekTo(0);}' +
    'else if(k==="End"){seekTo(v.duration);}' +
    'else{return;}' +
    'if(e.stopPropagation)e.stopPropagation();' +
    'if(e.preventDefault)e.preventDefault();});}' +
    'var finePointer=false;' +
    'try{finePointer=!!(window.matchMedia&&' +
    'window.matchMedia("(hover:hover) and (pointer:fine)").matches);}catch(e){}' +
    'if(tap&&tap.querySelector){var tapLbl=tap.querySelector("span");if(tapLbl)tapLbl.textContent=finePointer?"Click to play":"Tap to play";}' +
    'var lastTap={t:0,x:0},tapTimer=null,seekChainUntil=0,seekChainSide=0,seekChainTotal=0;' +
    'function toggleHud(){if(!document.body||!document.body.classList)return;' +
    'if(document.body.classList.contains("idle")){wakeHud();return;}' +
    'document.body.classList.add("idle");hidePreview();closeMenus();' +
    'if(typeof clearTimeout==="function"&&idleT){clearTimeout(idleT);idleT=null;}}' +
    'function tapSide(x){' +
    'var r=scrub&&scrub.getBoundingClientRect?scrub.getBoundingClientRect():null;' +
    'var w=r&&r.width>0?r.width:(window.innerWidth||0);' +
    'if(!(w>0))return 0;var relX=r?(x-r.left):x;var third=w/3;' +
    'return relX<third?-1:(relX>2*third?1:0);}' +
    'function applyChainedSeek(side,now){' +
    'var delta=side*prefs.seek;' +
    'seekChainTotal=(now<seekChainUntil&&seekChainSide===side)?(seekChainTotal+delta):delta;' +
    'seekChainSide=side;seekChainUntil=now+700;' +
    'if(!Number.isFinite(v.currentTime))return;' +
    'var d=Number.isFinite(v.duration)&&v.duration>0?v.duration:Infinity;' +
    'v.currentTime=Math.max(0,Math.min(d,v.currentTime+delta));updateUi();' +
    'flash(side<0?"rew":"ff",Math.abs(seekChainTotal));}' +
    'function doubleTapSeek(x,now){var s=tapSide(x);' +
    'if(s===0){togglePlay();return;}' +
    'applyChainedSeek(s,now);}' +
    'function onPictureTap(e){' +
    'if(lpSuppressClick){lpSuppressClick=false;return;}' +
    'if(screenLocked){showUnlockHint();return;}' +
    'closeMenus();' +
    'var x=e&&typeof e.clientX==="number"?e.clientX:0;' +
    'if(finePointer){togglePlay();wakeHud();return;}' +
    'var now=Date.now(),side=tapSide(x);' +
    'if(side!==0&&now<seekChainUntil&&seekChainSide===side){' +
    'if(typeof clearTimeout==="function"&&tapTimer){clearTimeout(tapTimer);tapTimer=null;}' +
    'lastTap={t:0,x:0};applyChainedSeek(side,now);return;}' +
    'if(now-lastTap.t<280&&Math.abs(x-lastTap.x)<80){' +
    'lastTap={t:0,x:0};' +
    'if(typeof clearTimeout==="function"&&tapTimer){clearTimeout(tapTimer);tapTimer=null;}' +
    'doubleTapSeek(x,now);return;}' +
    'lastTap={t:now,x:x};' +
    'if(typeof setTimeout!=="function")return;' +
    'if(tapTimer){clearTimeout(tapTimer);}' +
    'tapTimer=setTimeout(function(){tapTimer=null;toggleHud();},210);}' +
    'v.addEventListener("click",onPictureTap);' +
    'v.addEventListener("dblclick",function(e){if(screenLocked){showUnlockHint();return;}if(!finePointer)return;' +
    'if(e&&e.preventDefault)e.preventDefault();toggleFs();});' +
    'var gTouch=null,pinchStart=null,lpTimer=null,lpActive=false,lpPrevRate=1,lpSuppressClick=false;' +
    'function showGestureHud(lbl,pct){if(!gestureHud)return;' +
    'gestureHud.innerHTML="<span>"+lbl+"</span><span class=\\"g-bar\\"><i style=\\"width:"+Math.round(pct*100)+"%\\"></i></span><span>"+Math.round(pct*100)+"%</span>";' +
    'gestureHud.hidden=false;}' +
    'function showGestureText(msg){if(!gestureHud)return;gestureHud.textContent=msg;gestureHud.hidden=false;}' +
    'function hideGestureHud(){if(gestureHud)gestureHud.hidden=true;}' +
    'function clearLongPress(){if(typeof clearTimeout==="function"&&lpTimer){clearTimeout(lpTimer);lpTimer=null;}' +
    'if(lpActive){lpActive=false;try{v.playbackRate=lpPrevRate;}catch(e){}if(speedPill)speedPill.hidden=true;}}' +
    'if(v&&v.addEventListener){' +
    'v.addEventListener("touchstart",function(e){if(screenLocked)return;' +
    'var ts=e&&e.touches;if(!ts)return;clearLongPress();' +
    'if(ts.length===2){var dx=ts[0].clientX-ts[1].clientX,dy=ts[0].clientY-ts[1].clientY;pinchStart=Math.hypot(dx,dy);gTouch=null;return;}' +
    'if(ts.length===1){var t=ts[0],w=window.innerWidth||400;' +
    'gTouch={x:t.clientX,y:t.clientY,right:t.clientX>w/2,startVol:v.volume||1,startBright:prefs.bright,startTime:Number.isFinite(v.currentTime)?v.currentTime:0,seekToTime:null,mode:null};' +
    'if(typeof setTimeout==="function"&&!v.paused){lpTimer=setTimeout(function(){lpTimer=null;if(!gTouch||gTouch.mode)return;lpActive=true;lpSuppressClick=true;lpPrevRate=v.playbackRate||prefs.speed||1;try{v.playbackRate=2;}catch(err){}if(speedPill)speedPill.hidden=false;},420);}}},{passive:true});' +
    'v.addEventListener("touchmove",function(e){if(screenLocked)return;' +
    'var ts=e&&e.touches;if(!ts)return;' +
    'if(ts.length===2&&pinchStart){clearLongPress();var dx=ts[0].clientX-ts[1].clientX,dy=ts[0].clientY-ts[1].clientY,dist=Math.hypot(dx,dy);' +
    'if(dist>pinchStart*1.16&&prefs.fit<2){pinchStart=dist;setFit(prefs.fit+1);}else if(dist<pinchStart*0.86&&prefs.fit>0){pinchStart=dist;setFit(prefs.fit-1);}return;}' +
    'if(!gTouch||ts.length!==1)return;' +
    'var t=ts[0],dy=gTouch.y-t.clientY,dx=t.clientX-gTouch.x,adx=Math.abs(dx),ady=Math.abs(dy);' +
    'if(adx>10||ady>10)clearLongPress();' +
    'if(!gTouch.mode){if(adx>=18&&adx>ady*1.25){gTouch.mode="seek";}else if(ady>=14&&ady>adx){gTouch.mode="vert";}else{return;}}' +
    'if(e.preventDefault)e.preventDefault();' +
    'if(gTouch.mode==="seek"){var dur=Number.isFinite(v.duration)&&v.duration>0?v.duration:0;if(!dur)return;' +
    'var deltaSec=Math.round(dx*0.25);var target=Math.max(0,Math.min(dur,gTouch.startTime+deltaSec));gTouch.seekToTime=target;' +
    'showGestureText((deltaSec>=0?"+":"")+deltaSec+"s \u00b7 "+fmt(target));return;}' +
    'var h=window.innerHeight||240,delta=dy/Math.max(140,h*0.7);' +
    'if(gTouch.right){if(volLocked){showGestureText("Use side buttons for volume");return;}' +
    'var nv=Math.max(0,Math.min(1,gTouch.startVol+delta));setVol(nv);showGestureHud("Vol",nv);}' +
    'else{var nb=Math.max(0.4,Math.min(1.25,gTouch.startBright+delta*0.85));prefs.bright=nb;savePrefs();applyBright();showGestureHud("Bright",(nb-0.4)/0.85);}},{passive:false});' +
    'v.addEventListener("touchend",function(){clearLongPress();if(gTouch&&gTouch.mode==="seek"&&gTouch.seekToTime!==null){seekTo(gTouch.seekToTime);}gTouch=null;pinchStart=null;hideGestureHud();},{passive:true});' +
    'v.addEventListener("touchcancel",function(){clearLongPress();gTouch=null;pinchStart=null;hideGestureHud();},{passive:true});}' +
    'function openMenuEl(){if(ccMenu&&!ccMenu.hidden)return ccMenu;if(qMenu&&!qMenu.hidden)return qMenu;if(spMenu&&!spMenu.hidden)return spMenu;if(moreMenu&&!moreMenu.hidden)return moreMenu;if(svMenu&&!svMenu.hidden)return svMenu;if(keysMenu&&!keysMenu.hidden)return keysMenu;return null;}' +
    'function moveMenuFocus(menu,step){if(!menu||!menu.querySelectorAll)return false;' +
    'var items=menu.querySelectorAll("[role=menuitem],button.qi,input.cc-filter");if(!items||!items.length)return false;' +
    'var arr=[],idx=-1,cur=document.activeElement;for(var i=0;i<items.length;i++){arr.push(items[i]);if(items[i]===cur)idx=i;}' +
    'var next=step==="home"?0:(step==="end"?arr.length-1:((idx+step+arr.length)%arr.length));' +
    'if(arr[next]&&arr[next].focus)try{arr[next].focus();}catch(e){}return true;}' +
    'function stepSpeed(delta){var idx=SPEEDS.indexOf(prefs.speed);if(idx<0)idx=3;' +
    'var next=SPEEDS[Math.max(0,Math.min(SPEEDS.length-1,idx+delta))];' +
    'setSpeed(next);showToast("Speed: "+speedLabel(next));}' +
    'function handleKey(k){if(typeof k!=="string"||!k)return false;if(screenLocked){showUnlockHint();return false;}var used=true;' +
    'if(k==="Escape"){closeMenus(true);return true;}' +
    'var om=openMenuEl();' +
    'if(om&&(k==="ArrowDown"||k==="ArrowUp"||k==="Home"||k==="End")){' +
    'return moveMenuFocus(om,k==="ArrowDown"?1:(k==="ArrowUp"?-1:(k==="Home"?"home":"end")));}' +
    'if(k===" "||k==="k"||k==="K"){togglePlay();}' +
    'else if(k==="ArrowRight"||k==="l"||k==="L"){seekBy(prefs.seek);}' +
    'else if(k==="ArrowLeft"||k==="j"||k==="J"){seekBy(-prefs.seek);}' +
    'else if(k==="ArrowUp"){setVol((v.volume||0)+0.1);}' +
    'else if(k==="ArrowDown"){setVol((v.volume||0)-0.1);}' +
    'else if(k==="m"||k==="M"){v.muted=!v.muted;prefs.muted=v.muted;savePrefs();' +
    'syncVolIcon();showToast(v.muted?"Muted":"Unmuted");}' +
    'else if(k==="f"||k==="F"){toggleFs();}' +
    'else if(k==="z"||k==="Z"){setFit((prefs.fit+1)%3);}' +
    'else if(k==="i"||k==="I"){toggleStats();showToast(statsOn?"Stats: On":"Stats: Off");}' +
    'else if(k==="c"||k==="C"){setCc(!ccOn);showToast(ccOn?"Captions: On":"Captions: Off");}' +
    'else if(k==="s"||k==="S"){if(btnSkip&&!btnSkip.hidden){btnSkip.click();}else if(!isCinema){seekBy(85);showToast("Jumped +85s");}}' +
    'else if(k==="n"||k==="N"){if(btnNext&&!btnNext.hidden){btnNext.click();}else if(btnNx&&!btnNx.hidden){btnNx.click();}}' +
    'else if(k==="]"||k===">"){stepSpeed(1);}' +
    'else if(k==="["||k==="<"){stepSpeed(-1);}' +
    'else if(k==="g"||k==="G"){setDelay(prefs.delay-0.1);showToast("Sub delay: "+fmtDelay(prefs.delay));}' +
    'else if(k==="h"||k==="H"){setDelay(prefs.delay+0.1);showToast("Sub delay: "+fmtDelay(prefs.delay));}' +
    'else if((k==="."||k===",")&&v.paused&&Number.isFinite(v.duration)){' +
    'var step=k==="."?(1/24):(-1/24);v.currentTime=Math.max(0,Math.min(v.duration,(v.currentTime||0)+step));updateUi();showToast(k==="."?"Frame +1":"Frame -1");}' +
    'else if(k==="?"){openKeysMenu();}' +
    'else if(/^[0-9]$/.test(k)){seekTo((v.duration||0)*Number(k)/10);}' +
    'else{used=false;}' +
    'if(used)wakeHud();return used;}' +
    'function trapMenuTab(e,menu){if(!menu||!menu.querySelectorAll)return false;' +
    'var raw=menu.querySelectorAll("button:not([hidden]):not([disabled]),input:not([hidden]):not([disabled]),[tabindex]:not([tabindex=\\"-1\\"])");' +
    'var items=[];for(var i=0;i<raw.length;i++){if(raw[i]&&!raw[i].hidden)items.push(raw[i]);}' +
    'if(!items.length)return false;var first=items[0],last=items[items.length-1],cur=document.activeElement;' +
    'if(e.shiftKey){if(cur===first||items.indexOf(cur)<0){if(last.focus)last.focus();return true;}}' +
    'else if(cur===last||items.indexOf(cur)<0){if(first.focus)first.focus();return true;}return false;}' +
    'window.addEventListener("keydown",function(e){' +
    'if(!e||e.ctrlKey||e.metaKey||e.altKey)return;' +
    'var om=openMenuEl();' +
    'if(e.key==="Tab"&&om){if(trapMenuTab(e,om)&&e.preventDefault)e.preventDefault();return;}' +
    'if(e.key==="Escape"&&om){closeMenus(true);if(e.preventDefault)e.preventDefault();return;}' +
    'var tag=e.target&&e.target.tagName;' +
    'if(tag==="INPUT"||tag==="TEXTAREA"||tag==="SELECT")return;' +
    'if(handleKey(e.key)){if(e.preventDefault)e.preventDefault();}});' +
    'if(window.Hls&&Hls.isSupported()){' +
    'var fatal=0;' +
    'makeHls=function(){' +
    (token
      ? 'var h=new Hls({maxBufferLength:30,xhrSetup:function(x,u){try{if(new URL(u,location.href).origin===location.origin){x.setRequestHeader("Authorization","Bearer "+' + safeScriptJson(String(token)) + ');}}catch(e){}}});'
      : 'var h=new Hls({maxBufferLength:30});') +
    'hlsInst=h;hlsDead=false;fatal=0;audioTracks=[];' +
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
    'if(Hls.Events.AUDIO_TRACKS_UPDATED){h.on(Hls.Events.AUDIO_TRACKS_UPDATED,function(ev,d){' +
    'audioTracks=(d&&Array.isArray(d.audioTracks))?d.audioTracks:(Array.isArray(h.audioTracks)?h.audioTracks:[]);' +
    'buildCcMenu();if(moreMenu&&!moreMenu.hidden)buildMoreMenu();});}' +
    'h.on(Hls.Events.MANIFEST_PARSED,function(){' +
    'if(Array.isArray(h.audioTracks)){audioTracks=h.audioTracks;buildCcMenu();}' +
    'if(qMenu&&btnQ&&Array.isArray(h.levels)&&h.levels.length>0){' +
    'qMenu.innerHTML="";var buildQ=function(){qMenu.innerHTML="";var autoQ=typeof h.autoLevelEnabled==="boolean"?h.autoLevelEnabled:h.currentLevel===-1;var mk=function(lbl,lvl){var b=document.createElement("button");b.type="button";' +
    'b.className="qi"+((lvl===-1?autoQ:(!autoQ&&h.currentLevel===lvl))?" on":"");b.textContent=lbl;if(b.setAttribute)b.setAttribute("role","menuitem");' +
    'b.onclick=function(){h.currentLevel=lvl;btnQ.textContent=lvl===-1?"Auto":lbl;qMenu.hidden=true;buildQ();syncAria();};qMenu.appendChild(b);};' +
    'mk("Auto",-1);h.levels.forEach(function(lv,idx){if(lv&&lv.height)mk(lv.height+"p",idx);});};buildQ();}' +
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
