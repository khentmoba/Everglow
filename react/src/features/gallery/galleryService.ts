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
  documentId,
  type DocumentData,
  type QueryDocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type MemoryPhotoFixture } from '../../core/agent/fixtures';
import { auth, db, loadStorage } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Changes, just, snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';

export type MemoryPhoto = MemoryPhotoFixture & {
  latitude?: number;
  longitude?: number;
  takenAt?: Date;
};

const COLLECTION = 'gallery';

export function displayGalleryUrl(url: string, _thumb = false): string {
  if (!url) return '';
  if (url.includes('firebasestorage.googleapis.com')) {
    return `https://us-central1-everglow-1c6db.cloudfunctions.net/proxyGalleryImage?url=${encodeURIComponent(url)}`;
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

// Port of upload_image_preparation_web.dart: a 1600px full image and a 400px
// thumb, both JPEG 0.85; the original bytes (and no thumb) if the browser fails.
async function prepareImages(file: Blob): Promise<{ full: Blob; thumb: Blob | null }> {
  const url = URL.createObjectURL(file);
  const image = new Image();
  image.src = url;
  try {
    await image.decode();
    const resize = async (longestEdge: number) => {
      const scale = Math.min(1, longestEdge / Math.max(image.naturalWidth, image.naturalHeight));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
      canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
      try {
        canvas.getContext('2d')!.drawImage(image, 0, 0, canvas.width, canvas.height);
        const blob = await new Promise<Blob | null>((res) => canvas.toBlob(res, 'image/jpeg', 0.85));
        if (!blob) throw new Error('JPEG encoding failed');
        return blob;
      } finally {
        canvas.width = canvas.height = 0;
      }
    };
    return { full: await resize(1600), thumb: await resize(400) };
  } catch (e) {
    Logger.e('Browser image preparation failed, using original bytes', e);
    return { full: file, thumb: null };
  } finally {
    URL.revokeObjectURL(url);
  }
}

function safeUrlPath(raw: string): string {
  try {
    const u = new URL(raw);
    return u.origin + u.pathname;
  } catch {
    return '<invalid-url>';
  }
}

function isObjectNotFound(e: unknown): boolean {
  const code = (e as { code?: string } | null)?.code;
  return code === 'object-not-found' || code === 'storage/object-not-found';
}

async function deleteStorageViaFunction(imageUrl: string): Promise<void> {
  try {
    const idToken = (await auth.currentUser?.getIdToken()) ?? '';
    if (!idToken) throw new Error('No authenticated user for gallery file cleanup');
    let lastError: unknown = null;
    for (const url of ['/api/deleteGalleryPhoto', 'https://us-central1-everglow-1c6db.cloudfunctions.net/deleteGalleryPhoto']) {
      try {
        const resp = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
          body: JSON.stringify({ imageUrl }),
          signal: AbortSignal.timeout(10_000),
        });
        if (resp.status === 200) return;
        lastError = new Error(`deleteGalleryPhoto ${url} returned ${resp.status}`);
        Logger.e('Gallery storage fallback failed', lastError);
      } catch (e) {
        Logger.e(`deleteGalleryPhoto attempt failed for ${url}`, e);
        lastError = e;
      }
    }
    throw lastError ?? new Error('Gallery storage fallback did not run');
  } catch (e) {
    Logger.e(`Gallery: storage cleanup via function failed for ${safeUrlPath(imageUrl)}`, e);
    throw e;
  }
}

async function deleteStorageObject(imageUrl: string): Promise<void> {
  try {
    const { storage, mod } = await loadStorage();
    await mod.deleteObject(mod.ref(storage, imageUrl));
  } catch (e) {
    if (isObjectNotFound(e)) return;
    await deleteStorageViaFunction(imageUrl);
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

  watchPhotosByIds(ids: string[]): Source<MemoryPhoto[]> {
    if (ids.length === 0) return just([]);
    if (AgentMode.isActive.value) return just(AgentFixtures.demoPhotos().filter((p) => ids.includes(p.id)));
    const q = query(collection(db, COLLECTION), where(documentId(), 'in', ids.slice(0, 20)));
    return snapshots<QuerySnapshot<DocumentData>, MemoryPhoto[]>(
      (next, error) => onSnapshot(q, next, error),
      (snap) => {
        const photos = new Map(snap.docs.map((d) => [d.id, mapDoc(d)]));
        return ids.flatMap((id) => (photos.has(id) ? [photos.get(id)!] : []));
      },
    );
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
      : query(collection(db, COLLECTION), orderBy('uploadedAt', 'desc'), startAfter(Timestamp.fromDate(before)), limit(max));
    const snap = await getDocs(q);
    return {
      items: snap.docs.map(mapDoc),
      nextCursor: snap.docs.length < max ? null : snap.docs[snap.docs.length - 1],
      hasMore: snap.docs.length === max,
    };
  }

  // A photo the partner deletes stays searchable until the page is reopened (same as Flutter).
  private searchIndex: Promise<MemoryPhoto[]> | null = null;

  private async readAllPhotos(): Promise<MemoryPhoto[]> {
    const photos: MemoryPhoto[] = [];
    let cursor: QueryDocumentSnapshot<DocumentData> | null = null;
    do {
      const base = query(collection(db, COLLECTION), orderBy('uploadedAt', 'desc'));
      const snap: QuerySnapshot<DocumentData> = await getDocs(
        cursor ? query(base, startAfter(cursor), limit(40)) : query(base, limit(40)),
      );
      photos.push(...snap.docs.map(mapDoc));
      cursor = snap.docs.length < 40 ? null : snap.docs[snap.docs.length - 1];
    } while (cursor);
    return photos;
  }

  async searchPhotos(term: string, recent: MemoryPhoto[] = []): Promise<MemoryPhoto[]> {
    const q = term.toLowerCase().trim();
    const matches = (p: MemoryPhoto) => p.caption.toLowerCase().includes(q) || p.tags.some((t) => t.toLowerCase().includes(q));
    if (AgentMode.demo) return AgentFixtures.demoPhotos().filter(matches);
    if (!q) return [];
    const index = (this.searchIndex ??= this.readAllPhotos());
    let all: MemoryPhoto[];
    try {
      all = await index;
    } catch (e) {
      if (this.searchIndex === index) this.searchIndex = null;
      throw e;
    }
    const recentIds = new Set(recent.map((p) => p.id));
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
    const windowMonthDays = Array.from({ length: 7 }, (_, i) => {
      const d = new Date(today.getTime() + (i - 3) * 86_400_000);
      return monthDay(d);
    });
    const col = collection(db, COLLECTION);
    let snap = await withGetTimeout(
      getDocs(query(col, where('monthDay', 'in', windowMonthDays), limit(200))),
      'gallery this-week',
    );
    if (snap.empty) {
      snap = await withGetTimeout(
        getDocs(query(col, orderBy('uploadedAt', 'desc'), limit(200))),
        'gallery this-week fallback',
      );
    }
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
    file: Blob;
    fileName: string;
    caption: string;
    uploadedBy: string;
    userId: string;
    tags?: string[];
    locationName?: string;
    latitude?: number;
    longitude?: number;
    takenAt?: Date;
    onProgress?: (progress: number) => void;
  }): Promise<MemoryPhoto> {
    if (AgentMode.demo) return AgentFixtures.demoPhotos()[0];
    const tags = opts.tags ?? [];
    const base = `gallery/${opts.userId}/${Date.now()}_${opts.fileName.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
    const images = await prepareImages(opts.file);
    const uploaded: string[] = [];
    const total = images.full.size + (images.thumb?.size ?? 0);
    let sent = 0;
    const report = (inFlight: number) => opts.onProgress?.(Math.min(1, Math.max(0, (sent + inFlight) / total)));
    const put = async (path: string, blob: Blob) => {
      const { storage, mod } = await loadStorage();
      const fileRef = mod.ref(storage, path);
      const task = mod.uploadBytesResumable(fileRef, blob, { contentType: 'image/jpeg', cacheControl: 'public, max-age=31536000' });
      const stop = task.on(
        'state_changed',
        (snap) => report(snap.bytesTransferred),
        () => {},
      );
      try {
        await task;
      } finally {
        stop();
      }
      const url = await mod.getDownloadURL(fileRef);
      uploaded.push(url);
      sent += blob.size;
      report(0);
      return url;
    };

    const imageUrl = await put(`${base}_full.jpg`, images.full);
    let thumbUrl: string | undefined;
    if (images.thumb) {
      try {
        thumbUrl = await put(`${base}_thumb.jpg`, images.thumb);
      } catch (e) {
        Logger.e('Thumbnail upload failed, grid falls back to full', e);
      }
    }

    const payload: Record<string, unknown> = {
      imageUrl,
      ...(thumbUrl != null ? { thumbUrl } : {}),
      caption: opts.caption,
      uploadedBy: opts.uploadedBy,
      uploadedAt: serverTimestamp(),
      tags,
      monthDay: monthDay(new Date()),
      ...(opts.latitude != null ? { latitude: opts.latitude } : {}),
      ...(opts.longitude != null ? { longitude: opts.longitude } : {}),
      ...(opts.locationName ? { locationName: opts.locationName } : {}),
      ...(opts.takenAt ? { takenAt: Timestamp.fromDate(opts.takenAt) } : {}),
    };
    let refDoc;
    try {
      refDoc = await addDoc(collection(db, COLLECTION), payload);
    } catch (e) {
      for (const url of uploaded) {
        try {
          await deleteStorageObject(url);
        } catch (err) {
          Logger.e(`Gallery: failed to clean uploaded file ${safeUrlPath(url)}`, err);
        }
      }
      throw e;
    }
    return {
      id: refDoc.id,
      imageUrl,
      thumbUrl: thumbUrl ?? '',
      caption: opts.caption,
      uploadedBy: opts.uploadedBy,
      uploadedAt: new Date(),
      tags,
      latitude: opts.latitude,
      longitude: opts.longitude,
      locationName: opts.locationName,
      takenAt: opts.takenAt,
    };
  }

  async deletePhoto(photo: MemoryPhoto): Promise<void> {
    if (AgentMode.demo) return;
    try {
      for (const url of new Set([photo.imageUrl, ...(photo.thumbUrl ? [photo.thumbUrl] : [])])) {
        await deleteStorageObject(url);
      }
      await deleteDoc(doc(db, COLLECTION, photo.id));
      this.searchIndex = this.searchIndex?.then((photos) => photos.filter((p) => p.id !== photo.id)) ?? null;
    } catch (e) {
      Logger.e(`Error deleting photo: ${photo.id}`, e);
      throw e;
    }
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

/** `getPhotosFromThisDay`: photos uploaded on today's date in earlier years (none in demo mode). */
export async function getPhotosFromThisDay(): Promise<MemoryPhoto[]> {
  if (AgentMode.demo) return [];
  const now = new Date();
  try {
    const col = collection(db, COLLECTION);
    let snap = await withGetTimeout(
      getDocs(query(col, where('monthDay', '==', monthDay(now)), limit(100))),
      'gallery on-this-day',
    );
    if (snap.empty) {
      snap = await withGetTimeout(getDocs(query(col, orderBy('uploadedAt', 'desc'), limit(200))), 'gallery on-this-day fallback');
    }
    return snap.docs
      .map(mapDoc)
      .filter(
        (p) =>
          p.uploadedAt.getMonth() === now.getMonth() &&
          p.uploadedAt.getDate() === now.getDate() &&
          p.uploadedAt.getFullYear() !== now.getFullYear(),
      );
  } catch (e) {
    Logger.e('Error getting on-this-day photos', e);
    return [];
  }
}
