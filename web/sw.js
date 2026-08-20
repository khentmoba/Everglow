// BUILD=6.0.0+1-26b8d56
const CACHE='everglow-6.0.0+1-26b8d56';
const ASSETS=['flutter_bootstrap.js','main.dart.js'];
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS).catch(()=>{})));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;const u=new URL(e.request.url);const p=u.pathname;if(p==='/version.json'||p==='/sw.js'||p==='/index.html'){e.respondWith(fetch(e.request,{cache:'no-store'}));return;}let hit=false;for(const a of ASSETS) if(p.endsWith(a)) hit=true;if(hit){e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(res=>{caches.open(CACHE).then(c=>c.put(e.request,res.clone()));return res;})));return;}});
