import type { KatanaChapter } from './katanaService';
import type { MangaReaderParams } from './MangaReaderPage';

function makeDemoSvgPage(chapterNum: number, pageNum: number, totalPages: number, wide = false): string {
  const w = wide ? 1400 : 800;
  const h = wide ? 960 : 1200;
  const palettes = [
    { ink: '#0F172A', paper: '#F7F4EC', accent: '#F59E0B', mid: '#1E293B', sky: '#172554', glow: '#FDE68A' },
    { ink: '#090D16', paper: '#F5F5F0', accent: '#38BDF8', mid: '#1E293B', sky: '#0F172A', glow: '#BAE6FD' },
    { ink: '#111827', paper: '#F8F5EE', accent: '#2DD4BF', mid: '#1F2937', sky: '#111C24', glow: '#99F6E4' },
    { ink: '#14121D', paper: '#FAF6F0', accent: '#FB923C', mid: '#27233A', sky: '#1E1B2E', glow: '#FED7AA' },
  ];
  const pal = palettes[(chapterNum + pageNum) % palettes.length];
  const dialogues = [
    ['"The observatory seal held for three hundred winters…"', '"Until the seventh star fell across the eastern ridge."', 'KLANG — ゴゴゴ'],
    ['"Stay behind the lantern line, Clair!"', '"Look at the horizon—the whole sky is opening up."', 'SHING — 閃'],
    ['"If we cross the astral causeway tonight…"', '"There is no turning back to the lower capital."', 'ZAWA… ざわ'],
    ['"Hold the formation! Both wings together!"', '"Now—strike through the rift before it closes!"', 'DOOM — ドォン!!'],
    ['"Did the beacon reach the northern tower?"', '"Every bell in Celestia is answering at once."', 'RING — 凛'],
    ['"We made it past the storm wall."', '"Dawn is breaking over the sea of clouds."', 'HUSH… 静'],
  ];
  const lines = dialogues[(pageNum - 1) % dialogues.length];
  const midX = Math.round(w * 0.52);
  const topH = Math.round(h * 0.34);
  const midY = topH + 52;
  const midH = Math.round(h * 0.31);
  const botY = midY + midH + 18;
  const botH = h - botY - 56;

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <defs>
    <pattern id="tone-${pageNum}" width="8" height="8" patternUnits="userSpaceOnUse">
      <circle cx="3" cy="3" r="1.35" fill="${pal.ink}" opacity="0.18"/>
    </pattern>
    <pattern id="dense-${pageNum}" width="6" height="6" patternUnits="userSpaceOnUse">
      <circle cx="2.5" cy="2.5" r="1.6" fill="${pal.ink}" opacity="0.28"/>
    </pattern>
    <linearGradient id="sky-${pageNum}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${pal.sky}"/>
      <stop offset="100%" stop-color="${pal.mid}"/>
    </linearGradient>
  </defs>

  <!-- Outer manga page paper & trim margin for realistic fit/crop/gutter QA -->
  <rect width="${w}" height="${h}" fill="${pal.paper}"/>
  <rect x="18" y="18" width="${w - 36}" height="${h - 36}" fill="none" stroke="${pal.ink}" stroke-opacity="0.18" stroke-width="1.5"/>

  <!-- Panel 1: Wide establishing shot with starfield, mountain ridge, speed lines & narration box -->
  <g>
    <rect x="36" y="34" width="${w - 72}" height="${topH}" fill="url(#sky-${pageNum})" stroke="${pal.ink}" stroke-width="4.5"/>
    <circle cx="${Math.round(w * 0.76)}" cy="${Math.round(topH * 0.42)}" r="${Math.round(topH * 0.24)}" fill="${pal.glow}" opacity="0.22"/>
    <circle cx="${Math.round(w * 0.76)}" cy="${Math.round(topH * 0.42)}" r="${Math.round(topH * 0.14)}" fill="${pal.accent}" opacity="0.82"/>
    <line x1="40" y1="42" x2="${Math.round(w * 0.62)}" y2="${Math.round(topH * 0.36)}" stroke="#FFFFFF" stroke-opacity="0.16" stroke-width="2"/>
    <line x1="40" y1="88" x2="${Math.round(w * 0.58)}" y2="${Math.round(topH * 0.44)}" stroke="#FFFFFF" stroke-opacity="0.14" stroke-width="1.5"/>
    <line x1="${w - 42}" y1="54" x2="${Math.round(w * 0.82)}" y2="${Math.round(topH * 0.38)}" stroke="#FFFFFF" stroke-opacity="0.18" stroke-width="2"/>
    <polygon points="36,${34 + topH} ${Math.round(w * 0.26)},${34 + Math.round(topH * 0.56)} ${Math.round(w * 0.48)},${34 + Math.round(topH * 0.78)} ${Math.round(w * 0.71)},${34 + Math.round(topH * 0.48)} ${w - 36},${34 + topH}" fill="${pal.ink}" opacity="0.88"/>
    <!-- Narration caption box -->
    <rect x="54" y="52" width="320" height="76" fill="${pal.paper}" stroke="${pal.ink}" stroke-width="3"/>
    <text x="70" y="82" font-family="Georgia, serif" font-size="20" font-weight="700" fill="${pal.ink}">Chapter ${chapterNum} · ${wide ? 'Double-Page Spread' : `Demo Panel ${pageNum} of ${totalPages}`}</text>
    <text x="70" y="109" font-family="sans-serif" font-size="14.5" font-weight="600" fill="#334155">${lines[0]}</text>
    <!-- Tailed speech bubble in Panel 1 -->
    <ellipse cx="${Math.round(w * 0.68)}" cy="${34 + Math.round(topH * 0.68)}" rx="185" ry="52" fill="#FFFFFF" stroke="${pal.ink}" stroke-width="3.2"/>
    <polygon points="${Math.round(w * 0.62)},${34 + Math.round(topH * 0.68) + 48} ${Math.round(w * 0.66)},${34 + Math.round(topH * 0.68) + 48} ${Math.round(w * 0.58)},${34 + Math.round(topH * 0.88)}" fill="#FFFFFF" stroke="${pal.ink}" stroke-width="3"/>
    <text x="${Math.round(w * 0.68)}" y="${34 + Math.round(topH * 0.68) - 4}" text-anchor="middle" font-family="sans-serif" font-size="15.5" font-weight="700" fill="${pal.ink}">${lines[1]}</text>
    <text x="${Math.round(w * 0.68)}" y="${34 + Math.round(topH * 0.68) + 20}" text-anchor="middle" font-family="sans-serif" font-size="13" font-weight="600" fill="#B45309">CELESTIA ARCHIVE EDITION</text>
  </g>

  <!-- Panel 2 (Middle-Left): Screentone close-up character portrait with action focus lines -->
  <g>
    <rect x="36" y="${midY}" width="${midX - 46}" height="${midH}" fill="#FFFFFF" stroke="${pal.ink}" stroke-width="4.5"/>
    <rect x="36" y="${midY}" width="${midX - 46}" height="${midH}" fill="url(#tone-${pageNum})"/>
    <!-- Character silhouette (hooded cloak + shoulders + katana hilt) -->
    <circle cx="${Math.round((36 + midX - 46) * 0.52)}" cy="${midY + Math.round(midH * 0.42)}" r="${Math.round(midH * 0.21)}" fill="${pal.mid}" stroke="${pal.ink}" stroke-width="3.5"/>
    <path d="M ${Math.round((36 + midX - 46) * 0.24)} ${midY + midH} Q ${Math.round((36 + midX - 46) * 0.52)} ${midY + Math.round(midH * 0.56)} ${Math.round((36 + midX - 46) * 0.84)} ${midY + midH} Z" fill="${pal.ink}"/>
    <line x1="${Math.round((36 + midX - 46) * 0.72)}" y1="${midY + Math.round(midH * 0.22)}" x2="${Math.round((36 + midX - 46) * 0.34)}" y2="${midY + Math.round(midH * 0.92)}" stroke="${pal.accent}" stroke-width="5"/>
    <!-- Vertical speech balloon -->
    <rect x="52" y="${midY + 18}" width="156" height="${Math.round(midH * 0.54)}" rx="26" fill="#FFFFFF" stroke="${pal.ink}" stroke-width="3"/>
    <text x="130" y="${midY + 58}" text-anchor="middle" font-family="sans-serif" font-size="14.5" font-weight="700" fill="${pal.ink}">"Watch the</text>
    <text x="130" y="${midY + 80}" text-anchor="middle" font-family="sans-serif" font-size="14.5" font-weight="700" fill="${pal.ink}">astral compass—</text>
    <text x="130" y="${midY + 102}" text-anchor="middle" font-family="sans-serif" font-size="14.5" font-weight="700" fill="${pal.ink}">it's moving!"</text>
  </g>

  <!-- Panel 3 (Middle-Right): Dynamic diagonal action panel with SFX lettering -->
  <g>
    <rect x="${midX + 6}" y="${midY}" width="${w - midX - 42}" height="${midH}" fill="${pal.mid}" stroke="${pal.ink}" stroke-width="4.5"/>
    <rect x="${midX + 6}" y="${midY}" width="${w - midX - 42}" height="${midH}" fill="url(#dense-${pageNum})"/>
    <line x1="${midX + 12}" y1="${midY + midH - 12}" x2="${w - 48}" y2="${midY + 16}" stroke="${pal.accent}" stroke-width="6"/>
    <line x1="${midX + 24}" y1="${midY + midH - 42}" x2="${w - 64}" y2="${midY + 44}" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="2.5"/>
    <text x="${Math.round((midX + w - 36) * 0.5)}" y="${midY + Math.round(midH * 0.52)}" text-anchor="middle" font-family="Impact, sans-serif" font-size="30" font-weight="900" fill="${pal.glow}" stroke="${pal.ink}" stroke-width="1.5">${lines[2]}</text>
  </g>

  <!-- Panel 4 (Bottom): Wide dramatic horizon strip with dialogue balloon & Architecture landmarks -->
  <g>
    <rect x="36" y="${botY}" width="${w - 72}" height="${botH}" fill="#FFFFFF" stroke="${pal.ink}" stroke-width="4.5"/>
    <rect x="36" y="${botY}" width="${w - 72}" height="${Math.round(botH * 0.45)}" fill="url(#tone-${pageNum})"/>
    <!-- Spire silhouettes -->
    <rect x="${Math.round(w * 0.14)}" y="${botY + Math.round(botH * 0.28)}" width="38" height="${Math.round(botH * 0.72)}" fill="${pal.ink}"/>
    <rect x="${Math.round(w * 0.21)}" y="${botY + Math.round(botH * 0.42)}" width="54" height="${Math.round(botH * 0.58)}" fill="${pal.mid}"/>
    <rect x="${Math.round(w * 0.78)}" y="${botY + Math.round(botH * 0.24)}" width="44" height="${Math.round(botH * 0.76)}" fill="${pal.ink}"/>
    <!-- Dialogue balloon -->
    <ellipse cx="${Math.round(w * 0.54)}" cy="${botY + Math.round(botH * 0.52)}" rx="235" ry="54" fill="#FFFFFF" stroke="${pal.ink}" stroke-width="3.2"/>
    <text x="${Math.round(w * 0.54)}" y="${botY + Math.round(botH * 0.52) - 4}" text-anchor="middle" font-family="sans-serif" font-size="16" font-weight="700" fill="${pal.ink}">${lines[0]}</text>
    <text x="${Math.round(w * 0.54)}" y="${botY + Math.round(botH * 0.52) + 20}" text-anchor="middle" font-family="sans-serif" font-size="14.5" font-weight="600" fill="#475569">${lines[1]}</text>
  </g>

  <!-- Folio footer in page margin -->
  <text x="${Math.round(w * 0.5)}" y="${h - 24}" text-anchor="middle" font-family="sans-serif" font-size="15" font-weight="700" fill="${pal.ink}" opacity="0.78">STARLIGHT CHRONICLES — CH.${chapterNum} • P.${pageNum}</text>
</svg>`;
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}

export const DEMO_MANGA_CHAPTERS: KatanaChapter[] = [
  { id: 'c43', num: '43', title: 'Chapter 43: Beyond the Horizon' },
  { id: 'c42', num: '42', title: 'Chapter 42: Starlight Vow' },
  { id: 'c41', num: '41', title: 'Chapter 41: Paper Lanterns' },
  { id: 'c40', num: '40', title: 'Chapter 40: Quiet Rain' },
];

export function getDemoChapterPages(chapterId: string): string[] {
  const num = Number(chapterId.replace(/\D+/g, '')) || 42;
  const total = 6;
  return Array.from({ length: total }, (_, idx) => makeDemoSvgPage(num, idx + 1, total, idx === 3));
}

export function createDemoMangaReaderParams(): MangaReaderParams {
  return {
    slug: 'demo-starlight-manga',
    chapterId: 'c42',
    mangaTitle: 'Fictional Starlight Manga',
    coverUrl: '',
    chapters: DEMO_MANGA_CHAPTERS,
    initialPage: 2,
    mangaStatus: 'ongoing',
    finalChapterId: 'c43',
    readChapterIds: ['c40', 'c41'],
    seriesFormat: 'webtoon',
  };
}
