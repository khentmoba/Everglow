import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { radial } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { ourBookToBookItem, searchResultToBookItem, type BookSearchResult } from './bookTypes';
import { addToOurBooks, removeFromOurBooks, searchBooksCatalog, setOurBookReadFlag, watchOurBooks } from './booksService';

export function OurBooksPage() {
  const { width, height } = useViewport();
  const { currentUser, isCoupleUser } = useAuth();
  const navigate = useNavigate();
  const [tab, setTab] = useState<0 | 1>(0);
  const [addOpen, setAddOpen] = useState(false);
  const [queryText, setQueryText] = useState('');
  const [results, setResults] = useState<BookSearchResult[]>([]);
  const [searching, setSearching] = useState(false);

  const items = useSource(() => watchOurBooks(300), [], []);
  const userName = currentUser ?? '';

  if (!isCoupleUser) {
    return (
      <div style={{ height: '100%', background: '#09060E', color: AppColors.petalWhite, display: 'grid', placeItems: 'center', padding: 24 }}>
        <div style={{ fontFamily: Fonts.display, fontSize: 18 }}>This space is just for the two of you.</div>
      </div>
    );
  }

  const toReadList = items.filter((b) => !b.khentReadAt && !b.clairReadAt);
  const readList = items.filter((b) => Boolean(b.khentReadAt || b.clairReadAt));
  const shown = tab === 0 ? toReadList : readList;

  const runSearch = async () => {
    if (!queryText.trim()) return;
    setSearching(true);
    const res = await searchBooksCatalog(queryText);
    setResults(res.results.slice(0, 12));
    setSearching(false);
  };

  return (
    <div style={{ position: 'relative', height: '100%', background: '#09060E', color: AppColors.petalWhite, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          pointerEvents: 'none',
          backgroundImage: [
            radial([withAlpha(AppColors.deepRose, 0.08), 'transparent'], { center: [-0.8, -0.8], radius: 0.9, size: [width, height] }),
            radial([withAlpha(AppColors.cinemaBlue, 0.05), 'transparent'], { center: [0.85, 0.85], radius: 0.8, size: [width, height] }),
          ].join(', '),
        }}
      />

      <div style={{ position: 'relative', padding: '12px 20px 6px', display: 'flex', alignItems: 'center' }}>
        <button
          type="button"
          className="bare-button"
          onClick={() => navigate(-1)}
          style={{
            width: 40,
            height: 40,
            borderRadius: 99,
            background: 'rgba(255,255,255,0.02)',
            border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.1)}`,
            display: 'grid',
            placeItems: 'center',
          }}
        >
          <Icon name="arrow_back_ios_new" size={18} color={AppColors.roseQuartz} />
        </button>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div style={{ fontFamily: Fonts.display, fontWeight: 900, fontSize: 24, letterSpacing: 4, color: AppColors.petalWhite }}>
            OUR BOOKS
          </div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
            <span style={{ width: 4, height: 4, borderRadius: 99, background: AppColors.deepRose }} />
            <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: 2.5, color: withAlpha(AppColors.roseQuartz, 0.6) }}>
              {userName === 'khentsgdz' ? 'KHENT & CLAIR' : 'CLAIR & KHENT'}
            </span>
            <span style={{ width: 4, height: 4, borderRadius: 99, background: AppColors.deepRose }} />
          </div>
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={() => setAddOpen(true)}
          style={{
            width: 40,
            height: 40,
            borderRadius: 99,
            background: 'rgba(255,255,255,0.02)',
            border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.1)}`,
            display: 'grid',
            placeItems: 'center',
          }}
        >
          <Icon name="add" size={18} color={AppColors.roseQuartz} />
        </button>
      </div>

      <div style={{ position: 'relative', padding: '8px 20px 12px' }}>
        <div
          style={{
            padding: 4,
            borderRadius: 24,
            background: 'rgba(255,255,255,0.02)',
            border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.05)}`,
            display: 'flex',
          }}
        >
          {([
            [0, 'To Read Together', toReadList.length],
            [1, 'Read', readList.length],
          ] as const).map(([idx, label, cnt]) => {
            const active = tab === idx;
            return (
              <button
                key={label}
                type="button"
                className="bare-button"
                onClick={() => setTab(idx)}
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 6,
                  padding: '10px 8px',
                  borderRadius: 20,
                  background: active ? withAlpha(AppColors.deepRose, 0.25) : 'transparent',
                  color: active ? AppColors.petalWhite : withAlpha(AppColors.roseQuartz, 0.6),
                  fontSize: 13,
                  fontWeight: 700,
                }}
              >
                <span>{label}</span>
                <span
                  style={{
                    minWidth: 20,
                    height: 20,
                    padding: '0 6px',
                    borderRadius: 99,
                    background: active ? AppColors.deepRose : 'rgba(255,255,255,0.08)',
                    color: active ? '#FFFFFF' : withAlpha(AppColors.roseQuartz, 0.65),
                    fontSize: 11,
                    fontWeight: 700,
                    display: 'inline-grid',
                    placeItems: 'center',
                  }}
                >
                  {cnt}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      <div style={{ position: 'relative', flex: 1, overflowY: 'auto', padding: '8px 20px 100px' }}>
        {shown.length === 0 ? (
          <div style={{ padding: '60px 20px', textAlign: 'center', color: withAlpha(AppColors.roseQuartz, 0.6) }}>
            {tab === 0 ? 'Nothing on your shared reading list yet.' : 'No finished books yet.'}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, maxWidth: 680, margin: '0 auto' }}>
            {shown.map((b) => {
              const iRead = userName === 'khentsgdz' ? Boolean(b.khentReadAt) : Boolean(b.clairReadAt);
              return (
                <div
                  key={b.id || b.workKey}
                  style={{
                    padding: 14,
                    borderRadius: 18,
                    background: 'rgba(255,255,255,0.03)',
                    border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.1)}`,
                    display: 'flex',
                    gap: 14,
                    alignItems: 'center',
                  }}
                >
                  {b.coverUrl && (
                    <img
                      src={b.coverUrl}
                      alt={b.title}
                      onClick={() => navigate('/books/reader', { state: { book: ourBookToBookItem(b) } })}
                      style={{ width: 72, height: 108, borderRadius: 10, objectFit: 'cover', cursor: 'pointer', flexShrink: 0 }}
                    />
                  )}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 15, fontWeight: 700, color: AppColors.petalWhite }}>{b.title}</div>
                    <div style={{ marginTop: 6 }}>
                      <span
                        style={{
                          display: 'inline-block',
                          padding: '3px 8px',
                          borderRadius: 99,
                          background: withAlpha(AppColors.deepRose, 0.14),
                          border: `1px solid ${withAlpha(AppColors.deepRose, 0.35)}`,
                          color: AppColors.roseQuartz,
                          fontSize: 9.5,
                          fontWeight: 700,
                          letterSpacing: 0.7,
                        }}
                      >
                        OPEN LIBRARY
                      </span>
                    </div>
                    <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
                      {([
                        ['K', 'Khent', Boolean(b.khentReadAt)],
                        ['C', 'Clair', Boolean(b.clairReadAt)],
                      ] as const).map(([init, name, done]) => (
                        <span
                          key={name}
                          style={{
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 5,
                            padding: '3px 9px',
                            borderRadius: 99,
                            background: 'rgba(255,255,255,0.03)',
                            border: `1px solid ${done ? withAlpha(AppColors.success, 0.45) : withAlpha(AppColors.roseQuartz, 0.14)}`,
                            fontSize: 11,
                            color: done ? AppColors.success : AppColors.mutedPurple,
                            fontWeight: 600,
                          }}
                        >
                          <span style={{ width: 15, height: 15, borderRadius: 99, background: 'rgba(255,255,255,0.1)', display: 'grid', placeItems: 'center', fontSize: 9, fontWeight: 800, color: AppColors.petalWhite }}>
                            {init}
                          </span>
                          {name}
                        </span>
                      ))}
                    </div>
                    <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => void setOurBookReadFlag(b.workKey, userName, !iRead)}
                        style={{
                          flex: 1,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: 6,
                          padding: '8px 12px',
                          borderRadius: 10,
                          background: iRead ? withAlpha(AppColors.success, 0.16) : withAlpha(AppColors.cinemaBlue, 0.12),
                          border: `1px solid ${withAlpha(iRead ? AppColors.success : AppColors.cinemaBlue, 0.35)}`,
                          color: AppColors.petalWhite,
                          fontSize: 12.5,
                          fontWeight: 700,
                        }}
                      >
                        <Icon name="menu_book" size={14} color={iRead ? AppColors.success : '#60A5FA'} />
                        {iRead ? 'Read' : 'I Read'}
                      </button>
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => void removeFromOurBooks(b.workKey)}
                        style={{
                          width: 36,
                          height: 36,
                          borderRadius: 10,
                          background: 'rgba(255,255,255,0.03)',
                          border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.14)}`,
                          display: 'grid',
                          placeItems: 'center',
                        }}
                      >
                        <Icon name="delete_outline" size={16} color={AppColors.roseQuartz} />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {addOpen && (
        <div
          onClick={() => setAddOpen(false)}
          style={{ position: 'fixed', inset: 0, zIndex: 80, background: 'rgba(0,0,0,0.75)', display: 'grid', placeItems: 'center', padding: 20 }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{ width: '100%', maxWidth: 460, maxHeight: '80vh', overflowY: 'auto', background: '#181022', borderRadius: 20, padding: 20, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.18)}` }}
          >
            <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 700 }}>Add to Our Books</div>
            <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
              <input
                value={queryText}
                onChange={(e) => setQueryText(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && void runSearch()}
                placeholder="Search Open Library…"
                style={{ flex: 1, padding: '10px 12px', borderRadius: 12, background: '#09060E', border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.2)}`, color: '#FFF', outline: 'none' }}
              />
              <button type="button" className="bare-button" onClick={() => void runSearch()} style={{ padding: '10px 16px', borderRadius: 12, background: AppColors.deepRose, color: '#FFF', fontWeight: 700 }}>
                Search
              </button>
            </div>
            <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
              {searching && <div style={{ fontSize: 13, color: AppColors.mutedPurple }}>Searching…</div>}
              {results.map((r) => (
                <button
                  key={r.workKey || r.title}
                  type="button"
                  className="bare-button"
                  onClick={async () => {
                    await addToOurBooks(searchResultToBookItem(r), userName);
                    setAddOpen(false);
                  }}
                  style={{ display: 'flex', gap: 10, padding: 8, borderRadius: 10, background: 'rgba(255,255,255,0.04)', textAlign: 'left', alignItems: 'center' }}
                >
                  {r.coverUrl && <img src={r.coverUrl} alt={r.title} style={{ width: 38, height: 54, borderRadius: 6, objectFit: 'cover' }} />}
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 700, color: AppColors.petalWhite }}>{r.title}</div>
                    <div style={{ fontSize: 11.5, color: AppColors.roseQuartz }}>{r.author}</div>
                  </div>
                  <Icon name="add" size={18} color={AppColors.roseQuartz} />
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
