const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const INVITE_CODE = process.env.INVITE_CODE || 'SOLSTICE';
const OUTPUT_DIR = path.join(__dirname, '..', 'docs', 'screenshots');
const VIEWPORT = { width: 1024, height: 1400, deviceScaleFactor: 1 };

const GROUPS = {
  gate: ['gate'],
  pages: ['home', 'events', 'travel', 'stay', 'explore', 'attire', 'faq', 'rsvp'],
  rsvp: ['rsvp-lookup', 'rsvp-guests', 'rsvp-events'],
  hotel: ['hotel-booking'],
  admin: ['admin-dashboard', 'admin-invites', 'admin-guests', 'admin-children', 'admin-events', 'admin-seating', 'admin-seating-chart', 'admin-emails', 'admin-hotel-bookings', 'admin-import'],
};

const STATIC_PAGES = [
  { name: 'home', path: '/', description: 'Home page (after auth)' },
  { name: 'events', path: '/events', description: 'Weekend events' },
  { name: 'travel', path: '/travel', description: 'Travel information' },
  { name: 'stay', path: '/stay', description: 'Accommodations' },
  { name: 'explore', path: '/explore', description: 'Things to do' },
  { name: 'attire', path: '/attire', description: 'Dress code' },
  { name: 'faq', path: '/faq', description: 'FAQ' },
  { name: 'rsvp', path: '/rsvp', description: 'RSVP lookup' },
];

// --- helpers ---

async function authenticate(page) {
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle2' });
  await page.type('input[placeholder="Invite code"]', INVITE_CODE);
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForNavigation({ waitUntil: 'networkidle2' });
}

async function enableAllPages(page) {
  await page.evaluate(async () => {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    await fetch('/dev/toggle_pages', {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrfToken, 'Content-Type': 'application/x-www-form-urlencoded' },
      credentials: 'same-origin',
    });
  });
}

async function screenshot(page, name) {
  const file = path.join(OUTPUT_DIR, `${name}.png`);

  // Hide the "Show all pages" dev toggle before capturing
  await page.evaluate(() => {
    const el = document.getElementById('dev-toggle');
    if (el) el.style.display = 'none';
  });

  // Take full viewport screenshot
  await page.screenshot({ path: file, fullPage: false });

  // Use ImageMagick to trim bottom whitespace:
  // 1. Get the background color from the bottom-right pixel
  // 2. Trim rows from the bottom that match it (with fuzz for anti-aliasing)
  // 3. Keep full width — only trim vertically
  try {
    // Get original dimensions
    const info = execSync(`magick identify -format "%w %h" "${file}"`).toString().trim();
    const [origW, origH] = info.split(' ').map(Number);

    // Find the trimmed bounding box — background is #F8F7F9
    const trimInfo = execSync(
      `magick "${file}" -bordercolor "srgb(248,247,249)" -border 1 -fuzz 3% -trim -format "%X %Y %w %h" info:`
    ).toString().trim();
    const [trimX, trimY, trimW, trimH] = trimInfo.split(' ').map(Number);

    // Only crop if we'd save at least 50px of whitespace, and keep full width
    const padding = 24;
    const croppedH = Math.min(origH, trimH + padding);
    if (origH - croppedH > 50) {
      execSync(`magick "${file}" -crop ${origW}x${croppedH}+0+0 +repage "${file}"`);
      console.log(`  saved ${name}.png (trimmed ${origH} → ${croppedH}px)`);
    } else {
      console.log(`  saved ${name}.png (${origH}px, no trim needed)`);
    }
  } catch (e) {
    // If trimming fails, keep the original
    console.log(`  saved ${name}.png (trim skipped: ${e.message})`);
  }
}

// --- capture functions ---

async function captureGate(page) {
  console.log('Capturing gate...');
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle2' });
  await screenshot(page, 'gate');
}

async function capturePages(page, names) {
  const pages = names
    ? STATIC_PAGES.filter(p => names.includes(p.name))
    : STATIC_PAGES;

  for (const { name, path: pagePath, description } of pages) {
    console.log(`Capturing ${description} (${pagePath})...`);
    await page.goto(`${BASE_URL}${pagePath}`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 1000));
    await screenshot(page, name);
  }
}

async function captureRsvpFlow(page) {
  console.log('\n--- RSVP Flow ---');

  // Lookup with email filled in
  console.log('Capturing RSVP lookup...');
  await page.goto(`${BASE_URL}/rsvp`, { waitUntil: 'networkidle2' });
  await page.type('input[type="email"], input[name="query"]', 'taylor@example.com');
  await screenshot(page, 'rsvp-lookup');

  // Submit lookup → guest details
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForNavigation({ waitUntil: 'networkidle2' });
  await new Promise(r => setTimeout(r, 500));
  console.log('Capturing RSVP guest details...');
  await screenshot(page, 'rsvp-guests');

  // Submit form → events step (toggle is already on "Can attend")
  await page.evaluate(() => {
    document.querySelector('input[type="submit"], button[type="submit"]').click();
  });
  await page.waitForNavigation({ waitUntil: 'networkidle2' });
  await new Promise(r => setTimeout(r, 500));
  console.log('Capturing RSVP events...');
  await screenshot(page, 'rsvp-events');
}

const ADMIN_USER = process.env.ADMIN_USER || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'password';

const ADMIN_PAGES = [
  { name: 'admin-dashboard', path: '/admin', description: 'Admin dashboard' },
  { name: 'admin-invites', path: '/admin/invites', description: 'Admin invites' },
  { name: 'admin-guests', path: '/admin/guests', description: 'Admin guests' },
  { name: 'admin-children', path: '/admin/children', description: 'Admin children dashboard' },
  { name: 'admin-events', path: '/admin/events', description: 'Admin events' },
  { name: 'admin-seating', path: '/admin/seating', description: 'Admin seating (per event)' },
  { name: 'admin-emails', path: '/admin/emails', description: 'Admin emails / communications' },
  { name: 'admin-hotel-bookings', path: '/admin/hotel_bookings', description: 'Admin hotel bookings' },
  { name: 'admin-import', path: '/admin/import', description: 'Admin CSV import' },
];

async function captureAdmin(page) {
  console.log('\n--- Admin ---');

  // Authenticate via HTTP basic auth using the extraHTTPHeaders approach
  const authHeader = 'Basic ' + Buffer.from(`${ADMIN_USER}:${ADMIN_PASSWORD}`).toString('base64');
  await page.setExtraHTTPHeaders({ 'Authorization': authHeader });

  for (const { name, path: adminPath, description } of ADMIN_PAGES) {
    console.log(`Capturing ${description} (${adminPath})...`);
    await page.goto(`${BASE_URL}${adminPath}`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 500));
    await screenshot(page, name);
  }

  // Clear the auth header
  await page.setExtraHTTPHeaders({});
}

async function captureSeatingChart(page) {
  console.log('\n--- Seating floorplan ---');
  const authHeader = 'Basic ' + Buffer.from(`${ADMIN_USER}:${ADMIN_PASSWORD}`).toString('base64');
  await page.setExtraHTTPHeaders({ 'Authorization': authHeader });

  // Auto-accept Turbo confirmation dialogs (Randomize/Clear prompt before acting).
  const dialogHandler = async (dialog) => { await dialog.accept(); };
  page.on('dialog', dialogHandler);

  await page.goto(`${BASE_URL}/admin/seating`, { waitUntil: 'networkidle2' });
  const card = await page.$('a.card');
  if (!card) {
    console.log('  no events have seating tables — skipping floorplan');
    page.off('dialog', dialogHandler);
    await page.setExtraHTTPHeaders({});
    return;
  }

  console.log('Opening floorplan and seating guests...');
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle2' }),
    card.click(),
  ]);

  // Click "Randomize" to auto-seat attending guests so the chart isn't empty.
  const randomize = await page.evaluateHandle(() =>
    [...document.querySelectorAll('input[type=submit], button')]
      .find(b => /randomize/i.test(b.value || b.textContent || ''))
  );
  const randomizeEl = randomize.asElement();
  if (randomizeEl) {
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle2' }).catch(() => {}),
      randomizeEl.click(),
    ]);
    await new Promise(r => setTimeout(r, 800));
  }

  await screenshot(page, 'admin-seating-chart');
  page.off('dialog', dialogHandler);
  await page.setExtraHTTPHeaders({});
}

async function captureHotelBooking(page) {
  console.log('\n--- Hotel Booking ---');
  console.log('Capturing hotel booking page...');
  await page.goto(`${BASE_URL}/hotel_bookings/new`, { waitUntil: 'networkidle2' });
  await new Promise(r => setTimeout(r, 1000));
  await screenshot(page, 'hotel-booking');
}

// --- main ---

async function run() {
  const args = process.argv.slice(2);
  const requested = args.length ? args : ['gate', 'pages', 'rsvp'];

  // Expand group names (e.g. "pages" → all static page names)
  const targets = new Set();
  for (const arg of requested) {
    if (GROUPS[arg]) {
      GROUPS[arg].forEach(t => targets.add(t));
    } else {
      targets.add(arg);
    }
  }

  const needsAuth = [...targets].some(t => t !== 'gate' && !t.startsWith('admin-'));
  const needsPages = STATIC_PAGES.some(p => targets.has(p.name));
  const needsRsvp = ['rsvp-lookup', 'rsvp-guests', 'rsvp-events'].some(t => targets.has(t));
  const needsHotel = targets.has('hotel-booking');
  const needsAdmin = ADMIN_PAGES.some(p => targets.has(p.name));
  const needsSeatingChart = targets.has('admin-seating-chart');

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);

  if (targets.has('gate')) {
    await captureGate(page);
  }

  if (needsAuth) {
    console.log('Authenticating...');
    await authenticate(page);
    console.log('Enabling all pages...');
    await enableAllPages(page);
  }

  if (needsPages) {
    const pageNames = STATIC_PAGES.map(p => p.name).filter(n => targets.has(n));
    await capturePages(page, pageNames);
  }

  if (needsRsvp) {
    await captureRsvpFlow(page);
  }

  if (needsHotel) {
    await captureHotelBooking(page);
  }

  if (needsAdmin) {
    await captureAdmin(page);
  }

  if (needsSeatingChart) {
    await captureSeatingChart(page);
  }

  await browser.close();
  console.log('\nDone!');
}

run().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
