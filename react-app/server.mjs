import express from 'express';
import os from 'node:os';
import path from 'node:path';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const app = express();
const directory = path.dirname(fileURLToPath(import.meta.url));
const distDirectory = path.join(directory, 'dist');
const serverName = os.hostname().toUpperCase();

// Add the responding server's name to HTML at runtime.
// The built JavaScript and CSS stay identical on both servers.
const nameJSON = JSON.stringify(serverName).replace(/</g, '\\u003c');

const html = readFileSync(
  path.join(distDirectory, 'index.html'),
  'utf8'
).replace(
  '<head>',
  `<head><script>window.__SERVER_NAME__ = ${nameJSON};</script>`
);

app.disable('x-powered-by');

app.use((req, res, next) => {
  res.setHeader('X-Served-By', serverName);
  res.setHeader('Cache-Control', 'no-store');
  next();
});

app.get('/health', (req, res) => {
  res.status(200).type('text/plain').send(`OK ${serverName}\n`);
});

app.get(['/', '/index.html'], (req, res) => {
  res.type('html').send(html);
});

app.use(express.static(distDirectory, { index: false }));

app.listen(3000, '0.0.0.0', () => {
  console.log(`${serverName}: serving React on port 3000`);
});