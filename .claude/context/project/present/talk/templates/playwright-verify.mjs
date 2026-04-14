// Playwright slide verification script for Slidev decks.
// Starts a dev server, visits each slide, checks for errors, takes screenshots.
// Usage: node scripts/verify-slides.mjs [--screenshots]
//
// Exit code 0 = all slides OK, exit code 1 = errors found.

import { chromium } from 'playwright-chromium';
import { execSync, spawn } from 'child_process';
import { mkdirSync, existsSync } from 'fs';

const TAKE_SCREENSHOTS = process.argv.includes('--screenshots');
const PORT = 3099;
const BASE = `http://localhost:${PORT}`;
const SCREENSHOT_DIR = 'scripts/screenshots';

async function startDevServer() {
  const server = spawn('npx', ['@slidev/cli', '--port', String(PORT)], {
    stdio: ['ignore', 'pipe', 'pipe'],
    detached: true,
  });
  // Wait for server to be ready
  for (let i = 0; i < 30; i++) {
    try {
      await fetch(BASE);
      return server;
    } catch {
      await new Promise(r => setTimeout(r, 1000));
    }
  }
  throw new Error('Dev server did not start within 30 seconds');
}

function countSlides() {
  const content = execSync('cat slides.md', { encoding: 'utf-8' });
  // Count slide separators (--- at start of line, not in frontmatter)
  const lines = content.split('\n');
  let count = 1; // first slide has no separator
  let inFrontmatter = false;
  for (let i = 0; i < lines.length; i++) {
    if (i === 0 && lines[i].trim() === '---') { inFrontmatter = true; continue; }
    if (inFrontmatter && lines[i].trim() === '---') { inFrontmatter = false; continue; }
    if (!inFrontmatter && lines[i].trim() === '---') count++;
  }
  return count;
}

async function main() {
  const expectedSlides = countSlides();
  console.log(`Expected slides: ${expectedSlides}`);

  console.log('Starting dev server...');
  const server = await startDevServer();

  if (TAKE_SCREENSHOTS) {
    mkdirSync(SCREENSHOT_DIR, { recursive: true });
  }

  // On NixOS: add executablePath to point at a system Chromium if the bundled binary fails.
  // e.g. chromium.launch({ executablePath: '/run/current-system/sw/bin/chromium' })
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

  const errors = [];

  for (let i = 1; i <= expectedSlides; i++) {
    const slideErrors = [];

    page.removeAllListeners('pageerror');
    page.removeAllListeners('console');
    page.on('pageerror', err => slideErrors.push(err.message));
    page.on('console', msg => { if (msg.type() === 'error') slideErrors.push(msg.text()); });

    await page.goto(`${BASE}/${i}`, { waitUntil: 'networkidle', timeout: 15000 });
    await page.waitForTimeout(2000);

    // Check for visible error message
    const hasVisibleError = await page.evaluate(() =>
      document.body.innerText.includes('An error occurred on this slide')
    );

    // Check text content length (proxy for blank slides)
    const textLen = await page.evaluate(() =>
      document.body.innerText.trim().length
    );

    if (TAKE_SCREENSHOTS) {
      await page.screenshot({
        path: `${SCREENSHOT_DIR}/slide-${String(i).padStart(2, '0')}.png`
      });
    }

    if (hasVisibleError || slideErrors.length > 0 || textLen < 30) {
      const err = {
        slide: i,
        visibleError: hasVisibleError,
        consoleErrors: slideErrors,
        textLength: textLen,
      };
      errors.push(err);
      console.log(`FAIL  Slide ${i}: ${hasVisibleError ? 'VISIBLE ERROR' : ''} ${slideErrors.length ? 'console=' + slideErrors[0].substring(0, 100) : ''} ${textLen < 30 ? 'BLANK/LOW CONTENT' : ''}`);
    } else {
      console.log(`  OK  Slide ${i}`);
    }
  }

  await browser.close();
  process.kill(-server.pid);

  console.log(`\n--- Results ---`);
  console.log(`Total: ${expectedSlides}, Passed: ${expectedSlides - errors.length}, Failed: ${errors.length}`);

  if (errors.length > 0) {
    console.log('\nFailed slides:');
    for (const e of errors) {
      console.log(`  Slide ${e.slide}: ${JSON.stringify(e)}`);
    }
    process.exit(1);
  } else {
    console.log('All slides passed.');
    process.exit(0);
  }
}

main().catch(err => {
  console.error('Fatal:', err.message);
  process.exit(1);
});
