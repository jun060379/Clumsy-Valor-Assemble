const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 900, height: 900 } });
  p.on('console', m => { if (m.type() === 'error' && !m.text().includes('ERR_FAILED')) console.log('console', m.text().slice(0, 600)); });
  p.on('pageerror', e => console.log('err', e.message));
  await p.route('**/three.min.js', r => r.fulfill({ path: process.argv[3], contentType: 'application/javascript' }));
  await p.route('**/fonts.googleapis.com/**', r => r.abort());
  await p.goto('file://' + process.argv[2]);
  await p.waitForTimeout(2500);
  for (const s of process.argv[4].split(',')) {
    const [bm, h] = s.split(':');
    await p.click("#b-2"); await p.click(bm === "M" ? "#g-2" : (bm === "B" || bm === "N") ? "#g-1" : "#g-0"); if (bm === "L") await p.click("#m-light"); else await p.click("#m-game");
    await p.evaluate((n) => { NORMOUT = n; }, bm === "N");
    await p.$eval('#hour', (el, v) => { el.value = v; el.dispatchEvent(new Event('input')); }, h);
    await p.waitForTimeout(500);
    const data = await p.$eval('#cv', c => c.toDataURL());
    require('fs').writeFileSync(process.argv[2].replace('.html', `_b${bm}_${h}.png`), Buffer.from(data.split(',')[1], 'base64'));
  }
  await b.close();
})();
