// Port of lib/features/canvas: doodle_stroke.dart, canvas_point_utils.dart
// and canvas_service.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  writeBatch,
  type DocumentData,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { just, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';

export type CanvasPoint = { x: number; y: number };

export const LEGACY_CANVAS_ASPECT_RATIO = 2.0;

export type DoodleStroke = {
  id: string;
  points: CanvasPoint[];
  color: string;
  strokeWidth: number;
  canvasAspectRatio: number;
  createdAt: Date | null;
  userId: string;
  text: string | null;
};

export const isTextAnnotation = (s: DoodleStroke) => s.text != null && s.text !== '';

function parsePoints(raw: unknown): CanvasPoint[] {
  if (!Array.isArray(raw)) return [];
  const out: CanvasPoint[] = [];
  for (const p of raw) {
    if (p && typeof p === 'object') {
      const { x, y } = p as Record<string, unknown>;
      if (typeof x === 'number' && typeof y === 'number') out.push({ x, y });
    }
  }
  return out;
}

export function strokeFromMap(data: DocumentData, id: string): DoodleStroke {
  return {
    id,
    points: parsePoints(data.points),
    color: typeof data.color === 'string' ? data.color : '#FFC0CB',
    strokeWidth: typeof data.strokeWidth === 'number' ? data.strokeWidth : 3.0,
    canvasAspectRatio: typeof data.canvasAspectRatio === 'number' ? data.canvasAspectRatio : LEGACY_CANVAS_ASPECT_RATIO,
    createdAt: data.createdAt instanceof Timestamp ? data.createdAt.toDate() : null,
    userId: typeof data.userId === 'string' ? data.userId : '',
    text: typeof data.text === 'string' ? data.text : null,
  };
}

function strokeToMap(s: DoodleStroke) {
  return {
    points: s.points,
    color: s.color,
    strokeWidth: s.strokeWidth,
    canvasAspectRatio: s.canvasAspectRatio,
    createdAt: s.createdAt ? Timestamp.fromDate(s.createdAt) : serverTimestamp(),
    userId: s.userId,
    ...(s.text != null ? { text: s.text } : {}),
  };
}

/** Where a stored (0..1) point lands in a viewport, letterboxed to the stroke's aspect ratio. */
export function mapCanvasPointToViewport(x: number, y: number, w: number, h: number, canvasAspectRatio: number) {
  const aspect = Number.isFinite(canvasAspectRatio) && canvasAspectRatio > 0 ? canvasAspectRatio : 2.0;
  const scale = Math.min(w / aspect, h);
  const cw = aspect * scale;
  const ch = scale;
  return { x: (w - cw) / 2 + x * cw, y: (h - ch) / 2 + y * ch };
}

function perpendicularDistanceSquared(p: CanvasPoint, a: CanvasPoint, b: CanvasPoint) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  if (dx === 0 && dy === 0) return (p.x - a.x) ** 2 + (p.y - a.y) ** 2;
  let t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy);
  t = Math.min(1, Math.max(0, t));
  const nx = a.x + t * dx;
  const ny = a.y + t * dy;
  return (p.x - nx) ** 2 + (p.y - ny) ** 2;
}

/** Ramer–Douglas–Peucker, as in canvas_point_utils.dart. */
export function simplifyCanvasPoints(points: CanvasPoint[], epsilon = 0.001): CanvasPoint[] {
  if (points.length <= 2) return points;
  let index = -1;
  let maxDist = 0;
  for (let i = 1; i < points.length - 1; i++) {
    const d = perpendicularDistanceSquared(points[i], points[0], points[points.length - 1]);
    if (d > maxDist) {
      index = i;
      maxDist = d;
    }
  }
  if (maxDist > epsilon * epsilon) {
    const left = simplifyCanvasPoints(points.slice(0, index + 1), epsilon);
    const right = simplifyCanvasPoints(points.slice(index), epsilon);
    return [...left.slice(0, left.length - 1), ...right];
  }
  return [points[0], points[points.length - 1]];
}

const STROKES = 'canvas_strokes';
const LIVE = 'live_canvas';
const MAX_STROKES = 2400;

class CanvasService {
  getStrokesStream(): Source<DoodleStroke[]> {
    if (AgentMode.demo) return just([]);
    const subscribe: Source<DoodleStroke[]> = (l) => {
      let active = true;
      let max = 300;
      let unsub = () => {};
      const listen = () => {
        if (!active) return;
        unsub = onSnapshot(
          query(collection(db, STROKES), orderBy('createdAt'), limit(max)),
          (snap) => {
            if (!active) return;
            if (snap.docs.length === max && max < MAX_STROKES) {
              max = Math.min(max * 2, MAX_STROKES);
              unsub();
              listen();
              return;
            }
            l.data(snap.docs.map((d) => strokeFromMap(d.data(), d.id)));
          },
          (e) => {
            if (active) l.error?.(e);
          },
        );
      };
      listen();
      return () => {
        active = false;
        unsub();
      };
    };
    return withFirestoreTimeout(subscribe, { label: 'canvas-strokes', resubscribe: () => subscribe });
  }

  async saveStroke(stroke: DoodleStroke): Promise<DoodleStroke> {
    if (AgentMode.demo) return { ...stroke, id: 'demo-stroke' };
    const ref = await addDoc(collection(db, STROKES), strokeToMap(stroke));
    return { ...stroke, id: ref.id };
  }

  async deleteStroke(id: string): Promise<void> {
    if (AgentMode.demo) return;
    await deleteDoc(doc(db, STROKES, id));
  }

  async updateActiveStroke(userId: string, stroke: DoodleStroke): Promise<void> {
    if (AgentMode.demo) return;
    await setDoc(doc(db, LIVE, userId), strokeToMap(stroke));
  }

  async clearActiveStroke(userId: string): Promise<void> {
    if (AgentMode.demo) return;
    await deleteDoc(doc(db, LIVE, userId));
  }

  getLiveStrokesStream(): Source<DoodleStroke[]> {
    if (AgentMode.demo) return just([]);
    const src: Source<DoodleStroke[]> = (l) =>
      onSnapshot(
        query(collection(db, LIVE), limit(50)),
        (snap) => l.data(snap.docs.map((d) => strokeFromMap(d.data(), d.id))),
        (e) => l.error?.(e),
      );
    return withFirestoreTimeout(src, { label: 'canvas-live' });
  }

  async clearAllStrokes(): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await this.deleteCollectionChunked(STROKES, 'canvas clear strokes');
      await this.deleteCollectionChunked(LIVE, 'canvas clear live');
    } catch (e) {
      Logger.e('Canvas clearAllStrokes failed', e);
    }
  }

  private async deleteCollectionChunked(name: string, label: string) {
    for (let page = 0; page < 20; page++) {
      const snap = await withGetTimeout(getDocs(query(collection(db, name), limit(500))), label);
      if (snap.empty) break;
      const batch = writeBatch(db);
      for (const d of snap.docs) batch.delete(d.ref);
      await batch.commit();
      if (snap.docs.length < 500) break;
    }
  }
}

export const canvasService = new CanvasService();
