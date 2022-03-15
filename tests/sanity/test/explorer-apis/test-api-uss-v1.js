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

describe('test explorer server uss files api', function() {

  let hq;

  before('verify environment variables', function() {
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;

    hq = new HTTPRequest(null, null, null, {
      username: process.env.SSH_USER,
      password: process.env.SSH_PASSWD,
    });
  });

  it('Gets a list of files and directories for a given path', async function() {
    const res = await hq.request({
      url: `/unixfiles/api/v1?path=${process.env.ZOWE_WORKSPACE_DIR}`,
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

  it('Gets a list of files and directories for a given path (manual decompress)', async function() {
    const res = await hq.request({
      url: `/unixfiles/api/v1?path=${process.env.ZOWE_WORKSPACE_DIR}`,
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
