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

describe('test explorer server uss files api v2', function() {

  let hq;
  let apiml;
  let token;

  before('verify environment variables', async function() {
    hq = new HTTPRequest();
    apiml = new APIMLAuth(hq);
    token = await apiml.login();
  });

  it('Gets a list of files and directories for a given path (v2 API)', async() => {
    const res = await hq.request({
      url: `/unixfiles/api/v2?path=${process.env.ZOWE_WORKSPACE_DIR}`,
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('type');
    expect(res.data.type).to.be.a('string');
    expect(res.data).to.have.property('owner');
    expect(res.data.owner).to.be.a('string');
    expect(res.data).to.have.property('group');
    expect(res.data.group).to.be.a('string');
    expect(res.data).to.have.property('permissionsSymbolic');
    expect(res.data.permissionsSymbolic).to.be.a('string');
  });

  it('Gets a list of files and directories for a given path (v2 API) (manual decompress)', async() => {
    const res = await hq.request({
      url: `/unixfiles/api/v2?path=${process.env.ZOWE_WORKSPACE_DIR}`,
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    }, {
      manualDecompress: true,
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('type');
    expect(res.data.type).to.be.a('string');
    expect(res.data).to.have.property('owner');
    expect(res.data.owner).to.be.a('string');
    expect(res.data).to.have.property('group');
    expect(res.data.group).to.be.a('string');
    expect(res.data).to.have.property('permissionsSymbolic');
    expect(res.data.permissionsSymbolic).to.be.a('string');
  });
});
