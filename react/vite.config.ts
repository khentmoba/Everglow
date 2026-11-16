import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The Flutter app and this one share one `assets/` folder, so fonts and
// images live in a single place until the move is finished.
export default defineConfig({
  plugins: [react()],
  publicDir: '../assets',
  server: { open: false },
  preview: { open: false },
});
