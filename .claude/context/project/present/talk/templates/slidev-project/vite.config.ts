import { defineConfig } from 'vite'

export default defineConfig({
  resolve: {
    alias: {
      // lz-string is CJS-only and Vite's dep optimizer fails to pre-bundle
      // it under pnpm's strict layout. Alias to a self-contained ESM build.
      'lz-string': new URL('./lz-string-esm.js', import.meta.url).pathname,
    },
  },
})
