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
function hlsPlayerHtml({ src, title, tracks, token, ep, audio }) {
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
    '#sub-box{position:fixed;left:50%;transform:translateX(-50%);bottom:88px;width:88%;' +
    'text-align:center;z-index:4;pointer-events:none;transition:bottom .24s cubic-bezier(.22,1,.36,1)}' +
    'body.idle #sub-box{bottom:30px}' +
    '#sub-txt{display:inline;background:transparent;color:#fff;font-size:clamp(15px,2.4vw,22px);' +
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
    'z-index:5;transition:opacity .26s cubic-bezier(.22,1,.36,1)}' +
    'body.idle #hud{opacity:0;pointer-events:none}' +
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
    '.binge-r{position:relative;display:flex;justify-content:flex-end;align-items:center;' +
    'min-height:34px}' +
    // A soft scrim keeps the words readable over a bright frame. It is a
    // legibility wash, not a card: no edge, no border, no fill of its own.
    '.b-scrim{position:absolute;right:-20px;bottom:-14px;width:340px;height:120px;' +
    'pointer-events:none;background:radial-gradient(ellipse at 78% 62%,' +
    'rgba(8,5,14,.82) 0%,rgba(8,5,14,.5) 45%,transparent 72%)}' +
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
    'cursor:pointer;overflow:hidden}' +
    '#s-buf{position:absolute;left:0;top:0;bottom:0;width:0%;background:rgba(240,230,255,.32)}' +
    '#s-fill{position:absolute;left:0;top:0;bottom:0;width:0%;background:#c2185b;z-index:2}' +
    '.s-chap{position:absolute;top:0;bottom:0;background:rgba(245,201,123,.55);' +
    'border-left:1px solid #f5c97b;border-right:1px solid #f5c97b;z-index:3;pointer-events:none}' +
    '.ctrl-r{display:flex;align-items:center;justify-content:space-between;gap:10px;font-size:12px;color:#f1cbd2}' +
    '.ctrl-l,.ctrl-rt{display:flex;align-items:center;gap:12px}' +
    '.ib{border:0;background:transparent;color:#fff5f5;display:inline-flex;align-items:center;' +
    'justify-content:center;cursor:pointer;padding:2px;opacity:.92}' +
    '.ib:hover{opacity:1;color:#c2185b}' +
    '.ib.rose{color:#c2185b}' +
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
    '#q-menu{position:fixed;right:20px;bottom:58px;width:164px;background:rgba(18,13,26,.95);' +
    'backdrop-filter:blur(18px);border:1px solid rgba(240,230,255,.18);border-radius:10px;' +
    'padding:6px;z-index:12;box-shadow:0 14px 32px rgba(0,0,0,.65)}' +
    '.qi{display:flex;justify-content:space-between;align-items:center;width:100%;border:0;' +
    'background:transparent;color:#f1cbd2;padding:6px 8px;border-radius:6px;font-size:11.5px;' +
    'font-weight:600;cursor:pointer;font-family:inherit;text-align:left}' +
    '.qi.on{background:rgba(194,24,91,.28);color:#fff5f5}' +
    // Phones keep the Everglow badge (Clair watches here); the volume
    // button and wide gaps give up their room instead.
    '@media (max-width:520px){.h-top{padding:10px 14px}.h-bot{padding:0 14px 10px}' +
    '.ctrl-l,.ctrl-rt{gap:8px}#btn-vol{display:none}' +
    '.eg-badge{padding:2px 7px 2px 3px;gap:5px}.eg-cat{width:17px;height:17px}' +
    '.eg-w{font-size:14px}.chip{padding:3px 7px;font-size:10.5px}' +
    '#time-lbl{font-size:11px}#hud-title{font-size:13px}}' +
    '</style></head><body>' +
    '<video id="v" playsinline autoplay preload="auto" crossorigin="anonymous">' +
    (trackTags ? '\n    ' + trackTags : '') +
    '</video>\n' +
    '<div id="sub-box"><span id="sub-txt"></span></div>\n' +
    '<div id="hud">' +
    '<div class="h-top">' +
    '<span id="hud-title">' + displayTitle + '</span>' +
    '<div class="h-top-r">' +
    '<div class="sd-box">' +
    '<button type="button" class="sd-b' + (isDub ? '' : ' on') + '" id="btn-sub">SUB</button>' +
    '<button type="button" class="sd-b' + (isDub ? ' on' : '') + '" id="btn-dub">DUB</button>' +
    '</div>' +
    '<button type="button" class="chip" id="btn-eps">Episodes</button>' +
    '</div></div>' +
    '<div class="h-bot">' +
    '<div class="binge-r">' +
    '<div class="b-scrim"></div>' +
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
    '</div>' +
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
    '<button type="button" class="ib" id="btn-vol" aria-label="Mute or unmute">' +
    '<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><polygon points="9 4 5 7.5 2 7.5 2 12.5 5 12.5 9 16 9 4" fill="currentColor"/><path id="vol-w" d="M12.5 7a4 4 0 0 1 0 6M15 4.8a7.2 7.2 0 0 1 0 10.4"/></svg></button>' +
    '<span id="time-lbl">00:00 / 00:00</span>' +
    '</div>' +
    '<div class="ctrl-rt">' +
    '<div class="eg-badge">' +
    '<img class="eg-cat" src="https://everglow-1c6db.web.app/favicon.png" alt="">' +
    '<span class="eg-w"><b>EVER</b><i>GLOW</i></span>' +
    '</div>' +
    '<button type="button" class="chip on" id="btn-cc">CC</button>' +
    '<button type="button" class="chip" id="btn-q">Auto</button>' +
    '<button type="button" class="ib" id="btn-fs" aria-label="Fullscreen">' +
    '<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7V3h4M17 7V3h-4M3 13v4h4M17 13v4h-4"/></svg></button>' +
    '</div></div></div></div>\n' +
    '<div id="q-menu" hidden></div>\n' +
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
    'var btnQ=document.getElementById("btn-q");' +
    'var qMenu=document.getElementById("q-menu");' +
    'var btnFs=document.getElementById("btn-fs");' +
    'var btnSkip=document.getElementById("btn-skip");' +
    'var btnNext=document.getElementById("btn-next");' +
    'var btnSub=document.getElementById("btn-sub");' +
    'var btnDub=document.getElementById("btn-dub");' +
    'var btnEps=document.getElementById("btn-eps");' +
    'var subTxt=document.getElementById("sub-txt");' +
    'var skipTime=document.getElementById("skip-time");' +
    'var skipFill=document.getElementById("skip-fill");' +
    'var nextLbl=document.getElementById("next-lbl");' +
    'var nextTok=document.getElementById("next-tok");' +
    'var nextFill=document.getElementById("next-fill");' +
    'var episode=' + JSON.stringify(epNum) + ';' +
    'var opRange=null,edRange=null,activeSkipEnd=null,ccOn=true,hlsInst=null;' +
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
    'function updateSkipBtn(){if(!btnSkip)return;var t=v.currentTime;' +
    'if(opRange&&t>=opRange[0]&&t<opRange[1]){activeSkipEnd=opRange[1];' +
    'if(skipTime)skipTime.textContent=fmt(Math.max(0,opRange[1]-t));' +
    'var p=through(opRange,t);if(skipFill&&p!==null)skipFill.style.width=((1-p)*100)+"%";' +
    'btnSkip.hidden=false;return;}' +
    'activeSkipEnd=null;btnSkip.hidden=true;}' +
    // Next shows during the ending, or within the last 90s when nobody
    // marked one. No token means nothing follows, so it stays hidden.
    'function updateNextBtn(){if(!btnNext)return;' +
    'if(!nextToken&&nextKind!=="season"){btnNext.hidden=true;return;}' +
    'var t=v.currentTime,d=v.duration;' +
    'if(!Number.isFinite(t)||!Number.isFinite(d)||d<=0){btnNext.hidden=true;return;}' +
    'var inEnding=!!edRange&&t>=edRange[0]&&t<edRange[1];' +
    'var nearEnd=(d-t)<=NEAR_END_SECONDS;' +
    'if(!(inEnding||nearEnd)){btnNext.hidden=true;return;}' +
    'if(nextLbl)nextLbl.textContent=nextKind==="season"?"Next season":"Next episode";' +
    'if(nextTok)nextTok.textContent=nextToken||"";' +
    'var p=inEnding?through(edRange,t):null;' +
    'if(p===null)p=1-Math.min(1,Math.max(0,(d-t)/NEAR_END_SECONDS));' +
    'if(nextFill)nextFill.style.width=((1-p)*100)+"%";' +
    'btnNext.hidden=false;}' +
    'function updateUi(){var p=v.currentTime,d=v.duration;' +
    'if(Number.isFinite(p)&&Number.isFinite(d)&&d>0){' +
    'if(sFill)sFill.style.width=Math.min(100,Math.max(0,p/d*100))+"%";' +
    'if(timeLbl)timeLbl.textContent=fmt(p)+" / "+fmt(d);}' +
    'updateSkipBtn();updateNextBtn();}' +
    'function applySeek(){if(!hasMetadata||pendingSeek===null||!Number.isFinite(v.duration)||v.duration<=0){return;}' +
    'try{v.currentTime=Math.min(pendingSeek,v.duration);pendingSeek=null;updateUi();}catch(e){}}' +
    'v.addEventListener("loadedmetadata",function(){hasMetadata=true;applySeek();updateChapters();updateUi();});' +
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
    'v.addEventListener("pause",function(){if(playP)playP.setAttribute("d","M5 3.5l12 6.5-12 6.5V3.5z");progress(true);});' +
    'v.addEventListener("ended",function(){progress(true);});' +
    'function hideBoot(){boot.style.display="none";}' +
    'function showTap(){tapw.hidden=false;}' +
    'function tryPlay(){var p;try{p=v.play();}catch(e){showTap();return;}' +
    'if(p&&p.catch){p.catch(function(){showTap();});}}' +
    'function giveUp(){hideBoot();tapw.hidden=true;dead.hidden=false;' +
    'post("animex-content-error");}' +
    'tap.addEventListener("click",function(){tapw.hidden=true;tryPlay();});' +
    'v.addEventListener("playing",function(){hideBoot();tapw.hidden=true;' +
    'if(playP)playP.setAttribute("d","M4 3h3.5v14H4zM12.5 3H16v14h-3.5z");});' +
    'v.addEventListener("waiting",function(){' +
    'if(dead.hidden){boot.style.display="flex";}});' +
    'if(btnPlay)btnPlay.addEventListener("click",function(){if(v.paused)tryPlay();else v.pause();});' +
    'if(btnRew)btnRew.addEventListener("click",function(){if(Number.isFinite(v.currentTime))v.currentTime=Math.max(0,v.currentTime-10);updateUi();});' +
    'if(btnFf)btnFf.addEventListener("click",function(){if(Number.isFinite(v.currentTime)&&Number.isFinite(v.duration))v.currentTime=Math.min(v.duration,v.currentTime+10);updateUi();});' +
    'if(btnVol)btnVol.addEventListener("click",function(){v.muted=!v.muted;btnVol.style.opacity=v.muted?"0.45":"0.92";});' +
    'if(scrub)scrub.addEventListener("click",function(e){if(!Number.isFinite(v.duration)||v.duration<=0||!scrub.getBoundingClientRect)return;' +
    'var r=scrub.getBoundingClientRect();if(r.width<=0)return;' +
    'var pct=Math.max(0,Math.min(1,(e.clientX-r.left)/r.width));v.currentTime=pct*v.duration;updateUi();});' +
    'if(btnSkip)btnSkip.addEventListener("click",function(){if(activeSkipEnd!==null&&Number.isFinite(v.duration)){v.currentTime=Math.min(v.duration,activeSkipEnd);updateUi();}});' +
    'if(btnNext)btnNext.addEventListener("click",function(){post({type:"animex-action",action:"next-episode"});});' +
    'if(btnSub)btnSub.addEventListener("click",function(){post({type:"animex-action",action:"audio",audio:"sub"});});' +
    'if(btnDub)btnDub.addEventListener("click",function(){post({type:"animex-action",action:"audio",audio:"dub"});});' +
    'if(btnEps)btnEps.addEventListener("click",function(){post({type:"animex-action",action:"episodes"});});' +
    'if(btnCc)btnCc.addEventListener("click",function(){ccOn=!ccOn;btnCc.classList.toggle("on",ccOn);if(subTxt&&!ccOn)subTxt.textContent="";});' +
    'if(btnFs)btnFs.addEventListener("click",function(){var doc=document;var root=doc.documentElement||v;' +
    'if(doc.fullscreenElement){if(doc.exitFullscreen)doc.exitFullscreen();}' +
    'else if(root.requestFullscreen){root.requestFullscreen();}' +
    'else if(v.webkitEnterFullscreen){v.webkitEnterFullscreen();}});' +
    'if(btnQ&&qMenu)btnQ.addEventListener("click",function(){qMenu.hidden=!qMenu.hidden;});' +
    'function syncCues(){if(!subTxt||!v.textTracks)return;for(var i=0;i<v.textTracks.length;i++){' +
    'var tr=v.textTracks[i];tr.mode="hidden";tr.oncuechange=function(){' +
    'if(!ccOn){subTxt.textContent="";return;}var lines=[];' +
    'var ac=this.activeCues;if(ac){for(var j=0;j<ac.length;j++){if(ac[j]&&ac[j].text)lines.push(ac[j].text.replace(/<[^>]+>/g,""));}}' +
    'subTxt.textContent=lines.join("\\n");};}}' +
    'v.addEventListener("loadedmetadata",syncCues);' +
    'var idleT=null;function wakeHud(){if(document.body&&document.body.classList){document.body.classList.remove("idle");}' +
    'if(typeof clearTimeout==="function"&&idleT)clearTimeout(idleT);' +
    'if(typeof setTimeout==="function"){idleT=setTimeout(function(){if(!v.paused&&document.body&&document.body.classList){document.body.classList.add("idle");if(qMenu)qMenu.hidden=true;}},2800);}}' +
    'window.addEventListener("mousemove",wakeHud);window.addEventListener("touchstart",wakeHud);' +
    'if(window.Hls&&Hls.isSupported()){' +
    (token
      ? 'var h=new Hls({maxBufferLength:30,xhrSetup:function(x){try{x.setRequestHeader("Authorization","Bearer "+' + JSON.stringify(String(token)) + ');}catch(e){}}});var fatal=0;'
      : 'var h=new Hls({maxBufferLength:30});var fatal=0;') +
    'hlsInst=h;' +
    'h.on(Hls.Events.ERROR,function(ev,data){' +
    'if(!data||!data.fatal){return;}fatal++;' +
    'if(fatal>3){try{h.destroy();}catch(e){}giveUp();return;}' +
    'var ET=Hls.ErrorTypes||{};' +
    'try{' +
    'if(data.type===ET.NETWORK_ERROR){h.startLoad();}' +
    'else if(data.type===ET.MEDIA_ERROR){h.recoverMediaError();}' +
    'else if(fatal<3){h.startLoad();}' +
    'else{h.destroy();giveUp();}' +
    '}catch(e){giveUp();}});' +
    'h.on(Hls.Events.MANIFEST_PARSED,function(){' +
    'if(qMenu&&btnQ&&Array.isArray(h.levels)&&h.levels.length>0){' +
    'qMenu.innerHTML="";var mk=function(lbl,lvl){var b=document.createElement("button");' +
    'b.className="qi"+(h.currentLevel===lvl?" on":"");b.textContent=lbl;' +
    'b.onclick=function(){h.currentLevel=lvl;btnQ.textContent=lvl===-1?"Auto":lbl;qMenu.hidden=true;};qMenu.appendChild(b);};' +
    'mk("Auto",-1);h.levels.forEach(function(lv,idx){if(lv&&lv.height)mk(lv.height+"p",idx);});}' +
    'tryPlay();});' +
    'h.loadSource(src);h.attachMedia(v);' +
    '}else{' +
    'v.src=src;' +
    'v.addEventListener("loadedmetadata",function(){tryPlay();});' +
    'v.addEventListener("error",function(){giveUp();});' +
    '}})();</' + 'script></body></html>'
  );
}

module.exports = { escHtml, hlsPlayerHtml };
