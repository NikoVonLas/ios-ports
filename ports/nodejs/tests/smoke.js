'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

assert.equal(process.arch, 'arm64');
assert.equal(process.platform, 'darwin');
assert.equal(crypto.createHash('sha256').update('ios').digest('hex').length, 64);

const temporaryFile = path.join(os.tmpdir(), `node-ios24-${process.pid}.txt`);
fs.writeFileSync(temporaryFile, 'ok');
assert.equal(fs.readFileSync(temporaryFile, 'utf8'), 'ok');
fs.unlinkSync(temporaryFile);

const server = http.createServer((_request, response) => response.end('ok'));
server.listen(0, '127.0.0.1', () => {
  const address = server.address();
  http.get(`http://127.0.0.1:${address.port}`, (response) => {
    let body = '';
    response.setEncoding('utf8');
    response.on('data', (chunk) => {
      body += chunk;
    });
    response.on('end', () => {
      assert.equal(body, 'ok');
      server.close(() => console.log('node-ios24 smoke test: ok'));
    });
  });
});
