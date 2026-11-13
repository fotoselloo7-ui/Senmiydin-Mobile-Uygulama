const { spawn } = require('child_process');
const fs = require('fs');

async function run() {
  const html = `<!DOCTYPE html>
<html>
<body style="margin:0; background:#fff;">
  <img src="file:///C:/Users/pc/.gemini/antigravity/brain/58760531-9a94-438e-bfa9-8e742fbc03fa/.user_uploaded/media_1794384841290_a7161b44.jpg" style="position:absolute; top:-400px; left:0; width:512px;">
</body>
</html>`;
  fs.writeFileSync('scratch/crop.html', html);

  const proc = spawn('C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', [
    '--headless=new',
    '--remote-debugging-port=9222',
    '--user-data-dir=C:\\Users\\pc\\AppData\\Local\\Temp\\chrome-crop',
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

  const tabRes = await fetch('http://127.0.0.1:9222/json/new?file:///C:/Projeler/Senmiydin%20Mobile%20Uygulama/scratch/crop.html', { method: 'PUT' });
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
  await send('Emulation.setDeviceMetricsOverride', { width: 512, height: 350, deviceScaleFactor: 2, mobile: false });
  await new Promise(r => setTimeout(r, 500));

  const shot = await send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync('scratch/ref_phone_crop.png', Buffer.from(shot.data, 'base64'));
  console.log('Saved ref_phone_crop.png');

  ws.close();
  await fetch('http://127.0.0.1:9222/json/close/' + tab.id);
  proc.kill();
}

run().catch(console.error);
