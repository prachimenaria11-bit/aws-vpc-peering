const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const htmlPath = path.resolve(__dirname, 'report_template.html');
const pdfPath = path.resolve(__dirname, 'Prachi_EWB_VPC_Peering.pdf');

// Paths to check for Edge browser executable
const edgePaths = [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
];

let browserPath = edgePaths.find(p => fs.existsSync(p));

if (!browserPath) {
  console.error("[-] No Chromium-based browser (Edge/Chrome) found to generate PDF.");
  process.exit(1);
}

console.log(`[+] Using browser: ${browserPath}`);
console.log(`[+] Converting: ${htmlPath} -> ${pdfPath}`);

const cmd = `"${browserPath}" --headless --disable-gpu --run-all-compositor-stages-before-draw --print-to-pdf="${pdfPath}" "${htmlPath}"`;

try {
  execSync(cmd, { stdio: 'inherit' });
  if (fs.existsSync(pdfPath)) {
    const stats = fs.statSync(pdfPath);
    console.log(`[+] SUCCESS! Generated: ${pdfPath} (${stats.size} bytes)`);
  } else {
    console.error("[-] PDF generation failed.");
  }
} catch (err) {
  console.error("[-] Error generating PDF:", err.message);
}
