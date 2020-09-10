/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const _ = require('lodash');
const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:explorer:api-uss');
const axios = require('axios');
const addContext = require('mochawesome/addContext');
const utils = require('./utils');

let REQ;

describe('test explorer server uss files api', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    REQ = utils.verifyAndSetupEnvironment();
  });

  it(`Gets a list of files and directories for a given path (v2 API)`, async() => {
    const uuid = utils.uuid();
    const authenticationCookie = await utils.login(uuid);

    utils.log(uuid, ' URL: /api/v2/unixfiles?path=' + process.env.ZOWE_INSTANCE_DIR);
    const res = await REQ.get(`/api/v2/unixfiles?path=${process.env.ZOWE_INSTANCE_DIR}`, {
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    });
    utils.logResponse(uuid, res);

    expect(res).to.have.property('status');
    expect(res.status).to.equal(200);
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
