// Reçoit la fenêtre Sortie envoyée par le plugin AutoPlayTest et l'écrit dans out/studio-output.log.
// N'écoute que sur 127.0.0.1 : rien n'est accessible depuis l'extérieur du PC.
const http = require('http');
const fs = require('fs');
const path = require('path');

const outDir = path.join(__dirname, 'out');
fs.mkdirSync(outDir, { recursive: true });
const logFile = path.join(outDir, 'studio-output.log');

http.createServer((req, res) => {
  let body = '';
  req.on('data', (chunk) => { body += chunk; });
  req.on('end', () => {
    if (req.method === 'POST') {
      fs.appendFileSync(logFile, body.endsWith('\n') ? body : body + '\n');
    }
    res.end('ok');
  });
}).listen(34999, '127.0.0.1', () => console.log('logserver : 127.0.0.1:34999'));
