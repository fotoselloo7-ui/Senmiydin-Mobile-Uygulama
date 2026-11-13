const fs = require('fs');

function getJpegDimensions(path) {
  const b = fs.readFileSync(path);
  let i = 0;
  while (i < b.length) {
    if (b[i] === 0xFF && (b[i+1] === 0xC0 || b[i+1] === 0xC2)) {
      const h = b.readUInt16BE(i + 5);
      const w = b.readUInt16BE(i + 7);
      return { w, h };
    }
    i++;
  }
}

const refPath = 'C:/Users/pc/.gemini/antigravity/brain/58760531-9a94-438e-bfa9-8e742fbc03fa/.user_uploaded/media_1794384841290_a7161b44.jpg';
console.log('REF:', getJpegDimensions(refPath));

