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
const { HTTPRequest, HTTP_STATUS, APIMLAuth } = require('../http-helper');
const { APIML_AUTH_COOKIE } = require('../constants');

describe('test api mediation layer zosmf api', function() {

  let hq;
  let apiml;
  let token;

  before('verify environment variables', function() {
    hq = new HTTPRequest(null, null, {
      // required header by z/OSMF API
      'X-CSRF-ZOSMF-HEADER': '*',
    });
    apiml = new APIMLAuth(hq);
  });

  it('should be able to login to z/OS', async function() {
    // FIXME: /zosmf/api/v1/info doesn't require authentication, do we need to login?
    token = await apiml.login();
  });

  it('should be able to get z/OS Info via the gateway port and endpoint (/api/v1/zosmf/info)', async function() {
    if (!token) {
      this.skip();
    }

    const res = await hq.request({
      url: '/zosmf/api/v1/info',
      method: 'get',
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      },
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('api_version');
    expect(res.data).to.have.property('plugins');
    expect(res.data).to.have.property('zosmf_full_version');
    expect(res.data).to.have.property('zos_version');
  });
});
