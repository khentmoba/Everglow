'use strict';

function escHtml(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
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

function hlsPlayerHtml({ src, title, tracks, token, ep, audio, kind, servers, current }) {
  const isCinema = kind === 'cinema';
  const serverList = (Array.isArray(servers) ? servers : [])
    .filter((s) => s && s.id && s.url)
    .map((s) => ({ id: String(s.id), label: String(s.label || s.id), url: String(s.url) }));
  const currentServer = serverList.some((s) => s.id === current) ? current : serverList[0]?.id || '';
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
    '@keyframes egfs{from{opacity:.86;transform:scale(.982)}to{opacity:1;transform:scale(1)}}' +
    'body.fs-settle video,body.fs-settle #hud{animation:egfs .22s cubic-bezier(.22,1,.36,1)}' +
    '@media (prefers-reduced-motion:reduce){body.fs-settle video,body.fs-settle #hud{animation:none}}' +
    'video::cue{background:transparent!important;background-color:transparent!important;' +
    'color:#fff;font-family:"DM Sans",sans-serif;font-weight:800;' +
    'text-shadow:-1.5px -1.5px 0 rgba(0,0,0,.94),1.5px -1.5px 0 rgba(0,0,0,.94),' +
    '-1.5px 1.5px 0 rgba(0,0,0,.94),1.5px 1.5px 0 rgba(0,0,0,.94),' +
    '0 2px 5px rgba(0,0,0,.95),0 4px 12px rgba(0,0,0,.8)}' +
    '#sub-box{position:fixed;left:50%;transform:translateX(-50%);bottom:calc(118px + var(--sub-lift,0px));width:88%;' +
    'text-align:center;z-index:4;pointer-events:none;transition:bottom .24s cubic-bezier(.22,1,.36,1)}' +
    'body.idle #sub-box{bottom:30px}' +
    '#sub-txt{display:inline;background:transparent;color:#fff;' +
    'font-size:calc(clamp(15px,2.4vw,52px)*var(--sub-scale,1));' +
    'font-weight:800;line-height:1.35;letter-spacing:.01em;white-space:pre-line;' +
    'text-shadow:-1.5px -1.5px 0 rgba(0,0,0,.94),1.5px -1.5px 0 rgba(0,0,0,.94),' +
    '-1.5px 1.5px 0 rgba(0,0,0,.94),1.5px 1.5px 0 rgba(0,0,0,.94),' +
    '0 2px 5px rgba(0,0,0,.95),0 4px 12px rgba(0,0,0,.8)}' +
    '.ov{position:fixed;inset:0;display:flex;align-items:center;' +
    'justify-content:center;background:rgba(8,6,14,.74);backdrop-filter:blur(4px);z-index:8}' +
    '.ov[hidden]{display:none!important}[hidden]{display:none!important}' +
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
    '#hud{position:fixed;inset:0;display:flex;flex-direction:column;justify-content:space-between;' +
    'background:linear-gradient(180deg,rgba(10,6,14,.78) 0%,rgba(10,6,14,.22) 14%,transparent 26%,' +
    'transparent 50%,rgba(14,7,18,.62) 74%,rgba(14,7,18,.97) 100%);' +
    'z-index:5;transition:opacity .3s cubic-bezier(.22,1,.36,1);pointer-events:none}' +
    '.h-top,.h-bot{pointer-events:auto}' +
    'body.idle #hud{opacity:0;pointer-events:none}' +
    'body.idle .h-top,body.idle .h-bot{pointer-events:none}' +
    'body.idle{cursor:none}' +
    '.h-top,.h-bot{transition:transform .34s cubic-bezier(.22,1,.36,1)}' +
    'body.idle .h-top{transform:translateY(-14px)}body.idle .h-bot{transform:translateY(14px)}' +
    '.h-top{padding:18px 26px;display:flex;justify-content:flex-end;align-items:center;gap:12px}' +
    '#hud-title{display:block;max-width:100%;font-size:17px;font-weight:800;letter-spacing:.01em;color:#fff5f5;' +
    'text-shadow:0 2px 8px rgba(0,0,0,.78);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
    '.h-top-r{display:flex;align-items:center;gap:8px;flex-shrink:0}' +
    '.sd-box{display:flex;background:rgba(18,10,24,.58);border-radius:999px;padding:2px;' +
    'border:1px solid rgba(255,140,175,.18);backdrop-filter:blur(10px)}' +
    '.sd-b{border:0;background:transparent;padding:3px 10px;font-size:10.5px;font-weight:800;' +
    'border-radius:999px;color:#e4bfd0;cursor:pointer;font-family:inherit;transition:background .15s ease,color .15s ease}' +
    '.sd-b:hover{color:#fff5f5}' +
    '.sd-b.on{background:linear-gradient(135deg,#c2185b,#e91e63);color:#fff5f5;box-shadow:0 2px 10px rgba(194,24,91,.42)}' +
    '.h-bot{padding:0 26px 18px;display:flex;flex-direction:column;gap:12px}' +
    '.bar-row{display:flex;align-items:center;gap:16px}' +
    '.cplay{position:fixed;top:50%;left:50%;width:76px;height:76px;margin:-38px 0 0 -38px;' +
    'border-radius:50%;border:2px solid rgba(255,140,175,.55);background:rgba(14,7,18,.5);' +
    'color:#fff5f5;display:none;align-items:center;justify-content:center;cursor:pointer;' +
    'box-shadow:0 0 30px rgba(194,24,91,.35);pointer-events:auto;' +
    'transition:transform .2s cubic-bezier(.34,1.56,.64,1),background .15s ease}' +
    '.cplay:active{transform:scale(.88)}.cplay svg{width:34px;height:34px}' +
    'body.idle .cplay{pointer-events:none}' +
    '#flash{position:fixed;top:50%;left:50%;width:84px;height:84px;margin:-42px 0 0 -42px;' +
    'border-radius:50%;display:flex;flex-direction:column;align-items:center;justify-content:center;' +
    'background:rgba(14,7,18,.52);border:2px solid rgba(255,140,175,.55);' +
    'box-shadow:0 0 30px rgba(194,24,91,.38);color:#fff5f5;z-index:6;pointer-events:none;opacity:0}' +
    '#flash.l{left:26%}#flash.r{left:74%}' +
    '#flash svg{width:32px;height:32px}' +
    '#flash b{font-size:12px;font-weight:800;margin-top:1px;color:#ff8caf}' +
    '#flash.go{animation:egflash .62s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egflash{0%{opacity:0;transform:scale(.6)}25%{opacity:1;transform:scale(1.06)}' +
    '60%{opacity:1;transform:scale(1)}100%{opacity:0;transform:scale(1.2)}}' +
    '#binge{position:fixed;left:0;right:0;bottom:128px;padding:0 26px;z-index:7;' +
    'display:flex;justify-content:flex-end;align-items:center;min-height:34px;' +
    'pointer-events:none}' +
    '#binge .b-act{pointer-events:auto}' +
    '.b-scrim{position:absolute;right:-20px;bottom:-14px;width:340px;height:120px;' +
    'pointer-events:none;background:radial-gradient(ellipse at 78% 62%,' +
    'rgba(10,5,16,.84) 0%,rgba(10,5,16,.5) 45%,transparent 72%)}' +
    '#b-scrim[hidden]{display:none!important}' +
    '.b-act{position:relative;display:inline-flex;align-items:center;gap:8px;' +
    'padding:6px 2px 9px;border:0;background:transparent;font-family:inherit;' +
    'font-size:14px;font-weight:800;letter-spacing:.01em;color:#fff5f5;cursor:pointer;' +
    'text-shadow:0 2px 6px rgba(0,0,0,.9),0 4px 16px rgba(0,0,0,.7);' +
    'transition:color .15s ease}' +
    '.b-act:hover{color:#fff}' +
    '.b-act:not([hidden]){animation:egbin .38s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egbin{from{opacity:0;transform:translateX(18px)}to{opacity:1;transform:none}}' +
    '.b-ico{display:inline-flex}' +
    '.b-skip .b-ico{color:#f5c97b}' +
    '.b-next .b-ico{color:#ff8caf}' +
    '.b-t{color:#f5c97b;font-variant-numeric:tabular-nums;font-weight:800}' +
    '.b-next .b-t{color:rgba(255,245,245,.72)}' +
    '.b-u{position:absolute;left:2px;right:2px;bottom:3px;height:2px;border-radius:2px;' +
    'overflow:hidden;background:rgba(255,255,255,.14)}' +
    '.b-u i{display:block;height:100%;width:100%;transition:width .2s linear}' +
    '.b-skip .b-u i{background:#f5c97b}' +
    '.b-next .b-u i{background:linear-gradient(90deg,#c2185b,#e91e63)}' +
    '#scrub-wrap{position:relative;flex:1;min-width:0;padding:6px 0 2px}' +
    '#scrub-prev{position:absolute;bottom:22px;left:0;transform:translateX(-50%);' +
    'width:168px;pointer-events:none;z-index:10;display:flex;flex-direction:column;' +
    'align-items:center;gap:6px;transition:opacity .12s ease}' +
    '#scrub-prev[hidden]{display:none!important}' +
    '#scrub-prev:not([hidden]){animation:egprev .18s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egprev{from{opacity:0;transform:translateX(-50%) translateY(8px) scale(.9)}' +
    'to{opacity:1;transform:translateX(-50%)}}' +
    '.pv-box{position:relative;width:100%;aspect-ratio:16/9;border-radius:8px;overflow:hidden;' +
    'background:#120916;border:1.5px solid rgba(255,111,145,.68);' +
    'box-shadow:0 12px 30px rgba(0,0,0,.86),0 0 20px rgba(194,24,91,.34)}' +
    '#pv,#pv-c{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:block}' +
    '#pv-c[hidden]{display:none!important}' +
    '#pv-load{position:absolute;left:0;right:0;bottom:0;height:2.5px;overflow:hidden;' +
    'background:rgba(255,255,255,.12);opacity:0;transition:opacity .15s ease}' +
    '#scrub-prev.loading #pv-load{opacity:1}' +
    '#pv-load i{display:block;width:45%;height:100%;' +
    'background:linear-gradient(90deg,transparent,#e91e63,transparent);' +
    'animation:egpv 1s ease-in-out infinite}' +
    '@keyframes egpv{0%{transform:translateX(-100%)}100%{transform:translateX(260%)}}' +
    '.pv-meta{display:inline-flex;align-items:center;gap:6px;padding:2px 9px;border-radius:999px;' +
    'background:rgba(16,8,20,.9);border:1px solid rgba(255,140,175,.3);' +
    'box-shadow:0 4px 12px rgba(0,0,0,.65)}' +
    '#pv-time{font-size:11.5px;font-weight:800;font-variant-numeric:tabular-nums;' +
    'color:#fff5f5;letter-spacing:.02em}' +
    '#pv-tag{font-size:9.5px;font-weight:800;letter-spacing:.05em;text-transform:uppercase;color:#ff8caf}' +
    '#pv-tag[hidden]{display:none!important}' +
    '#scrub{position:relative;height:4px;border-radius:999px;background:rgba(255,245,245,.22);' +
    'cursor:pointer;outline:none;touch-action:none;transition:height .14s cubic-bezier(.22,1,.36,1)}' +
    '#scrub::before{content:"";position:absolute;left:0;right:0;top:-11px;bottom:-11px}' +
    '#scrub:hover,body.scrubbing #scrub{height:7px}' +
    '#scrub:focus-visible{box-shadow:0 0 0 3px rgba(255,111,145,.5)}' +
    '#s-buf{position:absolute;left:0;top:0;bottom:0;width:0%;background:rgba(255,230,240,.28);border-radius:999px}' +
    '#s-hover{position:absolute;left:0;top:0;bottom:0;width:0%;background:rgba(255,140,175,.38);' +
    'border-radius:999px;pointer-events:none;z-index:1}' +
    '#s-fill{position:absolute;left:0;top:0;bottom:0;width:0%;' +
    'background:linear-gradient(90deg,#c2185b 0%,#e91e63 100%);' +
    'box-shadow:0 0 10px rgba(255,111,145,.45);z-index:2;border-radius:999px}' +
    '#s-thumb{position:absolute;top:50%;left:0%;width:12px;height:12px;border-radius:50%;' +
    'background:#e91e63;border:2px solid #fff5f5;' +
    'box-shadow:0 0 0 3px rgba(194,24,91,.35),0 2px 8px rgba(0,0,0,.6);' +
    'transform:translate(-50%,-50%) scale(.82);opacity:0;z-index:4;pointer-events:none;' +
    'transition:transform .14s ease,opacity .14s ease}' +
    '#scrub:hover #s-thumb,body.scrubbing #s-thumb,#scrub:focus-visible #s-thumb{' +
    'opacity:1;transform:translate(-50%,-50%) scale(1.08)}' +
    '@media (hover:none),(pointer:coarse){#s-thumb{opacity:1;transform:translate(-50%,-50%) scale(.92)}}' +
    '.s-chap{position:absolute;top:0;bottom:0;background:rgba(245,201,123,.62);' +
    'border-left:1px solid #f5c97b;border-right:1px solid #f5c97b;z-index:3;pointer-events:none}' +
    '.ctrl-r{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:14px;font-size:12px;color:#f5dce4}' +
    '.ctrl-l,.ctrl-rt{display:flex;align-items:center;gap:20px}' +
    '.ctrl-l{justify-self:start}.ctrl-rt{justify-self:end;gap:16px}' +
    '.ctrl-mid{display:flex;flex-direction:column;align-items:center;gap:4px;min-width:0;max-width:38vw;text-align:center}' +
    '.ib{border:0;background:transparent;color:#fff5f5;display:inline-flex;align-items:center;' +
    'justify-content:center;cursor:pointer;padding:6px;border-radius:50%;opacity:.94;' +
    'transition:transform .2s cubic-bezier(.34,1.56,.64,1),color .15s ease,background .15s ease,opacity .15s ease}' +
    '.ib svg{width:26px;height:26px;overflow:visible}' +
    '.ib:hover{opacity:1;color:#ff8caf;background:rgba(255,111,145,.12);transform:scale(1.14)}' +
    '.ib:active{transform:scale(.86)}' +
    '.ib.on{color:#ff8caf}' +
    '.ib.pop svg{animation:egpop .34s cubic-bezier(.34,1.56,.64,1)}' +
    '.ib.spin-l svg{animation:egsl .5s cubic-bezier(.22,1,.36,1)}' +
    '.ib.spin-r svg{animation:egsr .5s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egpop{0%{transform:scale(.6)}100%{transform:scale(1)}}' +
    '@keyframes egsl{0%{transform:rotate(0)}40%{transform:rotate(-50deg)}100%{transform:rotate(0)}}' +
    '@keyframes egsr{0%{transform:rotate(0)}40%{transform:rotate(50deg)}100%{transform:rotate(0)}}' +
    '#vol-wrap{display:flex;align-items:center;gap:6px}' +
    '#vol-range{width:0;opacity:0;height:16px;margin:0;padding:0;accent-color:#e91e63;' +
    'background:transparent;cursor:pointer;overflow:hidden;' +
    'transition:width .2s cubic-bezier(.22,1,.36,1),opacity .18s ease}' +
    '#vol-wrap:hover #vol-range,#vol-wrap:focus-within #vol-range{width:74px;opacity:1}' +
    '@media (hover:none),(pointer:coarse){#vol-range{display:none}}' +
    '#btn-speed{min-width:32px}' +
    '#buf{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;' +
    'z-index:6;pointer-events:none}' +
    '.buf-ring{width:38px;height:38px;border-radius:50%;' +
    'border:3px solid rgba(255,245,245,.18);border-top-color:#e91e63;' +
    'animation:egspin .85s linear infinite}' +
    '@keyframes egspin{to{transform:rotate(360deg)}}' +
    '#time-lbl{font-variant-numeric:tabular-nums;font-weight:700;color:rgba(255,245,245,.92);font-size:14px;white-space:nowrap}' +
    '.chip{border:1px solid rgba(255,140,175,.22);background:rgba(18,10,24,.56);' +
    'backdrop-filter:blur(10px);color:#fff5f5;border-radius:999px;padding:4px 11px;' +
    'font-size:11px;font-weight:700;cursor:pointer;font-family:inherit;font-variant-numeric:tabular-nums;' +
    'transition:background .15s ease,border-color .15s ease,color .15s ease,transform .2s cubic-bezier(.34,1.56,.64,1)}' +
    '.chip:active{transform:scale(.92)}' +
    '.chip:hover{background:rgba(194,24,91,.28);border-color:rgba(255,111,145,.55)}' +
    '.chip.on{border-color:rgba(255,111,145,.6);background:rgba(194,24,91,.34)}' +
    '.ctrl-rt .chip{border-color:transparent;background:transparent;backdrop-filter:none;' +
    'border-radius:6px;padding:4px 8px;font-size:13.5px;font-weight:800;color:rgba(255,245,245,.9)}' +
    '.ctrl-rt .chip:hover{background:rgba(255,111,145,.18);border-color:transparent;color:#fff5f5}' +
    '.ctrl-rt .chip.on{color:#ff8caf;background:rgba(194,24,91,.2);border-color:rgba(255,111,145,.34)}' +
    '.eg-badge{display:inline-flex;align-items:center;gap:6px}' +
    '.eg-cat{width:16px;height:16px;border-radius:50%;object-fit:cover;' +
    'border:1.5px solid rgba(255,160,190,.75)}' +
    '.eg-w{font-family:"Bebas Neue",Impact,sans-serif;font-size:14.5px;letter-spacing:.07em;line-height:1}' +
    '.eg-w b{color:#fff5f5;font-weight:400}' +
    '.eg-w i{color:#e91e63;font-style:normal;text-shadow:0 2px 10px rgba(255,111,145,.58)}' +
    '#q-menu,#cc-menu,#sp-menu,#sv-menu{position:fixed;right:26px;bottom:96px;width:176px;' +
    'background:rgba(16,9,20,.94);backdrop-filter:blur(18px);' +
    'border:1px solid rgba(255,111,145,.26);border-radius:12px;' +
    'padding:8px;z-index:12;box-shadow:0 16px 36px rgba(0,0,0,.78);transform-origin:bottom right}' +
    '#q-menu:not([hidden]),#cc-menu:not([hidden]),#sp-menu:not([hidden]){animation:egmenu .22s cubic-bezier(.22,1,.36,1)}' +
    '#sv-menu{top:62px;bottom:auto;transform-origin:top right}' +
    '#sv-menu:not([hidden]){animation:egmenud .22s cubic-bezier(.22,1,.36,1)}' +
    '@keyframes egmenu{from{opacity:0;transform:translateY(10px) scale(.95)}to{opacity:1;transform:none}}' +
    '@keyframes egmenud{from{opacity:0;transform:translateY(-10px) scale(.95)}to{opacity:1;transform:none}}' +
    '.qi{display:flex;justify-content:space-between;align-items:center;width:100%;border:0;' +
    'background:transparent;color:#f3d2de;padding:6px 8px;border-radius:6px;font-size:11.5px;' +
    'font-weight:600;cursor:pointer;font-family:inherit;text-align:left;' +
    'transition:background .12s ease,color .12s ease,transform .16s cubic-bezier(.34,1.56,.64,1)}' +
    '.qi:active{transform:scale(.96)}' +
    '.qi:hover{background:rgba(255,111,145,.14);color:#fff5f5}' +
    '.qi.on{background:rgba(194,24,91,.34);color:#fff5f5}' +
    '#cc-menu{width:260px;max-height:56vh;overflow-y:auto}' +
    '#sv-menu{max-height:calc(100vh - 76px);overflow-y:auto}' +
    '@media (hover:none),(pointer:coarse){.cplay{display:flex}#btn-play{display:none}}' +
    '@media (prefers-reduced-motion:reduce){*:not(.wc):not(.buf-ring):not(#pv-load i){animation:none!important;transition:none!important}}' +
    '.cc-h{font-size:9.5px;font-weight:800;letter-spacing:.09em;text-transform:uppercase;' +
    'color:#c79ab0;padding:8px 8px 3px}' +
    '.cc-row{display:flex;gap:4px;align-items:center;padding:0 4px 4px}' +
    '.cc-row .qi{flex:1;justify-content:center;padding:5px 4px;text-align:center}' +
    '.chip[hidden]{display:none}' +
    '@media (max-width:520px){.h-top{padding:10px 14px}.h-bot{padding:0 14px 10px;gap:8px}' +
    '.ctrl-l,.ctrl-rt{gap:10px}.ctrl-r{gap:8px}#vol-wrap{display:none}#btn-speed{display:none}#btn-pip{display:none}' +
    '.ib{padding:4px}.ib svg{width:22px;height:22px}.bar-row{gap:10px}' +
    '#time-lbl{font-size:11.5px}#binge{padding:0 14px;bottom:104px}#sub-box{bottom:calc(96px + var(--sub-lift,0px))}' +
    '#scrub-prev{width:124px;bottom:20px}.pv-meta{padding:1px 7px}#pv-time{font-size:10.5px}' +
    '.ctrl-mid{max-width:34vw;gap:2px}.cplay{width:62px;height:62px;margin:-31px 0 0 -31px}.cplay svg{width:28px;height:28px}' +
    '.eg-w{font-size:12px;letter-spacing:.05em}.eg-badge{gap:4px}.eg-cat{width:13px;height:13px}' +
    '#q-menu,#cc-menu,#sp-menu{right:14px;bottom:78px}#sv-menu{right:14px;top:48px}' +
    '.chip{padding:3px 8px;font-size:10.5px}.ctrl-rt .chip{padding:3px 6px;font-size:12px}#hud-title{font-size:13.5px}}' +
    '@media (max-width:380px){.eg-w{display:none}}' +
    '@media (max-height:300px){.cplay{width:46px;height:46px;margin:-23px 0 0 -23px;top:40%}.cplay svg{width:20px;height:20px}' +
    '#flash{width:58px;height:58px;margin:-29px 0 0 -29px}#flash svg{width:22px;height:22px}}' +
    '</style></head><body>' +
    '<video id="v" playsinline autoplay preload="auto" crossorigin="anonymous">' +
    (trackTags ? '\n    ' + trackTags : '') +
    '</video>\n' +
    '<div id="sub-box"><span id="sub-txt"></span></div>\n' +
    '<div id="hud">' +
    '<div class="h-top">' +
    '<div class="h-top-r">' +
    '<button type="button" class="chip" id="btn-sv" aria-haspopup="true"' +
    (serverList.length > 1 ? '' : ' hidden') + '>Servers</button>' +
    (isCinema
      ? ''
      : '<div class="sd-box">' +
        '<button type="button" class="sd-b' + (isDub ? '' : ' on') + '" id="btn-sub">SUB</button>' +
        '<button type="button" class="sd-b' + (isDub ? ' on' : '') + '" id="btn-dub">DUB</button>' +
        '</div>') +
    '</div></div>' +
    '<button type="button" class="cplay" id="cplay" aria-label="Play or pause">' +
    '<svg viewBox="0 0 20 20"><path id="cplay-p" fill="currentColor" d="M4 3h3.5v14H4zM12.5 3H16v14h-3.5z"/></svg></button>' +
    '<div class="h-bot">' +
    '<div class="bar-row">' +
    '<div id="scrub-wrap">' +
    '<div id="scrub-prev" hidden>' +
    '<div class="pv-box"><video id="pv" muted playsinline preload="none" crossorigin="anonymous"></video><canvas id="pv-c" hidden></canvas><div id="pv-load"><i></i></div></div>' +
    '<div class="pv-meta"><span id="pv-time">00:00</span><span id="pv-tag" hidden></span></div>' +
    '</div>' +
    '<div id="scrub">' +
    '<div id="s-buf"></div>' +
    '<div id="s-hover"></div>' +
    '<div id="s-fill"></div>' +
    '<div class="s-chap" id="s-op" hidden></div>' +
    '<div class="s-chap" id="s-ed" hidden></div>' +
    '<div id="s-thumb"></div>' +
    '</div>' +
    '</div>' +
    '<span id="time-lbl">00:00</span>' +
    '</div>' +
    '<div class="ctrl-r">' +
    '<div class="ctrl-l">' +
    '<button type="button" class="ib" id="btn-play" aria-label="Play or pause">' +
    '<svg viewBox="0 0 20 20"><path id="play-p" fill="currentColor" d="M4 3h3.5v14H4zM12.5 3H16v14h-3.5z"/></svg></button>' +
    '<button type="button" class="ib" id="btn-rew" aria-label="Rewind 10 seconds">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><text x="12" y="15.3" text-anchor="middle" fill="currentColor" stroke="none" font-family="system-ui,sans-serif" font-size="7.5" font-weight="800">10</text></svg></button>' +
    '<button type="button" class="ib" id="btn-ff" aria-label="Forward 10 seconds">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><text x="12" y="15.3" text-anchor="middle" fill="currentColor" stroke="none" font-family="system-ui,sans-serif" font-size="7.5" font-weight="800">10</text></svg></button>' +
    '<span id="vol-wrap">' +
    '<button type="button" class="ib" id="btn-vol" aria-label="Mute or unmute">' +
    '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><polygon points="9 4 5 7.5 2 7.5 2 12.5 5 12.5 9 16 9 4" fill="currentColor"/><path id="vol-w" d="M12.5 7a4 4 0 0 1 0 6M15 4.8a7.2 7.2 0 0 1 0 10.4"/></svg></button>' +
    '<input type="range" id="vol-range" min="0" max="1" step="0.01" value="1" aria-label="Volume">' +
    '</span>' +
    '</div>' +
    '<div class="ctrl-mid">' +
    '<span id="hud-title">' + displayTitle + '</span>' +
    '<div class="eg-badge">' +
    '<img class="eg-cat" src="https://everglow-1c6db.web.app/favicon.png" alt="">' +
    '<span class="eg-w"><b>EVER</b><i>GLOW</i></span>' +
    '</div></div>' +
    '<div class="ctrl-rt">' +
    '<button type="button" class="ib" id="btn-nx" aria-label="Next episode" hidden>' +
    '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M4 5l10 7-10 7zM16 5h3v14h-3z"/></svg></button>' +
    (isCinema
      ? ''
      : '<button type="button" class="ib" id="btn-eps" aria-label="Episodes">' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="13" height="9" rx="1.5"/><path d="M7 18h13V9"/></svg></button>') +
    '<button type="button" class="ib on" id="btn-cc" aria-label="Subtitles" aria-haspopup="true"' +
    (trackTags ? '' : ' hidden') + '>' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"><path d="M4 5h16v11H9l-5 4z"/><path d="M8 9.5h3M13 9.5h3M8 12.5h6" stroke-linecap="round"/></svg></button>' +
    '<button type="button" class="chip" id="btn-speed" aria-label="Playback speed" aria-haspopup="true">1x</button>' +
    '<button type="button" class="chip" id="btn-q" aria-label="Quality">Auto</button>' +
    '<button type="button" class="ib" id="btn-pip" aria-label="Picture in picture">' +
    '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="4" width="15" height="12" rx="2"/><rect x="10.2" y="9.4" width="6" height="4.8" rx="1" fill="currentColor" stroke="none"/></svg></button>' +
    '<button type="button" class="ib" id="btn-fs" aria-label="Fullscreen">' +
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
    'var fsP=document.getElementById("fs-p");' +
    'var btnSkip=document.getElementById("btn-skip");' +
    'var btnNext=document.getElementById("btn-next");' +
    'var btnSub=document.getElementById("btn-sub");' +
    'var btnDub=document.getElementById("btn-dub");' +
    'var btnEps=document.getElementById("btn-eps");' +
    'var btnNx=document.getElementById("btn-nx");' +
    'var cplay=document.getElementById("cplay");' +
    'var cplayP=document.getElementById("cplay-p");' +
    'var flashEl=document.getElementById("flash");' +
    'var FLASH=' + JSON.stringify(FLASH_ICONS) + ';' +
    'function kick(el,cls){if(!el||!el.classList)return;el.classList.remove(cls);' +
    'void el.offsetWidth;el.classList.add(cls);}' +
    'function flash(kind){if(!flashEl||!flashEl.classList||!FLASH[kind])return;' +
    'if((kind==="play"||kind==="pause")&&!finePointer)return;' +
    'flashEl.innerHTML=FLASH[kind];flashEl.className=kind==="rew"?"l":kind==="ff"?"r":"";' +
    'kick(flashEl,"go");}' +
    'var subTxt=document.getElementById("sub-txt");' +
    'var subBox=document.getElementById("sub-box");' +
    'var skipTime=document.getElementById("skip-time");' +
    'var skipFill=document.getElementById("skip-fill");' +
    'var nextLbl=document.getElementById("next-lbl");' +
    'var nextTok=document.getElementById("next-tok");' +
    'var nextFill=document.getElementById("next-fill");' +
    'var episode=' + JSON.stringify(epNum) + ';' +
    'var opRange=null,edRange=null,activeSkipEnd=null,hlsInst=null,hlsDead=false,makeHls=null,picking=false;' +
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
    'function updateBingeScrim(){var sc=document.getElementById("b-scrim");if(sc){' +
    'sc.hidden=(!btnSkip||btnSkip.hidden)&&(!btnNext||btnNext.hidden);}}' +
    'function updateSkipBtn(){if(!btnSkip)return;var t=v.currentTime;' +
    'if(opRange&&t>=opRange[0]&&t<opRange[1]){activeSkipEnd=opRange[1];' +
    'if(skipTime)skipTime.textContent=fmt(Math.max(0,opRange[1]-t));' +
    'var p=through(opRange,t);if(skipFill&&p!==null)skipFill.style.width=((1-p)*100)+"%";' +
    'btnSkip.hidden=false;updateBingeScrim();return;}' +
    'activeSkipEnd=null;btnSkip.hidden=true;updateBingeScrim();}' +
    'function updateNextBtn(){if(btnNx)btnNx.hidden=!nextToken&&nextKind!=="season";if(!btnNext)return;' +
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
    'function updateBuffer(){if(!sBuf||!v.buffered||!Number.isFinite(v.duration)||v.duration<=0)return;' +
    'var t=Number.isFinite(v.currentTime)?v.currentTime:0,end=0;' +
    'for(var i=0;i<v.buffered.length;i++){try{if(t>=v.buffered.start(i)-0.5&&v.buffered.end(i)>end)end=v.buffered.end(i);}catch(e){}}' +
    'if(!end&&v.buffered.length>0){try{end=v.buffered.end(v.buffered.length-1);}catch(e){}}' +
    'sBuf.style.width=Math.min(100,Math.max(0,end/v.duration*100))+"%";}' +
    'v.addEventListener("progress",updateBuffer);' +
    'function updateUi(){var p=v.currentTime,d=v.duration;' +
    'if(Number.isFinite(p)&&Number.isFinite(d)&&d>0){' +
    'var pctStr=Math.min(100,Math.max(0,p/d*100))+"%";' +
    'if(sFill&&!dragging)sFill.style.width=pctStr;' +
    'if(sThumb&&!dragging)sThumb.style.left=pctStr;' +
    'if(timeLbl&&!dragging)timeLbl.textContent=fmt(d-p);' +
    'if(scrub){scrub.setAttribute("aria-valuenow",String(Math.round(p)));' +
    'scrub.setAttribute("aria-valuemin","0");' +
    'scrub.setAttribute("aria-valuemax",String(Math.round(d)));}}' +
    'updateBuffer();renderCues();updateSkipBtn();updateNextBtn();}' +
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
    'if(cplayP)cplayP.setAttribute("d","M5 3.5l12 6.5-12 6.5V3.5z");' +
    'if(buf)buf.hidden=true;progress(true);});' +
    'v.addEventListener("ended",function(){progress(true);});' +
    'function hideBoot(){boot.style.display="none";}' +
    'function showTap(){tapw.hidden=false;}' +
    'function tryPlay(){var p;try{p=v.play();}catch(e){showTap();return;}' +
    'if(p&&p.catch){p.catch(function(err){' +
    'if(err&&(err.name==="AbortError"||err.code===20))return;showTap();});}}' +
    'function giveUp(){hideBoot();tapw.hidden=true;dead.hidden=false;' +
    'if(pickSeq>0){if(svMenu){buildSvMenu();svMenu.hidden=false;}' +
    'dead.style.paddingRight="190px";return;}' +
    'post("animex-content-error");}' +
    'tap.addEventListener("click",function(){tapw.hidden=true;tryPlay();});' +
    'var started=false;' +
    'var stallT=null;' +
    'function clearStall(){if(typeof clearTimeout==="function"&&stallT){clearTimeout(stallT);stallT=null;}}' +
    'function armStall(){clearStall();if(typeof setTimeout==="function"){' +
    'stallT=setTimeout(function(){stallT=null;if(!v.paused&&!v.ended)giveUp();},15000);}}' +
    'v.addEventListener("playing",function(){started=true;clearStall();hideBoot();tapw.hidden=true;' +
    'if(buf)buf.hidden=true;' +
    'if(dead){dead.hidden=true;dead.style.paddingRight="";}' +
    'if(picking){picking=false;if(svMenu)svMenu.hidden=true;}' +
    'if(playP)playP.setAttribute("d","M4 3h3.5v14H4zM12.5 3H16v14h-3.5z");' +
    'if(cplayP)cplayP.setAttribute("d","M4 3h3.5v14H4zM12.5 3H16v14h-3.5z");});' +
    'v.addEventListener("canplay",function(){clearStall();if(buf)buf.hidden=true;});' +
    'v.addEventListener("pause",clearStall);v.addEventListener("ended",clearStall);' +
    'v.addEventListener("waiting",function(){' +
    'if(!v.paused&&!v.ended)armStall();' +
    'if(!started){if(dead.hidden)boot.style.display="flex";return;}' +
    'if(buf)buf.hidden=false;});' +
    'if(btnPlay)btnPlay.addEventListener("click",function(){togglePlay();kick(btnPlay,"pop");});' +
    'if(cplay)cplay.addEventListener("click",function(){togglePlay();kick(cplay,"pop");wakeHud();});' +
    'if(btnRew)btnRew.addEventListener("click",function(){seekBy(-10);kick(btnRew,"spin-l");});' +
    'if(btnFf)btnFf.addEventListener("click",function(){seekBy(10);kick(btnFf,"spin-r");});' +
    'if(btnNx)btnNx.addEventListener("click",function(){post({type:"animex-action",action:"next-episode"});});' +
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
    'var fsT=null;function isFs(){var d=document;return !!(d.fullscreenElement||d.webkitFullscreenElement);}' +
    'function syncFsUi(){var on=isFs();if(document.body&&document.body.classList){' +
    'document.body.classList.toggle("is-fs",on);document.body.classList.remove("fs-settle");' +
    'document.body.classList.add("fs-settle");' +
    'if(typeof clearTimeout==="function"&&fsT)clearTimeout(fsT);' +
    'if(typeof setTimeout==="function"){fsT=setTimeout(function(){' +
    'if(document.body&&document.body.classList)document.body.classList.remove("fs-settle");},240);}}' +
    'if(btnFs){btnFs.setAttribute("aria-label",on?"Exit fullscreen":"Fullscreen");' +
    'btnFs.classList.toggle("on",on);' +
    'if(fsP)fsP.setAttribute("d",on?"M7 3v4H3M13 3v4h4M7 17v-4H3M13 17v-4h4":"M3 7V3h4M17 7V3h-4M3 13v4h4M17 13v4h-4");}' +
    'placeSubs();if(typeof wakeHud==="function")wakeHud();}' +
    'function toggleFs(){var doc=document;var root=doc.documentElement||v;' +
    'if(isFs()){if(doc.exitFullscreen)doc.exitFullscreen();else if(doc.webkitExitFullscreen)doc.webkitExitFullscreen();}' +
    'else if(root.requestFullscreen){root.requestFullscreen();}' +
    'else if(root.webkitRequestFullscreen){root.webkitRequestFullscreen();}' +
    'else if(v.webkitEnterFullscreen){v.webkitEnterFullscreen();}}' +
    'if(document.addEventListener){document.addEventListener("fullscreenchange",syncFsUi);' +
    'document.addEventListener("webkitfullscreenchange",syncFsUi);}' +
    'if(btnFs)btnFs.addEventListener("click",toggleFs);' +
    'function inOpenMenu(t){while(t){if((t===ccMenu||t===svMenu||t===qMenu||t===spMenu)&&!t.hidden)return true;t=t.parentNode||t.parentElement;}return false;}' +
    'window.addEventListener("wheel",function(e){if(!e||isFs()||inOpenMenu(e.target))return;' +
    'var dx=Number(e.deltaX)||0,dy=Number(e.deltaY)||0;if(!dx&&!dy)return;' +
    'post({type:"everglow-embed-scroll",deltaX:dx,deltaY:dy,deltaMode:Number(e.deltaMode)||0});},{passive:true});' +
    'if(btnQ&&qMenu)btnQ.addEventListener("click",function(){qMenu.hidden=!qMenu.hidden;' +
    'if(!qMenu.hidden){if(ccMenu)ccMenu.hidden=true;if(spMenu)spMenu.hidden=true;}placeSubs();});' +
    'if(btnSpeed&&spMenu)btnSpeed.addEventListener("click",function(){' +
    'spMenu.hidden=!spMenu.hidden;' +
    'if(!spMenu.hidden){buildSpeedMenu();if(qMenu)qMenu.hidden=true;if(ccMenu)ccMenu.hidden=true;}placeSubs();});' +
    'var pickSeq=0;' +
    'function setTracks(list){var old=v.querySelectorAll?v.querySelectorAll("track"):[];' +
    'for(var i=old.length-1;i>=0;i--){try{v.removeChild(old[i]);}catch(e){}}' +
    'cueList=[];cueTrack=-1;cueFetching=-1;cueFetchSeq++;' +
    'var arr=Array.isArray(list)?list:[],added=0;' +
    'for(var k=0;k<arr.length&&added<8;k++){var t=arr[k];if(!t||!t.file)continue;' +
    'var el=document.createElement("track");el.kind="captions";el.src=String(t.file);' +
    'if(t.label)el.label=String(t.label);if(added===0)el.default=true;added++;' +
    'try{v.appendChild(el);}catch(e){}}' +
    'buildCcMenu();syncCues();}' +
    'function buildSvMenu(){if(!svMenu)return;svMenu.innerHTML="";' +
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
    'if(btnSv&&svMenu)btnSv.addEventListener("click",function(){svMenu.hidden=!svMenu.hidden;' +
    'if(!svMenu.hidden){buildSvMenu();if(qMenu)qMenu.hidden=true;' +
    'if(ccMenu)ccMenu.hidden=true;if(spMenu)spMenu.hidden=true;}placeSubs();});' +
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
    'var cueList=[],cueTrack=-1,cueFetching=-1,cueFetchSeq=0;' +
    'function cleanCueText(s){return String(s||"").replace(/\\{\\\\[^}]*\\}/g,"").replace(/<[^>]+>/g,"").trim();}' +
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
    'if(subTxt.textContent!==next)subTxt.textContent=next;}' +
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
    'if(!v.paused&&!hoveringScrub&&!dragging&&(!ccMenu||ccMenu.hidden)&&(!spMenu||spMenu.hidden)&&document.body&&document.body.classList){' +
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
    'if(btnVol)btnVol.style.opacity=v.muted?"0.45":"0.92";}' +
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
    'function ensurePreview(){if(!pv||!activeSrc||pvFailed)return;if(pvLoadedSrc===activeSrc&&(pvHls||!window.Hls||!Hls.isSupported()))return;' +
    'pvLoadedSrc=activeSrc;pvReady=false;' +
    'if(window.Hls&&Hls.isSupported()){' +
    'if(pvHls){try{pvHls.destroy();}catch(e){}pvHls=null;}' +
    'try{' +
    (token
      ? 'pvHls=new Hls({startLevel:0,capLevelToPlayerSize:true,maxBufferLength:3,maxMaxBufferLength:6,backBufferLength:0,xhrSetup:function(x){try{x.setRequestHeader("Authorization","Bearer "+' + JSON.stringify(String(token)) + ');}catch(e){}}});'
      : 'pvHls=new Hls({startLevel:0,capLevelToPlayerSize:true,maxBufferLength:3,maxMaxBufferLength:6,backBufferLength:0});') +
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
    'if(scrubPrev){scrubPrev.hidden=true;if(scrubPrev.classList)scrubPrev.classList.remove("loading");}}' +
    'function showPreviewAt(pct){if(!scrubPrev||pct===null||!Number.isFinite(v.duration)||v.duration<=0)return;' +
    'pct=Math.max(0,Math.min(1,pct));var t=pct*v.duration;' +
    'if(pvTime)pvTime.textContent=fmt(t);' +
    'if(pvTag){if(opRange&&t>=opRange[0]&&t<opRange[1]){pvTag.textContent="Intro";pvTag.hidden=false;}' +
    'else if(edRange&&t>=edRange[0]&&t<edRange[1]){pvTag.textContent="Ending";pvTag.hidden=false;}' +
    'else{pvTag.hidden=true;}}' +
    'scrubPrev.hidden=false;' +
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
    'if(timeLbl&&Number.isFinite(v.duration))timeLbl.textContent=fmt(v.duration-pct*v.duration);' +
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
    'scrub.setAttribute("aria-label","Seek");' +
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
    'if(k==="ArrowRight"){seekBy(10);}' +
    'else if(k==="ArrowLeft"){seekBy(-10);}' +
    'else if(k==="Home"){seekTo(0);}' +
    'else if(k==="End"){seekTo(v.duration);}' +
    'else{return;}' +
    'if(e.stopPropagation)e.stopPropagation();' +
    'if(e.preventDefault)e.preventDefault();});}' +
    'var finePointer=false;' +
    'try{finePointer=!!(window.matchMedia&&' +
    'window.matchMedia("(hover:hover) and (pointer:fine)").matches);}catch(e){}' +
    'var lastTap={t:0,x:0},tapTimer=null;' +
    'function toggleHud(){if(!document.body||!document.body.classList)return;' +
    'if(document.body.classList.contains("idle")){wakeHud();return;}' +
    'document.body.classList.add("idle");hidePreview();closeMenus();' +
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
    'v.addEventListener("dblclick",function(e){if(!finePointer)return;' +
    'if(e&&e.preventDefault)e.preventDefault();toggleFs();});' +
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
