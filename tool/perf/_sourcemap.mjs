// Minimal source-map decoder for perf traces.
//
// dart2js release output is minified, so a CDP trace only ever names things
// like `$1 @main.dart.js:54713`. Building with `--source-maps` does not change
// the emitted code, so the same measurement can be resolved back to the Dart
// function that actually spent the time. That is the difference between
// guessing at a hotspot and knowing one.
import { readFileSync } from 'node:fs';

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const CHAR_TO_INT = new Map([...B64].map((c, i) => [c, i]));

/** Decodes one VLQ segment into its signed integers. */
function decodeSegment(segment) {
  const out = [];
  let value = 0;
  let shift = 0;
  for (const char of segment) {
    const digit = CHAR_TO_INT.get(char);
    if (digit === undefined) throw new Error(`bad source-map character: ${char}`);
    value += (digit & 31) << shift;
    if (digit & 32) {
      shift += 5;
      continue;
    }
    out.push(value & 1 ? -(value >> 1) : value >> 1);
    value = 0;
    shift = 0;
  }
  return out;
}

/**
 * Loads a source map and exposes `lookup(line, column)` with 1-based line and
 * 0-based column, matching CDP's `callFrame.lineNumber` / `columnNumber`.
 */
export function loadSourceMap(path) {
  const map = JSON.parse(readFileSync(path, 'utf8'));
  const sources = map.sources ?? [];
  const names = map.names ?? [];
  // generated line (0-based) -> array of decoded segments
  const lines = [];
  let sourceIdx = 0;
  let origLine = 0;
  let origCol = 0;
  let nameIdx = 0;
  for (const rawLine of (map.mappings ?? '').split(';')) {
    const segments = [];
    let genCol = 0;
    if (rawLine) {
      for (const rawSegment of rawLine.split(',')) {
        if (!rawSegment) continue;
        const fields = decodeSegment(rawSegment);
        genCol += fields[0];
        if (fields.length >= 4) {
          sourceIdx += fields[1];
          origLine += fields[2];
          origCol += fields[3];
          if (fields.length >= 5) nameIdx += fields[4];
          segments.push({
            genCol,
            source: sources[sourceIdx] ?? `#${sourceIdx}`,
            line: origLine,
            col: origCol,
            name: fields.length >= 5 ? names[nameIdx] ?? '' : '',
          });
        } else {
          segments.push({ genCol, source: null });
        }
      }
    }
    lines.push(segments);
  }

  return {
    size: lines.length,
    /** Resolves a generated position, or null when it has no mapping. */
    lookup(line, column) {
      const segments = lines[line - 1];
      if (!segments?.length) return null;
      let best = null;
      for (const segment of segments) {
        if (segment.genCol > column) break;
        if (segment.source) best = segment;
      }
      best ??= segments.find((s) => s.source) ?? null;
      if (!best) return null;
      return {
        source: best.source,
        line: best.line + 1,
        column: best.col + 1,
        name: best.name,
      };
    },
  };
}

/** Shortens an original path to something readable in a report. */
export function shortSource(source) {
  return String(source).replace(/^.*?(lib[\\/]|package:)/, '$1').replace(/\\/g, '/');
}
