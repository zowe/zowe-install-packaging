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
const debug = require('debug')('zowe-sanity-test:apiml:sample-extension-controller');

describe('test api gateway sample extension controller', function() {

  let hq;

  before('verify environment variables', function() {
    hq = new HTTPRequest();
  });

  it('should return the greeting message from the gateway sample extension controller', async function() {
    
    const isAttlsEnabled = process.env['ZOWE_IS_ATTLS_ENABLED'];
    if (isAttlsEnabled === true || isAttlsEnabled === 'true' ) {
      debug('Skipping sample extension verification: see https://github.com/zowe/api-layer/issues/4340');
    } else {
      debug('Verify access to greeting endpoint via /api/v1/greeting');

      const res = await hq.request({
        url: '/api/v1/greeting',
        method: 'get',
      });

      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
      expect(res.data).to.not.be.empty;
    }
  });

});
