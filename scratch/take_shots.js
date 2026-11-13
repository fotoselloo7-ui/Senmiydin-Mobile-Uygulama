const { spawn } = require('child_process');
const fs = require('fs');

async function run() {
  // 1. Launch Chrome
  const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  const proc = spawn(chromePath, [
    '--headless=new',
    '--remote-debugging-port=9222',
    '--user-data-dir=C:\\Users\\pc\\AppData\\Local\\Temp\\chrome-cdp-node',
    '--disable-gpu',
    '--no-first-run'
  ], { stdio: 'ignore' });

  // Wait for CDP to be ready
  let version = null;
  for (let i = 0; i < 20; i++) {
    await new Promise(r => setTimeout(r, 300));
    try {
      const res = await fetch('http://127.0.0.1:9222/json/version');
      version = await res.json();
      break;
    } catch (e) {}
  }

  if (!version) {
    console.error('Failed to connect to Chrome CDP');
    proc.kill();
    process.exit(1);
  }
  console.log('Chrome CDP ready:', version.Browser);

  // 2. Open new tab using PUT
  const newTabRes = await fetch('http://127.0.0.1:9222/json/new?http://127.0.0.1:8000/', { method: 'PUT' });
  const tab = await newTabRes.json();
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
  await send('DOM.enable');

  // Set desktop 1200
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1200, height: 900, deviceScaleFactor: 1, mobile: false
  });
  await new Promise(r => setTimeout(r, 1000));

  const metrics = await send('Page.getLayoutMetrics');
  const fullHeight = Math.ceil(metrics.contentSize.height);
  console.log('Content height at 1200px:', fullHeight);

  // 1. Full Desktop screenshot
  const deskShot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 1200, height: fullHeight, scale: 1 }
  });
  fs.writeFileSync('docs/screenshots/web-final/home-1200.png', Buffer.from(deskShot.data, 'base64'));
  console.log('Saved home-1200.png');

  // 2. Mobile 390
  await send('Emulation.setDeviceMetricsOverride', {
    width: 390, height: 844, deviceScaleFactor: 2, mobile: true
  });
  await new Promise(r => setTimeout(r, 800));

  const mobMetrics = await send('Page.getLayoutMetrics');
  const mobHeight = Math.ceil(mobMetrics.contentSize.height);
  console.log('Content height at 390px:', mobHeight);

  const mobShot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 390, height: mobHeight, scale: 1 }
  });
  fs.writeFileSync('docs/screenshots/web-final/home-mobile-390.png', Buffer.from(mobShot.data, 'base64'));
  console.log('Saved home-mobile-390.png');

  // 3. Switch back to 1200 for section screenshots
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1200, height: 900, deviceScaleFactor: 1, mobile: false
  });
  await new Promise(r => setTimeout(r, 600));

  // Helper to get element box
  async function getBox(selector) {
    const evalRes = await send('Runtime.evaluate', {
      expression: `(() => {
        const el = document.querySelector('${selector}');
        if (!el) return null;
        const r = el.getBoundingClientRect();
        return { x: r.left + window.scrollX, y: r.top + window.scrollY, width: r.width, height: r.height };
      })()`,
      returnByValue: true
    });
    return evalRes.result.value;
  }

  // Hero section
  const heroBox = await getBox('.hero');
  if (heroBox) {
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: heroBox.x, y: heroBox.y, width: heroBox.width, height: heroBox.height, scale: 1 }
    });
    fs.writeFileSync('docs/screenshots/web-final/hero-slider-1.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved hero-slider-1.png');
  }

  // Dual showcase (Radar & Polaroids)
  const dualBox = await getBox('.section-dual-showcase');
  if (dualBox) {
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: dualBox.x, y: dualBox.y, width: dualBox.width, height: dualBox.height, scale: 1 }
    });
    fs.writeFileSync('docs/screenshots/web-final/city-stories.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved city-stories.png');
  }

  // Security section
  const secBox = await getBox('.section-security');
  if (secBox) {
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: secBox.x, y: secBox.y, width: secBox.width, height: secBox.height, scale: 1 }
    });
    fs.writeFileSync('docs/screenshots/web-final/security-section.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved security-section.png');
  }

  // Footer
  const footBox = await getBox('.site-footer');
  if (footBox) {
    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: footBox.x, y: footBox.y, width: footBox.width, height: footBox.height, scale: 1 }
    });
    fs.writeFileSync('docs/screenshots/web-final/footer.png', Buffer.from(shot.data, 'base64'));
    console.log('Saved footer.png');
  }

  ws.close();
  await fetch('http://127.0.0.1:9222/json/close/' + tab.id);
  proc.kill();
  console.log('All screenshots completed successfully!');
  process.exit(0);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
