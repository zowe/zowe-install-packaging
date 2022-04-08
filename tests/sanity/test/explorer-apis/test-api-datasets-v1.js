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
const {
  EXPLORER_API_TEST_DATASET_PATTERN,
  EXPLORER_API_TEST_DATASET_NAME,
  EXPLORER_API_TEST_DATASET_MEMBER_NAME,
} = require('../constants');

const getDatasetHelper = async function(hq, manualDecompress=false) {
  const res = await hq.request({
    url: '/datasets/api/v1/' + encodeURIComponent(EXPLORER_API_TEST_DATASET_PATTERN),
  }, {
    manualDecompress,
  });

  expect(res).to.have.property('status');
  expect(res.status).to.equal(HTTP_STATUS.SUCCESS);

  expect(res).to.have.property('headers');
  if (manualDecompress) {
    expect(res.headers).to.have.property('content-encoding');
    expect(res.headers['content-encoding']).to.equal('gzip');
  }

  expect(res.data).to.be.an('object');
  expect(res.data).to.have.property('items');
  expect(res.data.items).to.be.an('array');
  expect(res.data.items.map(one => one.name)).to.include(EXPLORER_API_TEST_DATASET_NAME);
};

const getDatasetMemberHelper = async function(hq, manualDecompress=false) {
  const res = await hq.request({
    url: '/datasets/api/v1/' + encodeURIComponent(EXPLORER_API_TEST_DATASET_NAME) + '/members',
  }, {
    manualDecompress,
  });

  expect(res).to.have.property('status');
  expect(res.status).to.equal(HTTP_STATUS.SUCCESS);

  expect(res).to.have.property('headers');
  if (manualDecompress) {
    expect(res.headers).to.have.property('content-encoding');
    expect(res.headers['content-encoding']).to.equal('gzip');
  }

  expect(res.data).to.be.an('object');
  expect(res.data).to.have.property('items');
  expect(res.data.items).to.be.an('array');
  expect(res.data.items).to.include(EXPLORER_API_TEST_DATASET_MEMBER_NAME);
};

const getDatasetContentHelper = async function(hq, manualDecompress=false) {
  const res = await hq.request({
    url: '/datasets/api/v1/' + encodeURIComponent(`${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME})`) + '/content',
  }, {
    manualDecompress,
    ungzip: false,
  });

  //checks for both paths
  expect(res).to.have.property('status');
  expect(res.status).to.equal(HTTP_STATUS.SUCCESS);

  expect(res).to.have.property('headers');
  if (manualDecompress) {
    expect(res.headers).to.have.property('content-encoding');
    expect(res.headers['content-encoding']).to.equal('gzip');
    return;
  }

  // checks for default path only - content JSON.parse(data.toString()) parsing cause exception
  expect(res.data).to.be.an('object');
  expect(res.data).to.have.property('records');
  expect(res.data.records).to.be.a('string');
};

describe('test explorer server datasets api', function() {

  let hq;

  before('verify environment variables', function() {
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;

    hq = new HTTPRequest(null, null, null, {
      username: process.env.SSH_USER,
      password: process.env.SSH_PASSWD,
    });
  });

  it(`should be able to list data sets of ${EXPLORER_API_TEST_DATASET_PATTERN} default`, async function() {
    await getDatasetHelper(hq);
  });

  it(`should be able to list data sets of ${EXPLORER_API_TEST_DATASET_PATTERN} decompress with zlib`, async function() {
    await getDatasetHelper(hq, true);
  });

  it(`should be able to get members of data set ${EXPLORER_API_TEST_DATASET_NAME} default`, async function() {
    await getDatasetMemberHelper(hq);
  });

  it(`should be able to get members of data set ${EXPLORER_API_TEST_DATASET_NAME} decompress with zlib`, async function() {
    await getDatasetMemberHelper(hq, true);
  });

  it(`should be able to get content of data set ${EXPLORER_API_TEST_DATASET_NAME} default`, async function() {
    await getDatasetContentHelper(hq);
  });

  it(`should be able to get content of data set ${EXPLORER_API_TEST_DATASET_NAME} decompress with zlib`, async function() {
    await getDatasetContentHelper(hq, true);
  });
  
  it('returns the current user\'s TSO userid', async function() {
    const res = await hq.request({
      url: '/datasets/api/v1/username',
      method: 'get',
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('username');
    expect(res.data.username).to.be.a('string');
  });
});
