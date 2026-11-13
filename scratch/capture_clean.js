const fs = require('fs');
const WebSocket = globalThis.WebSocket;

async function capture() {
  const cdpRes = await fetch('http://127.0.0.1:9222/json/new?http://127.0.0.1:8000/');
  const tab = await cdpRes.json();
  const ws = new WebSocket(tab.webSocketDebuggerUrl);

  let id = 1;
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const curId = id++;
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

  // Capture desktop 1200 full
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1200, height: 900, deviceScaleFactor: 1, mobile: false
  });
  await new Promise(r => setTimeout(r, 800));

  const doc = await send('DOM.getDocument', { depth: -1 });
  const metrics = await send('Page.getLayoutMetrics');
  const fullWidth = Math.ceil(metrics.contentSize.width);
  const fullHeight = Math.ceil(metrics.contentSize.height);

  console.log('1200px page size:', fullWidth, 'x', fullHeight);

  // Capture full page 1200px
  const fullShot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 1200, height: fullHeight, scale: 1 }
  });
  fs.writeFileSync('docs/screenshots/web-final/home-1200-clean.png', Buffer.from(fullShot.data, 'base64'));
  console.log('Saved home-1200-clean.png');

  // Capture mobile 390 full
  await send('Emulation.setDeviceMetricsOverride', {
    width: 390, height: 844, deviceScaleFactor: 2, mobile: true
  });
  await new Promise(r => setTimeout(r, 800));

  const mobMetrics = await send('Page.getLayoutMetrics');
  const mobHeight = Math.ceil(mobMetrics.contentSize.height);
  console.log('390px page size:', mobMetrics.contentSize.width, 'x', mobHeight);

  const mobShot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 390, height: mobHeight, scale: 1 }
  });
  fs.writeFileSync('docs/screenshots/web-final/home-mobile-390-clean.png', Buffer.from(mobShot.data, 'base64'));
  console.log('Saved home-mobile-390-clean.png');

  ws.close();
  await fetch('http://127.0.0.1:9222/json/close/' + tab.id);
  process.exit(0);
}

capture().catch(err => {
  console.error(err);
  process.exit(1);
});
