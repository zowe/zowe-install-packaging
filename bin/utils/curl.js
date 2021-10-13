/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2021
 */

/**
 * This script is a simplified version of Linux curl command.
 *
 * It supports these parameters:
 *
 * -k: skip https certificate check
 * -X: http method
 * -H: http header
 * -d: post/put method body
 * -u: username:password
 * -o, --output <file> Write to file instead of stdout
 * -v: verbose mode
 * -J: prettify JSON response to make it more readable
 * --response-type 'status'/'body'/'header': outputs one of three following information (body is default value)
 *
 * Usage Examples:
 *
 * - make GET request
 * node curl.js https://your-zos-host-name/zosmf/info -k -v -H 'X-CSRF-ZOSMF-HEADER: *' -J
 * - make PUT request
 * node curl.js https://your-zos-host-name/zosmf/restconsoles/consoles/defcn -k -v -H 'X-CSRF-ZOSMF-HEADER: *' -J -X PUT -H 'Content-type: application/json' -d '{"cmd":"D TS"}' -u user:pass
 */

const { URL } = require('url');
const fs = require('fs');

const exitWithError = (code, message) => {
  process.stderr.write(message);
  process.exit(code);
};

// suppress Warning: Setting the NODE_TLS_REJECT_UNAUTHORIZED environment variable to '0' makes TLS connections and HTTPS requests insecure by disabling certificate verification.
const originalEmitWarning = process.emitWarning;
process.emitWarning = (warning, opts) => {
  if (warning && `${warning}`.indexOf('NODE_TLS_REJECT_UNAUTHORIZED') > -1) {
    // node will only emit the warning once
    // https://github.com/nodejs/node/blob/82f89ec8c1554964f5029fab1cf0f4fad1fa55a8/lib/_tls_wrap.js#L1378-L1384
    process.emitWarning = originalEmitWarning;
    return
  }
  return originalEmitWarning.call(process, warning, opts);
};

// variables
let verbose = false;
const params = {
  method: 'GET',
  rejectUnauthorized: true,
  headers: {},
  url: null,
  auth: null,
  data: null,
  output: null,
  key: null,
  cert: null,
  cacert: null,
};
let prettifyJson = false;
let responseType = '';

// parse arguments
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  if (args[i].match(/^https?:\/\//)) {
    params.url = new URL(args[i]);
  } else if (args[i] === '-H') { // extra header
    i++;
    if (args[i]) {
      const colonIndex = args[i].indexOf(':');
      if (colonIndex > -1) {
        const headerKey = args[i].substr(0, colonIndex);
        const headerVal = args[i].substr(colonIndex + 1).trim();
        params.headers[headerKey] = headerVal;
      }
    }
  } else if (args[i] === '-X') { // method
    i++;
    params.method = args[i];
  } else if (args[i] === '-u') { // auth
    i++;
    params.auth = args[i];
  } else if (args[i] === '-d') {
    i++;
    params.data = args[i];
  } else if (args[i] === '-k') {
    params.rejectUnauthorized = false;
    process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0;
  } else if (args[i] === '--cacert') {
    i++;
    params.cacert = args[i];
  } else if (args[i] === '-E' || args[i] === '--cert') {
    i++;
    params.cert = args[i];
  } else if (args[i] === '--key') {
    i++;
    params.key = args[i];
  } else if (args[i] === '-v') {
    verbose = true;
  } else if (args[i] === '-J') {
    prettifyJson = true;
  } else if (args[i] === '-o' || args[i] === '--output') {
    i++;
    params.output = args[i];
  } else if (args[i] == '--response-type'){
    i++;
    responseType = args[i];
    if (responseType != 'body' && responseType != 'header' && responseType != 'status') {
      exitWithError(1, `Error: --response-type| can only take one of the three following values: header, body, status\n`);
    }
  } else {
    exitWithError(1, `Error: unknown parameter ${args[i]}\n`);
  }
}

// prepare options
const options = {
  hostname: params.url.hostname,
  port: params.url.port,
  path: params.url.pathname + (params.url.search || ''),
  method: params.method,
  headers: params.headers,
  key: params.key ? fs.readFileSync(params.key) : null,
  cert: params.cert ? fs.readFileSync(params.cert) : null,
  ca: params.cacert ? [ fs.readFileSync(params.cacert) ] : null,
};
if (params.url.protocol === 'https') {
  options.rejectUnauthorized = params.rejectUnauthorized;
}
if (params.auth) {
  options.auth = params.auth;
}

if (verbose) {
  process.stdout.write(`> ${params.method} ${params.url}\n`);
  process.stdout.write(`> Headers:\n`);
  for (const k in options.headers) {
    process.stdout.write(`> - ${k}: ${options.headers[k]}\n`);
  }
  if (options.ca) {
    process.stdout.write(`> CA(s):\n${options.ca}\n`);
  }
  if (options.cert) {
    process.stdout.write(`> Cert:\n${options.cert}\n`);
  }
  if (options.key) {
    process.stdout.write(`> Key:\n${options.key}\n`);
  }
  if (params.data) {
    process.stdout.write(`> Body:\n${params.data}\n`);
  }
  process.stdout.write(`\n`);
}

// make request
const HTTP = params.url.protocol === 'https:' ? require('https') : require('http');
let resBody = [];
const req = HTTP.request(options, (res) => {
  if (responseType == 'header') {
    for (const k in res.headers) {
      process.stdout.write(`${k}: ${res.headers[k]}\n`);
    }
  } else if (responseType == 'status') {
    process.stdout.write(`${res.statusCode}\n`)
  } else {
    if (verbose) {
      // console.log(res);
      process.stdout.write(`< Status: ${res.statusCode}\n`);
      process.stdout.write(`< Headers:\n`);
      for (const k in res.headers) {
        process.stdout.write(`< - ${k}: ${res.headers[k]}\n`);
      }
      process.stdout.write(`< Body:\n`);
    }
    // res.setEncoding('utf8');
    res.on('data', (chunk) => {
      resBody.push(chunk);
    });
    res.on('end', () => {
      if (params.output) {
        fs.writeFileSync(params.output, Buffer.concat(resBody));
      } else {
        if (prettifyJson) {
          // sometimes response doesn't have this header
          // && res.headers['content-type'] === 'application/json'
          process.stdout.write(JSON.stringify(JSON.parse(resBody.join('')), null, 2));
        } else {
          process.stdout.write(resBody.join(''));
        }
        process.stdout.write('\n');
      }
    });
  }
});

// handling errors
req.on('error', (e) => {
  const msg = `Request failed (${e.code}): ${e.message}\n` +
    (verbose ? e.stack + '\n' : '');
  exitWithError(2, msg);
});

// write data to request body
if (params.data) {
  req.write(params.data);
}

req.end();
