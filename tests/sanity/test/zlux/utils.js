const debug = require('debug')('zowe-sanity-test:zlux:utils');
const expect = require('chai').expect;
const _ = require('lodash');
const { getCookie } = require('../cookie-helper');

const APIML_AUTH_COOKIE = 'apimlAuthenticationToken';
async function zluxAuth(REQ, username, password) {
  let authCookie = '';
  const data = {
    username,
    password,
  };

  const options = {
    method: 'POST',
    url: '/auth',
    headers: {
      accept: 'application/json',
      'Content-Type': 'application/json'
    },
    data
  };
  debug('request', options);

  return REQ
    .request(options)
    .then(function(res) {
      debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
      expect(res).to.have.property('status');
      expect(res.status).to.equal(200);
      expect(res.data).to.be.an('object');
      expect(res.data).to.have.property('categories');
      expect(res.data.categories).to.have.property('apiml');
      expect(res.data.categories.apiml).to.have.property('success');
      expect(res.data.categories.apiml.success).to.be.true;
      expect(res.headers).to.be.an('object');
      expect(res.headers).to.have.property('set-cookie');
      authCookie = getCookie(res.headers['set-cookie']);
      debug(`cookies: ${JSON.stringify(authCookie)}`);
      expect(authCookie).to.contain(APIML_AUTH_COOKIE); 
      return authCookie;
    }).catch(function(err) {
      throw err;
    });
} 


// export constants and methods
module.exports = {
  zluxAuth
};