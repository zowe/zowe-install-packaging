const debug = require('debug')('zowe-sanity-test:utils');

function parseCookies(setCookie) {
  let cookies = {};
  for (let one of setCookie) {
    const trunks = one.split(/;/).map(trunk => trunk.trim());
    let cookie = null;
    for (let i in trunks) {
      const kv = trunks[i].split(/=/);
      if (`${i}` === '0') {
        if (kv.length === 2) {
          cookie = kv[0];
          cookies[cookie] = {
            value: kv[1],
          };
        } else {
          debug(`unknown cookie: ${trunks[i]}`);
        }
      } else if (cookie) {
        if (kv.length === 2) {
          cookies[cookie][kv[0]] = kv[1];
        } else if (kv.length === 1) {
          cookies[cookie][kv[0]] = true;
        } else {
          debug(`unknown cookie: ${trunks[i]}`);
        }
      }
    }
  }

  return cookies;
}

function getCookie(setCookie) {
  return setCookie.join(';');
}

function getCookieByKey(cookiesMap, key) {
  return `${key}=${cookiesMap[key].value}`;
}

// export constants and methods
module.exports = {
  parseCookies,
  getCookie,
  getCookieByKey
};