const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');
const root = path.resolve(__dirname, '../../[core]/esx_identity/web/dist');
const output = process.argv[2];
async function fill(page) {
  await page.locator('#firstname').fill('Santiago');
  await page.locator('#lastname').fill('Rivera');
  await page.locator('#dob').fill('1990-01-01');
  await page.locator('label.gender-option').filter({ has: page.locator('input[value="m"]') }).click();
  await page.locator('#height').fill('180');
  await page.locator('#nationality').selectOption('Spain');
  await page.waitForFunction(() => document.querySelector('#nationality').getAttribute('aria-invalid') === 'false');
}
const server = http.createServer((request, response) => {
  const url = new URL(request.url, 'http://localhost');
  const file = path.resolve(root, `.${decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname)}`);
  if (!file.startsWith(root + path.sep)) { response.writeHead(403); response.end(); return; }
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml' };
  try { response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream'); response.end(fs.readFileSync(file)); }
  catch { response.writeHead(404); response.end(); }
});
(async () => {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const errors = [];
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    page.on('pageerror', (error) => errors.push(error.message));
    const languages = process.env.BROWSER_ONLY_MOBILE ? [] : ['en', 'es', 'fr', 'de', 'pt', 'it', 'nl', 'pl'];
    for (const lang of languages) {
      await page.goto(`${base}/?preview=1&lang=${lang}`);
      await page.locator('#nationality').waitFor();
      assert.equal(await page.locator('#nationality option').count(), 197);
      await page.locator('#submit').click();
      assert((await page.locator('#nationality-error').innerText()).length > 0);
      await fill(page);
      assert.equal(await page.locator('#nationality').inputValue(), 'Spain');
      if (lang === 'es' && output) await page.screenshot({ path: path.join(output, 'identity-nationality-desktop.png'), fullPage: true });
      await page.locator('#submit').click();
      assert(await page.locator('#submit').isDisabled());
    }
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(`${base}/?preview=1&lang=es`);
    await fill(page);
    if (output) await page.screenshot({ path: path.join(output, 'identity-nationality-mobile.png'), fullPage: true });
    const overflow = await page.evaluate(() => ({ width: innerWidth, scroll: document.documentElement.scrollWidth,
      elements: [...document.querySelectorAll('body *')].filter((element) => element.getBoundingClientRect().right > innerWidth + 1).map((element) => ({ tag: element.tagName, className: element.className, width: element.getBoundingClientRect().width })).slice(0,15) }));
    assert(overflow.scroll <= overflow.width, JSON.stringify(overflow));
    await page.locator('#submit').click();
    assert(await page.locator('#submit').isDisabled());
    let payload;
    await page.addInitScript(() => { window.GetParentResourceName = () => 'esx_identity'; });
    await page.route('http://esx_identity/**', (route) => {
      if (route.request().url().endsWith('/register')) payload = route.request().postDataJSON();
      return route.fulfill({ json: { ok: true } });
    });
    await page.goto(base);
    await page.evaluate(() => window.postMessage({ type: 'enableui', enable: true, settings: { locale: 'es' } }, '*'));
    await fill(page);
    await page.locator('#submit').click();
    await page.waitForFunction(() => !document.querySelector('#submit')?.disabled);
    assert.deepEqual(payload, { firstname: 'Santiago', lastname: 'Rivera', dateofbirth: '01/01/1990', sex: 'm', height: 180, nationality: 'Spain' });
    assert.deepEqual(errors, []);
    console.log(`PASS browser: ${languages.length} desktop languages, required country, 196 countries, mobile layout and actual NUI payload.`);
  } finally { await browser.close(); }
})().catch((error) => { console.error(error); process.exitCode = 1; }).finally(() => server.close());
