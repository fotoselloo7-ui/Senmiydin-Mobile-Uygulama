const { spawn } = require('child_process');
const fs = require('fs');

async function run() {
  const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  const proc = spawn(chromePath, [
    '--headless=new',
    '--remote-debugging-port=9222',
    '--user-data-dir=C:\\Users\\pc\\AppData\\Local\\Temp\\chrome-shot-features-2',
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
    width: 1200, height: 900, deviceScaleFactor: 1, mobile: false
  });
  await new Promise(r => setTimeout(r, 500));

  // Capture Section 4 ("Tüm Özellikler")
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

  console.log('ozellikler box:', featBox.result.value);
  if (featBox.result.value) {
    const b = featBox.result.value;
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: b.x, y: b.y, width: b.width, height: b.height, scale: 1 }
    });
    fs.writeFileSync('scratch/features_section.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved scratch/features_section.png');
  }

  // Close-up on phone mockup
  const phoneBox = await send('Runtime.evaluate', {
    expression: `(() => {
      const el = document.querySelector('.features-mockup-container');
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { x: r.left + window.scrollX, y: r.top + window.scrollY, width: r.width, height: r.height };
    })()`,
    returnByValue: true
  });

  console.log('phone container box:', phoneBox.result.value);
  if (phoneBox.result.value) {
    const b = phoneBox.result.value;
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: Math.max(0, b.x - 20), y: Math.max(0, b.y - 20), width: b.width + 80, height: b.height + 40, scale: 1 }
    });
    fs.writeFileSync('scratch/phone_closeup.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved scratch/phone_closeup.png');
  }

  // Full page 1200
  const metrics = await send('Page.getLayoutMetrics');
  const fullHeight = Math.ceil(metrics.contentSize.height);
  const fullShot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 1200, height: fullHeight, scale: 1 }
  });
  fs.writeFileSync('docs/screenshots/web-final/home-1200.png', Buffer.from(fullShot.data, 'base64'));
  console.log('Saved docs/screenshots/web-final/home-1200.png (height: ' + fullHeight + ')');

  ws.close();
  await fetch('http://127.0.0.1:9222/json/close/' + tab.id);
  proc.kill();
  console.log('All done!');
  process.exit(0);
}

run().catch(console.error);
