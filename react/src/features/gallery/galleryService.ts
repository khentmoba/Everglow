// Port of lib/features/gallery/data/services/gallery_service.dart + domain/models/memory_photo.dart.
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
  startAfter,
  Timestamp,
  updateDoc,
  where,
  type DocumentData,
  type QueryDocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { deleteObject, getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type MemoryPhotoFixture } from '../../core/agent/fixtures';
import { auth, db, storage } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type MemoryPhoto = MemoryPhotoFixture & {
  latitude?: number;
  longitude?: number;
  takenAt?: Date;
};

const COLLECTION = 'gallery';

export function displayGalleryUrl(url: string, thumb = false): string {
  if (!url) return '';
  if (url.includes('firebasestorage.googleapis.com')) {
    const proxied = `https://us-central1-everglow-1c6db.cloudfunctions.net/proxyGalleryImage?url=${encodeURIComponent(url)}`;
    return thumb ? `${proxied}&w=440` : proxied;
  }
  if (url.startsWith('http') || url.startsWith('/')) return url;
  if (url.startsWith('assets/')) return `/${url.slice('assets/'.length)}`;
  return url;
}

export function gridPhotoUrl(photo: MemoryPhoto): string {
  const preview = photo.thumbUrl && photo.thumbUrl.length > 0 ? photo.thumbUrl : photo.imageUrl;
  return displayGalleryUrl(preview, !(photo.thumbUrl && photo.thumbUrl.length > 0));
}

function monthDay(d: Date): string {
  return `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function parseCoord(v: unknown): number | undefined {
  if (typeof v === 'number' && !Number.isNaN(v)) return v;
  if (typeof v === 'string') {
    const n = Number(v);
    return Number.isNaN(n) ? undefined : n;
  }
  return undefined;
}

function parseTs(v: unknown): Date {
  if (v && typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
  if (typeof v === 'number') return new Date(v);
  if (typeof v === 'string') {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return new Date();
}

function mapDoc(d: QueryDocumentSnapshot<DocumentData>): MemoryPhoto {
  const data = d.data();
  return {
    id: d.id,
    imageUrl: String(data.imageUrl ?? ''),
    thumbUrl: String(data.thumbUrl ?? ''),
    caption: String(data.caption ?? ''),
    uploadedBy: String(data.uploadedBy ?? ''),
    uploadedAt: parseTs(data.uploadedAt),
    tags: Array.isArray(data.tags) ? data.tags.map(String) : [],
    locationName: typeof data.locationName === 'string' ? data.locationName : undefined,
    latitude: parseCoord(data.latitude),
    longitude: parseCoord(data.longitude),
    takenAt: data.takenAt != null ? parseTs(data.takenAt) : undefined,
  };
}

async function resizeJpeg(file: File, maxDim: number, quality = 0.86): Promise<Blob> {
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new Image();
      el.onload = () => resolve(el);
      el.onerror = reject;
      el.src = url;
    });
    const ratio = Math.min(1, maxDim / Math.max(img.width, img.height));
    const w = Math.max(1, Math.round(img.width * ratio));
    const h = Math.max(1, Math.round(img.height * ratio));
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    if (!ctx) return file;
    ctx.drawImage(img, 0, 0, w, h);
    const blob = await new Promise<Blob | null>((res) => canvas.toBlob(res, 'image/jpeg', quality));
    return blob ?? file;
  } finally {
    URL.revokeObjectURL(url);
  }
}

class GalleryService {
  private demoPhotos: MemoryPhoto[] | null = null;
  private demoChanges = new Changes(() => [...(this.demoPhotos ?? AgentFixtures.demoPhotos())]);

  private ensureDemo(): MemoryPhoto[] {
    if (!this.demoPhotos) {
      this.demoPhotos = AgentFixtures.demoPhotos();
    }
    return this.demoPhotos;
  }

  getPhotosStream(max = 40): Source<MemoryPhoto[]> {
    if (AgentMode.demo) {
      this.ensureDemo();
      return this.demoChanges.source;
    }
    const q = query(collection(db, COLLECTION), orderBy('uploadedAt', 'desc'), limit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, MemoryPhoto[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) => s.docs.map(mapDoc),
      ),
      { label: 'gallery-grid' },
    );
  }

  getRecentPhotos(max = 6): Source<MemoryPhoto[]> {
    return this.getPhotosStream(max);
  }

  async fetchOlderPhotos(
    cursor: QueryDocumentSnapshot<DocumentData> | null,
    before: Date,
    max = 40,
  ): Promise<{ items: MemoryPhoto[]; nextCursor: QueryDocumentSnapshot<DocumentData> | null; hasMore: boolean }> {
    if (AgentMode.demo) return { items: [], nextCursor: null, hasMore: false };
    const q = cursor
      ? query(collection(db, COLLECTION), orderBy('uploadedAt', 'desc'), startAfter(cursor), limit(max))
      : query(
          collection(db, COLLECTION),
          orderBy('uploadedAt', 'desc'),
          startAfter(Timestamp.fromDate(before)),
          limit(max),
        );
    const snap = await getDocs(q);
    return {
      items: snap.docs.map(mapDoc),
      nextCursor: snap.docs.length < max ? null : snap.docs[snap.docs.length - 1],
      hasMore: snap.docs.length === max,
    };
  }

  async searchPhotos(term: string, recent: MemoryPhoto[] = []): Promise<MemoryPhoto[]> {
    const q = term.trim().toLowerCase();
    if (!q) return [];
    const matches = (p: MemoryPhoto) =>
      p.caption.toLowerCase().includes(q) ||
      p.tags.some((t) => t.toLowerCase().includes(q)) ||
      (p.locationName?.toLowerCase().includes(q) ?? false);

    if (AgentMode.demo) {
      return this.ensureDemo().filter(matches);
    }
    const recentIds = new Set(recent.map((p) => p.id));
    const snap = await getDocs(query(collection(db, COLLECTION), orderBy('uploadedAt', 'desc'), limit(200)));
    const all = snap.docs.map(mapDoc);
    return [...recent, ...all.filter((p) => !recentIds.has(p.id))].filter(matches);
  }

  async getPhotosWithLocation(max = 100): Promise<MemoryPhoto[]> {
    if (AgentMode.demo) {
      return this.ensureDemo().filter((p) => p.latitude != null && p.longitude != null);
    }
    const snap = await getDocs(query(collection(db, COLLECTION), orderBy('uploadedAt', 'desc'), limit(max)));
    return snap.docs.map(mapDoc).filter((p) => p.latitude != null && p.longitude != null);
  }

  async getPhotosFromThisWeek(): Promise<MemoryPhoto[]> {
    if (AgentMode.demo) {
      return this.ensureDemo();
    }
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const snap = await getDocs(query(collection(db, COLLECTION), orderBy('uploadedAt', 'desc'), limit(100)));
    return snap.docs
      .map(mapDoc)
      .filter((p) => {
        if (p.uploadedAt.getFullYear() === now.getFullYear()) return false;
        const anniv = new Date(now.getFullYear(), p.uploadedAt.getMonth(), p.uploadedAt.getDate());
        const diff = Math.abs(Math.round((anniv.getTime() - today.getTime()) / 86_400_000));
        return diff <= 3;
      })
      .sort((a, b) => b.uploadedAt.getTime() - a.uploadedAt.getTime());
  }

  async uploadPhoto(opts: {
    file: File;
    caption: string;
    uploadedBy: string;
    userId: string;
    tags: string[];
    locationName?: string;
    latitude?: number;
    longitude?: number;
  }): Promise<MemoryPhoto> {
    if (AgentMode.demo) {
      const previewUrl = URL.createObjectURL(opts.file);
      const created: MemoryPhoto = {
        id: `demo_photo_${Date.now()}`,
        imageUrl: previewUrl,
        thumbUrl: previewUrl,
        caption: opts.caption,
        uploadedBy: opts.uploadedBy,
        uploadedAt: new Date(),
        tags: opts.tags,
        locationName: opts.locationName || undefined,
        latitude: opts.latitude,
        longitude: opts.longitude,
      };
      this.demoPhotos = [created, ...this.ensureDemo()];
      this.demoChanges.emit();
      return created;
    }

    const safe = opts.file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
    const base = `gallery/${opts.userId}/${Date.now()}_${safe}`;
    const [fullBlob, thumbBlob] = await Promise.all([
      resizeJpeg(opts.file, 1920, 0.88),
      resizeJpeg(opts.file, 480, 0.8),
    ]);

    const fullRef = ref(storage, `${base}_full.jpg`);
    await uploadBytes(fullRef, fullBlob, {
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=31536000',
    });
    const imageUrl = await getDownloadURL(fullRef);

    let thumbUrl: string | undefined;
    try {
      const thumbRef = ref(storage, `${base}_thumb.jpg`);
      await uploadBytes(thumbRef, thumbBlob, {
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      });
      thumbUrl = await getDownloadURL(thumbRef);
    } catch (e) {
      Logger.e('Thumbnail upload failed, grid falls back to full', e);
    }

    const payload: Record<string, unknown> = {
      imageUrl,
      caption: opts.caption,
      uploadedBy: opts.uploadedBy,
      uploadedAt: serverTimestamp(),
      tags: opts.tags,
      monthDay: monthDay(new Date()),
    };
    if (thumbUrl) payload.thumbUrl = thumbUrl;
    if (opts.locationName?.trim()) payload.locationName = opts.locationName.trim();
    if (opts.latitude != null) payload.latitude = opts.latitude;
    if (opts.longitude != null) payload.longitude = opts.longitude;

    const refDoc = await addDoc(collection(db, COLLECTION), payload);
    return {
      id: refDoc.id,
      imageUrl,
      thumbUrl: thumbUrl ?? '',
      caption: opts.caption,
      uploadedBy: opts.uploadedBy,
      uploadedAt: new Date(),
      tags: opts.tags,
      locationName: opts.locationName,
      latitude: opts.latitude,
      longitude: opts.longitude,
    };
  }

  async deletePhoto(photo: MemoryPhoto): Promise<void> {
    if (AgentMode.demo) {
      this.demoPhotos = this.ensureDemo().filter((p) => p.id !== photo.id);
      this.demoChanges.emit();
      return;
    }
    const urls = Array.from(new Set([photo.imageUrl, photo.thumbUrl].filter((u): u is string => Boolean(u))));
    for (const url of urls) {
      try {
        await deleteObject(ref(storage, url));
      } catch {
        const token = await auth.currentUser?.getIdToken().catch(() => '');
        if (token) {
          await fetch('https://us-central1-everglow-1c6db.cloudfunctions.net/deleteGalleryPhoto', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify({ imageUrl: url }),
          }).catch(() => {});
        }
      }
    }
    await deleteDoc(doc(db, COLLECTION, photo.id));
  }

  async updatePhotoCaption(id: string, caption: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoPhotos = this.ensureDemo().map((p) => (p.id === id ? { ...p, caption } : p));
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, COLLECTION, id), { caption });
  }
}

export const galleryService = new GalleryService();
export { where };
