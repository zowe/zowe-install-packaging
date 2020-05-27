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
const testUtils = require('./utils');

let request, username, password;
const ZOSMF_TOKEN = 'LtpaToken2';

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

let assertNotEmptyValidResponse = (response) => {
  expect(response.status).to.equal(200);
  expect(response.data).to.not.be.empty;
};

describe('test api mediation layer zosmf authentication', function() {
  before('verify environment variables', function() {
    request = testUtils.verifyAndSetupEnvironment();
    const environment = process.env;
    username = environment.SSH_USER;
    password = environment.SSH_PASSWD;
  });

  describe('should be able to get data from z/OSMF ', () => {
    it('with valid basic header', async () => {
      const token = Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
      const response = await request.get('/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*', {
        headers: {
          'Authorization': `Basic ${token}`,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      assertNotEmptyValidResponse(response);
    });

    it('with valid cookie', async () => {
      const uuid = testUtils.uuid();
      const authenticationCookie = await testUtils.login(uuid);

      testUtils.log(uuid, '/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*');
      const response = await request.get('/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*', {
        headers: {
          'Cookie': authenticationCookie,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });
      testUtils.logResponse(uuid, response);

      assertNotEmptyValidResponse(response);
    });

    it('with valid LTPA cookie', async () => {
      const token = Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
      const loginResponse = await request.get('/api/v1/zosmf/info', {
        headers: {
          'Authorization': `Basic ${token}`,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      const ltpaCookie = testUtils.findCookieInResponse(loginResponse, ZOSMF_TOKEN);
      const response = await request.get('/api/v1/zosmf/info', {
        headers: {
          'Cookie': ltpaCookie,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      assertNotEmptyValidResponse(response);
    });

    it('with valid JWT token via Bearer', async () => {
      const uuid = testUtils.uuid();
      const authenticationCookie = await testUtils.login(uuid);
      const justCookie = authenticationCookie.split(';')[0];
      const tokenValue = justCookie.split('=')[1];

      testUtils.log(uuid, '/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*');
      const response = await request.get('/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*', {
        headers: {
          'Authorization': `Bearer ${tokenValue}`,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });
      testUtils.logResponse(uuid, response);

      assertNotEmptyValidResponse(response);
    });
  });
});
