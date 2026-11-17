import { cpSync, existsSync, statSync, createReadStream } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';

// Self-contained web games that live in the Flutter `web/` folder and are
// shown in an iframe. Served as-is at the same paths the Flutter build uses.
const WEB_FOLDERS = ['table_tennis'];
const webRoot = resolve(__dirname, '../web');

const TYPES: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.wav': 'audio/wav',
};

function webGames(): Plugin {
  return {
    name: 'everglow-web-games',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const path = decodeURIComponent((req.url ?? '').split('?')[0]);
        if (!WEB_FOLDERS.some((f) => path.startsWith(`/${f}/`))) return next();
        const file = join(webRoot, path);
        if (!file.startsWith(webRoot) || !existsSync(file) || !statSync(file).isFile()) return next();
        res.setHeader('Content-Type', TYPES[extname(file)] ?? 'application/octet-stream');
        createReadStream(file).pipe(res);
      });
    },
    closeBundle() {
      for (const f of WEB_FOLDERS) cpSync(join(webRoot, f), resolve(__dirname, 'dist', f), { recursive: true });
    },
  };
}

// The Flutter app and this one share one `assets/` folder, so fonts and
// images live in a single place until the move is finished.
export default defineConfig({
  plugins: [react(), webGames()],
  publicDir: '../assets',
  server: { open: false },
  preview: { open: false },
});
