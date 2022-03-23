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

describe('test endpoint /services and its authentication', function() {

  let hq;
  let apiml;
  let token;

  before('obtain JWT token', async function() {
    hq = new HTTPRequest();
    apiml = new APIMLAuth(hq);
    token = await apiml.login();
  });

  it('should be able get list of services with authenticated user', async function() {
    const res = await hq.request({
      url: '/gateway/services',
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      },
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('array').that.is.not.empty;
    expect(res.data.map(x => x.serviceId)).to.include.members(['gateway', 'discovery']);
  });

  it('should be able get list of services with authenticated user, routed version', async function() {
    const res = await hq.request({
      url: '/gateway/api/v1/services',
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      },
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('array').that.is.not.empty;
    expect(res.data.map(x => x.serviceId)).to.include.members(['gateway', 'discovery']);
  });

});
