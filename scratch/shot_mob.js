const { spawn } = require('child_process');
const fs = require('fs');

async function run() {
  const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  const proc = spawn(chromePath, [
    '--headless=new',
    '--remote-debugging-port=9222',
    '--user-data-dir=C:\\Users\\pc\\AppData\\Local\\Temp\\chrome-shot-mob',
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
    width: 390, height: 844, deviceScaleFactor: 2, mobile: true
  });
  await new Promise(r => setTimeout(r, 600));

  const featBox = await send('Runtime.evaluate', {
    expression: `(() => {
      const el = document.querySelector('#ozellikler');
      if (!el) return null;
      el.scrollIntoView();
      const r = el.getBoundingClientRect();
      return { x: r.left + window.scrollX, y: r.top + window.scrollY, width: r.width, height: r.height };
    })()`,
    returnByValue: true
  });

  if (featBox.result.value) {
    const b = featBox.result.value;
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: b.x, y: b.y, width: b.width, height: b.height, scale: 1 }
    });
    fs.writeFileSync('scratch/features_mobile.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved scratch/features_mobile.png');
  }

  // Update home-mobile-390.png
  const metrics = await send('Page.getLayoutMetrics');
  const fullHeight = Math.ceil(metrics.contentSize.height);
  const mobShot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 390, height: fullHeight, scale: 1 }
  });
  fs.writeFileSync('docs/screenshots/web-final/home-mobile-390.png', Buffer.from(mobShot.data, 'base64'));
  console.log('Saved docs/screenshots/web-final/home-mobile-390.png');

  ws.close();
  await fetch('http://127.0.0.1:9222/json/close/' + tab.id);
  proc.kill();
  process.exit(0);
}

run().catch(console.error);

