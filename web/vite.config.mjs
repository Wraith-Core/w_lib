import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import * as path from 'path';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: './',
  server: {
    port: 3000,
  },
  build: {
    // ★ build/ is this app's output. w_lib's fxmanifest serves web/build/**, and the cutover
    //   from the previous vanilla UI is done -- it is kept in the session scratchpad, not here.
    outDir: 'build',
    target: 'esnext',
    minify: 'esbuild',
    sourcemap: false,
    emptyOutDir: true,
  },
  esbuild: {
    legalComments: 'inline',
    logOverride: { 'this-is-undefined-in-esm': 'silent' },
  },
});
