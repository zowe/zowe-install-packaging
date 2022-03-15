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
const {
  APIML_AUTH_COOKIE,
  EXPLORER_API_TEST_DATASET_PATTERN,
  EXPLORER_API_TEST_DATASET_NAME,
  EXPLORER_API_TEST_DATASET_MEMBER_NAME,
} = require('../constants');

describe('test explorer server datasets api v2',async function() {

  let hq;
  let apiml;
  let token;

  before('verify environment variables', async function() {
    hq = new HTTPRequest();
    apiml = new APIMLAuth(hq);
    token = await apiml.login();
  });

  it(`should be able to list data sets of ${EXPLORER_API_TEST_DATASET_PATTERN} (v2 API)`, async() => {
    const req = {
      url: '/datasets/api/v2/' + encodeURIComponent(EXPLORER_API_TEST_DATASET_PATTERN),
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    };

    const res = await hq.request(req);
    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data.items).to.be.a('array');
    expect(res.data.items.map(one => one.name)).to.include(EXPLORER_API_TEST_DATASET_NAME);
  });

  it(`should be able to list data sets of ${EXPLORER_API_TEST_DATASET_PATTERN} (v2 API) (manual decompress)`, async() => {
    const req = {
      url: '/datasets/api/v2/' + encodeURIComponent(EXPLORER_API_TEST_DATASET_PATTERN),
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    };

    const res = await hq.request(req, { manualDecompress: true });
    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data.items).to.be.a('array');
    expect(res.data.items.map(one => one.name)).to.include(EXPLORER_API_TEST_DATASET_NAME);
  });

  it(`should be able to get members of data set ${EXPLORER_API_TEST_DATASET_NAME} (v2 API)`, async() => {
    const req = {
      url: '/datasets/api/v2/' + encodeURIComponent(EXPLORER_API_TEST_DATASET_NAME) + '/members',
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    };

    const res = await hq.request(req);
    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('items');
    expect(res.data.items).to.be.an('array');
    expect(res.data.items).to.include(EXPLORER_API_TEST_DATASET_MEMBER_NAME);
  });

  it(`should be able to get members of data set ${EXPLORER_API_TEST_DATASET_NAME} (v2 API) (manual decompress)`, async() => {
    const req = {
      url: '/datasets/api/v2/' + encodeURIComponent(EXPLORER_API_TEST_DATASET_NAME) + '/members',
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    };

    const res = await hq.request(req, { manualDecompress: true });
    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('items');
    expect(res.data.items).to.be.an('array');
    expect(res.data.items).to.include(EXPLORER_API_TEST_DATASET_MEMBER_NAME);
  });

  it(`should be able to get content of a data set member ${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME}) (v2 API)`, async() => {
    const req = {
      url:'/datasets/api/v2/' + encodeURIComponent(`${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME})`) + '/content', 
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    };

    const res = await hq.request(req);
    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('records');
    expect(res.data.records).to.be.a('string');
  });

  it(`should be able to get content of a data set member ${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME}) (v2 API) (manual decompress)`, async() => {
    const req = {
      url:'/datasets/api/v2/' + encodeURIComponent(`${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME})`) + '/content', 
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    };

    const res = await hq.request(req, { manualDecompress: true, ungzip: false });
    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
  });
});
