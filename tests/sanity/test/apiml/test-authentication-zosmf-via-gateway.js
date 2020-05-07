/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:apiml:gateway');
const axios = require('axios');

let request, username, password;
const APIML_AUTH_COOKIE = 'apimlAuthenticationToken';
const ZOSMF_TOKEN = 'LtpaToken2';

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

let login = async () => {
  let response = await request.post('/api/v1/apicatalog/auth/login', {
    username, password
  });

  // Validate the response at least basically
  expect(response.status).to.be.oneOf([200, 204]);
  expect(response.headers).to.be.an('object');
  expect(response.headers).to.have.property('set-cookie');
  expect(response.data).to.be.empty;

  return findCookieInResponse(response, APIML_AUTH_COOKIE);
};

let findCookieInResponse = (response, cookieName) => {
  let cookiesSetByServer = response.headers['set-cookie'];
  let authenticationCookie = cookiesSetByServer.filter(cookieRow => cookieRow.startsWith(cookieName));
  if(authenticationCookie.length === 0) {
    throw new Error('The authentication was unsuccessful');
  }

  return authenticationCookie[0];
};

describe('test api mediation layer zosmf authentication', function() {
  before('verify environment variables', function() {
    const environment = process.env;
    expect(environment.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(environment.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(environment.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(environment.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    const baseUrl = `https://${environment.SSH_HOST}:${environment.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`;
    request = axios.create({
      baseURL: baseUrl,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json'
      }
    });
    username = environment.SSH_USER;
    password = environment.SSH_PASSWD;
    debug(`Explorer server URL: ${baseUrl}`);
  });

  describe('should be able to get data from ZOSM/f ', () => {
    it('with valid basic header', async () => {
      const token = Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
      const response = await request.get('/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*', {
        headers: {
          'Authorization': `Basic ${token}`,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      expect(response.status).to.equal(200);
      expect(response.data).to.not.be.empty;
    });

    it('with valid cookie', async () => {
      const authenticationCookie = await login();

      const response = await request.get('/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*', {
        headers: {
          'Cookie': authenticationCookie,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      expect(response.status).to.equal(200);
      expect(response.data).to.not.be.empty;
    });

    it('with valid LTPA cookie', async () => {
      const token = Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
      const loginResponse = await request.get('/api/v1/zosmf/info', {
        headers: {
          'Authorization': `Basic ${token}`,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      const ltpaCookie = findCookieInResponse(loginResponse, ZOSMF_TOKEN);
      const response = await request.get('/api/v1/zosmf/info', {
        headers: {
          'Cookie': ltpaCookie,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      expect(response.status).to.equal(200);
      expect(response.data).to.not.be.empty;
    });

    it('with valid JWT token via Bearer', async () => {
      const authenticationCookie = await login();
      const justCookie = authenticationCookie.split(';')[0];
      const tokenValue = justCookie.split('=')[1];

      const response = await request.get('/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*', {
        headers: {
          'Authorization': `Bearer ${tokenValue}`,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      expect(response.status).to.equal(200);
      expect(response.data).to.not.be.empty;
    });
  });
});
