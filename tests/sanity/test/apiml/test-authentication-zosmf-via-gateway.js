/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

const expect = require('chai').expect;
const { HTTPRequest, APIMLAuth } = require('../http-helper');
const { APIML_AUTH_COOKIE, ZOSMF_TOKEN } = require('../constants');

describe('test api mediation layer zosmf authentication', function() {

  let hq;
  let apiml;
  let username, password;

  before('verify environment variables', function() {
    hq = new HTTPRequest(null, null, {
      // required header by z/OSMF API
      'X-CSRF-ZOSMF-HEADER': '*',
    });
    apiml = new APIMLAuth(hq);

    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    username = process.env.SSH_USER;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    password = process.env.SSH_PASSWD;
  });

  describe('should be able to get data from z/OSMF ', function() {

    const assertNotEmptyValidResponse = (res) => {
      expect(res.status).to.equal(200);
      expect(res.data).to.not.be.empty;
    };

    it('with valid basic header', async function() {
      const token = Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
      const res = await hq.request({
        url: '/zosmf/api/v1/restfiles/ds?dslevel=SYS1.PARMLIB*',
        headers: {
          'Authorization': `Basic ${token}`,
        }
      });

      assertNotEmptyValidResponse(res);
    });

    it('with valid cookie', async function() {
      const token = await apiml.login();
      const res = await hq.request({
        url: '/zosmf/api/v1/restfiles/ds?dslevel=SYS1.PARMLIB*',
        headers: {
          Cookie: `${APIML_AUTH_COOKIE}=${token}`,
        }
      });

      assertNotEmptyValidResponse(res);
    });

    it('with valid LTPA cookie', async function() {
      const token = Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
      const loginResponse = await hq.request({
        url: '/zosmf/api/v1/info',
        headers: {
          'Authorization': `Basic ${token}`,
        }
      });

      const ltpaCookie = hq.findCookieInResponse(loginResponse, ZOSMF_TOKEN);
      const response = await hq.request({
        url: '/zosmf/api/v1/info',
        headers: {
          'Cookie': ltpaCookie,
        }
      });

      assertNotEmptyValidResponse(response);
    });

    it('with valid JWT token via Bearer', async function() {
      const token = await apiml.login();
      const res = await hq.request({
        url: '/zosmf/api/v1/restfiles/ds?dslevel=SYS1.PARMLIB*',
        headers: {
          'Authorization': `Bearer ${token}`,
        }
      });

      assertNotEmptyValidResponse(res);
    });

  });
});
