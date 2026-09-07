import { db, storage, session, esc, errMsg, monthDay, galleryDisplayUrl, fmtTime } from './lib.js';
import { displayName, requireCouple } from './auth.js';
import { Shell } from './home.js';

export async function Gallery(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'gallery', `
    <div class="topbar"><div class="grow"><h2 class="serif">Gallery</h2><p class="sub">our shared album</p></div>
      <label class="btn" style="min-height:44px">+ Add<input id="file" type="file" accept="image/*" hidden></label></div>
    <div id="msg"></div>
    <div class="photos" id="grid" style="margin-top:12px"><div class="skel"></div><div class="skel"></div><div class="skel"></div></div>
    <div class="center" style="margin-top:12px"><button class="ghost" id="more" type="button" hidden>Show more</button></div>`);

  const grid = el.querySelector('#grid');
  const msg = el.querySelector('#msg');
  const more = el.querySelector('#more');
  let last = null;
  let done = false;

  function card(p) {
    return `<figure data-id="${esc(p.id)}">
      <div class="ph"><span>…</span><img loading="lazy" width="300" height="300" src="${esc(galleryDisplayUrl(p.imageUrl))}" alt="${esc(p.caption || 'our photo')}"
        onload="this.previousElementSibling.remove()" onerror="this.parentNode.innerHTML='🤍'"></div>
      <figcaption>${esc(p.caption || fmtTime(p.uploadedAt))}</figcaption></figure>`;
  }

  async function page() {
    try {
      const { db: d, f } = await db();
      let q = f.query(f.collection(d, 'gallery'), f.orderBy('uploadedAt', 'desc'), f.limit(24));
      if (last) q = f.query(f.collection(d, 'gallery'), f.orderBy('uploadedAt', 'desc'), f.startAfter(last), f.limit(24));
      const s = await f.getDocs(q);
      if (s.empty && !last) {
        grid.innerHTML = `<div class="card center" style="grid-column:1/-1"><p class="serif" style="font-size:22px;margin:0">No memories yet</p><p class="muted small">Add your first photo with + Add.</p></div>`;
        return;
      }
      if (!last) grid.innerHTML = '';
      grid.insertAdjacentHTML('beforeend', s.docs.map((x) => card({ id: x.id, ...x.data() })).join(''));
      last = s.docs[s.docs.length - 1] || null;
      done = s.docs.length < 24;
      more.hidden = done;
    } catch (e) {
      grid.innerHTML = `<div class="card" style="grid-column:1/-1"><p>${esc(errMsg(e))}</p><button class="ghost" type="button" id="retry">Try again</button></div>`;
      grid.querySelector('#retry').addEventListener('click', () => { last = null; page(); });
    }
  }
  await page();
  more.addEventListener('click', page);

  grid.addEventListener('click', (ev) => {
    const fig = ev.target.closest('figure');
    if (!fig) return;
    const img = fig.querySelector('img');
    if (!img || img.currentSrc === '') return;
    const cap = fig.querySelector('figcaption').textContent;
    const v = document.createElement('div');
    v.className = 'viewer';
    v.innerHTML = `<div class="row"><span class="grow"></span><button type="button" id="x">Close ✕</button></div>
      <img src="${esc(img.src)}" alt="${esc(cap)}"><p class="cap center">${esc(cap)}</p>`;
    document.body.appendChild(v);
    v.querySelector('#x').addEventListener('click', () => v.remove());
    v.addEventListener('click', (e) => { if (e.target === v) v.remove(); });
  });

  el.querySelector('#file').addEventListener('change', async (ev) => {
    const file = ev.target.files && ev.target.files[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) { msg.innerHTML = `<p class="err small">Please pick a photo.</p>`; return; }
    if (file.size > 8 * 1024 * 1024) { msg.innerHTML = `<p class="err small">That photo is over 8MB — pick a smaller one.</p>`; return; }
    const caption = prompt('A few words for this memory? (optional)') || '';
    msg.innerHTML = `<p class="muted small">Uploading with love…</p>`;
    try {
      const s = await storage();
      const path = `gallery/${u.uid}/${Date.now()}_${file.name.replace(/[^\w.\-]+/g, '_')}`;
      const ref = s.ref(s.st, path);
      await s.uploadBytes(ref, file, { contentType: file.type || 'image/jpeg', cacheControl: 'public, max-age=31536000' });
      const url = await s.getDownloadURL(ref);
      const { db: d, f } = await db();
      await f.addDoc(f.collection(d, 'gallery'), {
        imageUrl: url,
        caption: caption.slice(0, 280),
        uploadedBy: displayName(session.username),
        uploadedAt: f.serverTimestamp(),
        tags: [],
        monthDay: monthDay(),
      });
      msg.innerHTML = `<p class="ok small">Saved. 💖</p>`;
      last = null;
      await page();
    } catch (e) {
      msg.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`;
    }
    ev.target.value = '';
  });
}
