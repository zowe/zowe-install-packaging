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
const { HTTPRequest, HTTP_STATUS } = require('../http-helper');
const debug = require('debug')('zowe-sanity-test:apiml:api-gateway-version');

describe('test api gateway version', function() {

  let hq;

  before('verify environment variables', function() {
    hq = new HTTPRequest();
  });

  it('should return the version information of the API Mediation Layer and Zowe', async function() {
    debug('Verify access to version via /application/version');

    const res = await hq.request({
      url: '/application/version',
      method: 'get',
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.have.property('apiml');
    expect(res.data.apiml).to.have.property('version');
    expect(res.data.apiml).to.have.property('buildNumber');
    expect(res.data.apiml).to.have.property('commitHash');
  });

});
