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

describe('test zss x509 certificate mapping via gateway', function() {

  let hq;
  let apiml;
  let token;

  it('obtain JWT for certificate', async function() {
    hq = new HTTPRequest();
    apiml = new APIMLAuth(hq);
    token = await apiml.loginWithCertificate();
  });

  it('call endpoint with valid certificate', async function() {
    if (!token) {
      this.skip();
    }

    const res = await hq.request({
      url: `jobs/api/v2?owner=${process.env.SSH_USER.toUpperCase()}&prefix=*`,
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
        'X-CSRF-ZOSMF-HEADER': '*',
      },
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.not.be.empty;
  });

});
