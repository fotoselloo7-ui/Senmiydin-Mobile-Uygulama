const { spawn } = require('child_process');

async function audit() {
  const proc = spawn('C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', [
    '--headless=new',
    '--remote-debugging-port=9222',
    '--user-data-dir=C:\\Users\\pc\\AppData\\Local\\Temp\\chrome-cdp-overflow',
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

  const viewports = [1920, 1440, 1200, 1024, 768, 430, 390, 360];
  let allClean = true;

  for (const w of viewports) {
    await send('Emulation.setDeviceMetricsOverride', {
      width: w, height: 900, deviceScaleFactor: 1, mobile: w < 768
    });
    await new Promise(r => setTimeout(r, 300));

    const res = await send('Runtime.evaluate', {
      expression: `(() => {
        const sw = document.documentElement.scrollWidth;
        const iw = window.innerWidth;
        const diff = sw - iw;
        return { sw, iw, diff, hasOverflow: diff > 1 };
      })()`,
      returnByValue: true
    });

    const info = res.result.value;
    console.log(`Viewport ${w}px -> scrollWidth: ${info.sw}, innerWidth: ${info.iw}, diff: ${info.diff}, overflow: ${info.hasOverflow}`);
    if (info.hasOverflow) allClean = false;
  }

  ws.close();
  await fetch('http://127.0.0.1:9222/json/close/' + tab.id);
  proc.kill();

  if (allClean) {
    console.log('✅ ALL VIEWPORTS PERFECT! 0 OVERFLOW!');
    process.exit(0);
  } else {
    console.error('❌ OVERFLOW DETECTED!');
    process.exit(1);
  }
}

audit().catch(e => {
  console.error(e);
  process.exit(1);
});

