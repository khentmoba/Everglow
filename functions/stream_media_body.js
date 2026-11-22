'use strict';

const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');

const RASTER_IMAGE_RE = /^image\/(jpeg|jpg|png|webp|gif|avif|bmp|x-icon|vnd\.microsoft\.icon)$/;
const GENERIC_BINARY_TYPES = new Set(['', 'application/octet-stream', 'binary/octet-stream']);
const GIF87A = Buffer.from('GIF87a');
const GIF89A = Buffer.from('GIF89a');

function sniffRasterContentType(bytes) {
  if (!bytes || bytes.length < 2) return null;
  const b = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return 'image/jpeg';
  if (
    b.length >= 8 &&
    b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47 &&
    b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a && b[7] === 0x0a
  ) return 'image/png';
  if (b.length >= 6 && (b.subarray(0, 6).equals(GIF87A) || b.subarray(0, 6).equals(GIF89A))) return 'image/gif';
  if (b.length >= 12 && b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP') {
    return 'image/webp';
  }
  if (b.length >= 12 && b.toString('ascii', 4, 8) === 'ftyp') {
    const brand = b.toString('ascii', 8, 12);
    if (brand === 'avif' || brand === 'avis') return 'image/avif';
  }
  if (b[0] === 0x42 && b[1] === 0x4d) return 'image/bmp';
  if (b.length >= 4 && b[0] === 0x00 && b[1] === 0x00 && b[2] === 0x01 && b[3] === 0x00) return 'image/x-icon';
  return null;
}

async function resolveRasterImageStream(upstream) {
  const base = String(upstream.headers?.get?.('content-type') || '').split(';')[0].trim().toLowerCase();
  if (RASTER_IMAGE_RE.test(base)) {
    return { contentType: base, body: upstream.body };
  }
  if (!GENERIC_BINARY_TYPES.has(base)) {
    await upstream.body?.cancel?.().catch(() => {});
    return null;
  }
  if (!upstream.body || typeof upstream.body.getReader !== 'function') return null;

  const reader = upstream.body.getReader();
  const headChunks = [];
  let total = 0;
  let eof = false;
  for (let reads = 0; reads < 16 && total < 12; reads++) {
    const { done, value } = await reader.read();
    if (done) {
      eof = true;
      break;
    }
    if (value && value.byteLength > 0) {
      headChunks.push(value);
      total += value.byteLength;
    }
  }

  const head = headChunks.length === 1 ? headChunks[0] : Buffer.concat(headChunks, total);
  const contentType = sniffRasterContentType(head);
  if (!contentType) {
    if (!eof) await reader.cancel().catch(() => {});
    return null;
  }

  const body = new ReadableStream({
    async pull(controller) {
      if (headChunks.length > 0) {
        controller.enqueue(headChunks.shift());
        return;
      }
      if (eof) {
        controller.close();
        return;
      }
      const { done, value } = await reader.read();
      if (done) {
        eof = true;
        controller.close();
        return;
      }
      controller.enqueue(value);
    },
    cancel(reason) {
      if (!eof) return reader.cancel(reason);
    },
  });
  return { contentType, body };
}

async function streamMediaBody(body, response) {
  try {
    await pipeline(Readable.fromWeb(body), response);
  } catch (error) {
    if (error.code !== 'ERR_STREAM_PREMATURE_CLOSE') throw error;
  }
}

module.exports = { resolveRasterImageStream, sniffRasterContentType, streamMediaBody };
