import type { KatanaChapter } from './katanaService';
import type { MangaReaderParams } from './MangaReaderPage';

function makeDemoSvgPage(chapterNum: number, pageNum: number, totalPages: number, wide = false): string {
  const w = wide ? 1400 : 800;
  const h = wide ? 960 : 1200;
  const palette = [
    ['#1A1024', '#FF2E7E', '#3A1F47'],
    ['#121829', '#7B61FF', '#223152'],
    ['#1D1420', '#FF85B3', '#3D2239'],
    ['#131A24', '#5BC0EB', '#21354A'],
  ][(chapterNum + pageNum) % 4];

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <rect width="${w}" height="${h}" fill="#0B0810"/>
  <rect x="28" y="28" width="${w - 56}" height="${Math.round(h * 0.44)}" rx="12" fill="${palette[0]}" stroke="${palette[1]}" stroke-width="4"/>
  <circle cx="${Math.round(w * 0.72)}" cy="${Math.round(h * 0.22)}" r="${Math.round(h * 0.12)}" fill="${palette[1]}" opacity="0.22"/>
  <rect x="28" y="${Math.round(h * 0.49)}" width="${Math.round((w - 72) * 0.48)}" height="${Math.round(h * 0.46)}" rx="12" fill="${palette[2]}" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="3"/>
  <rect x="${Math.round(44 + (w - 72) * 0.48)}" y="${Math.round(h * 0.49)}" width="${Math.round((w - 72) * 0.52)}" height="${Math.round(h * 0.46)}" rx="12" fill="${palette[0]}" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="3"/>
  <ellipse cx="${Math.round(w * 0.28)}" cy="${Math.round(h * 0.18)}" rx="150" ry="68" fill="#FFF8FA"/>
  <text x="${Math.round(w * 0.28)}" y="${Math.round(h * 0.175)}" text-anchor="middle" font-family="sans-serif" font-size="24" font-weight="700" fill="#170E1D">Chapter ${chapterNum}</text>
  <text x="${Math.round(w * 0.28)}" y="${Math.round(h * 0.205)}" text-anchor="middle" font-family="sans-serif" font-size="18" font-weight="600" fill="#C9185B">${wide ? 'Double-Page Spread' : `Demo Panel ${pageNum} of ${totalPages}`}</text>
  <text x="${Math.round(w * 0.5)}" y="${h - 46}" text-anchor="middle" font-family="sans-serif" font-size="22" font-weight="600" fill="#D9B8C7" opacity="0.85">STARLIGHT CHRONICLES — CH.${chapterNum} • P.${pageNum}</text>
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
  };
}
