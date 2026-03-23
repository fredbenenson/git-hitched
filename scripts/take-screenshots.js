const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const INVITE_CODE = process.env.INVITE_CODE || 'SOLSTICE';
const OUTPUT_DIR = path.join(__dirname, '..', 'docs', 'screenshots');
const VIEWPORT = { width: 1024, height: 1400, deviceScaleFactor: 1 };

const GROUPS = {
  gate: ['gate'],
  pages: ['home', 'events', 'travel', 'stay', 'explore', 'attire', 'faq', 'rsvp'],
  rsvp: ['rsvp-lookup', 'rsvp-guests', 'rsvp-events'],
  hotel: ['hotel-booking'],
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
  await page.screenshot({ path: file, fullPage: false });
  console.log(`  saved ${name}.png`);
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

  const needsAuth = [...targets].some(t => t !== 'gate');
  const needsPages = STATIC_PAGES.some(p => targets.has(p.name));
  const needsRsvp = ['rsvp-lookup', 'rsvp-guests', 'rsvp-events'].some(t => targets.has(t));
  const needsHotel = targets.has('hotel-booking');

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

  await browser.close();
  console.log('\nDone!');
}

run().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
