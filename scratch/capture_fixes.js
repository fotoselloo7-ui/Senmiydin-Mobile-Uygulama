const { spawn } = require('child_process');
const fs = require('fs');

async function run() {
  const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  const proc = spawn(chromePath, [
    '--headless=new',
    '--remote-debugging-port=9222',
    '--user-data-dir=C:\\Users\\pc\\AppData\\Local\\Temp\\chrome-shot-fixes',
    '--disable-gpu',
    '--no-first-run'
  ], { stdio: 'ignore' });

  for (let i = 0; i < 20; i++) {
    await new Promise(r => setTimeout(r, 200));
    try {
      const res = await fetch('http://127.0.0.1:9222/json/version');
      if (res.ok) break;
    } catch (e) {}
  }

  const tabRes = await fetch('http://127.0.0.1:9222/json/new', { method: 'PUT' });
  const tab = await tabRes.json();
  const ws = new WebSocket(tab.webSocketDebuggerUrl);

  let reqId = 1;
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const curId = reqId++;
    const handler = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.id === curId) {
        ws.removeEventListener('message', handler);
        if (msg.error) reject(msg.error);
        else resolve(msg.result);
      }
    };
    ws.addEventListener('message', handler);
    ws.send(JSON.stringify({ id: curId, method, params }));
  });

  await new Promise(r => ws.addEventListener('open', r, { once: true }));
  await send('Page.enable');
  await send('Page.navigate', { url: 'http://127.0.0.1:8000/' });
  await new Promise(r => setTimeout(r, 1200));

  await send('Emulation.setDeviceMetricsOverride', {
    width: 1200, height: 900, deviceScaleFactor: 2, mobile: false
  });
  await new Promise(r => setTimeout(r, 600));

  async function getBox(selector) {
    const evalRes = await send('Runtime.evaluate', {
      expression: `(() => {
        const el = document.querySelector('${selector}');
        if (!el) return null;
        el.scrollIntoView();
        const r = el.getBoundingClientRect();
        return { x: r.left + window.scrollX, y: r.top + window.scrollY, width: r.width, height: r.height };
      })()`,
      returnByValue: true
    });
    return evalRes.result.value;
  }

  // 1. Store buttons close-up (Hero stores)
  const storesBox = await getBox('.hero-cta-group');
  if (storesBox) {
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: Math.max(0, storesBox.x - 10), y: Math.max(0, storesBox.y - 10), width: storesBox.width + 20, height: storesBox.height + 20, scale: 1 }
    });
    fs.writeFileSync('scratch/fix1_stores.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved scratch/fix1_stores.png');
  }

  // 2. Hero photo card close-up (No arrows, auto-sliding quote card)
  const heroCardBox = await getBox('.hero-photo-card');
  if (heroCardBox) {
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: Math.max(0, heroCardBox.x - 10), y: Math.max(0, heroCardBox.y - 10), width: heroCardBox.width + 20, height: heroCardBox.height + 20, scale: 1 }
    });
    fs.writeFileSync('scratch/fix2_hero_no_arrows.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved scratch/fix2_hero_no_arrows.png');
  }

  // 3. Section 2 ("SENMİYDİN NEDİR?") close-up (Wider columns, cards stretched across)
  const sec2Box = await getBox('.section-about');
  if (sec2Box) {
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: sec2Box.x, y: sec2Box.y, width: sec2Box.width, height: sec2Box.height, scale: 1 }
    });
    fs.writeFileSync('scratch/fix3_section2_wide.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved scratch/fix3_section2_wide.png');
  }

  // 4. Update home-1200.png full page
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1200, height: 900, deviceScaleFactor: 1, mobile: false
  });
  await new Promise(r => setTimeout(r, 400));
  const metrics = await send('Page.getLayoutMetrics');
  const fullHeight = Math.ceil(metrics.contentSize.height);
  const fullShot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 1200, height: fullHeight, scale: 1 }
  });
  fs.writeFileSync('docs/screenshots/web-final/home-1200.png', Buffer.from(fullShot.data, 'base64'));
  console.log('Saved docs/screenshots/web-final/home-1200.png');

  ws.close();
  await fetch('http://127.0.0.1:9222/json/close/' + tab.id);
  proc.kill();
  console.log('All screenshots ready!');
  process.exit(0);
}

run().catch(console.error);

