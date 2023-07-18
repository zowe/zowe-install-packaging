/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2020
 */

//const { setApimlAuthTokenCookie } = require('explorer-fvt-utilities');
const path = require('path');
const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:e2e:mvs-explorer');
const addContext = require('mochawesome/addContext');
const testName = path.basename(__filename, path.extname(__filename));

const { Key } = require('selenium-webdriver');

const {
  DEFAULT_PAGE_LOADING_TIMEOUT,
  DEFAULT_ELEMENT_CHECK_INTERVAL,
  MVD_IFRAME_APP_CONTEXT,
  saveScreenshot,
  getDefaultDriver,
  getElement,
  getElements,
  waitUntilElement,
  waitUntilElementIsGone,
  waitUntilIframe,
  loginMVD,
  launchApp,
  locateApp,
  switchToIframeAppContext,
  saveScreenshotWithIframeAppContext,
} = require('./utils');
let driver;

const APP_TO_TEST = 'MVS Explorer';
const EXPLORER_API_TEST_DATASET_PATTERN = 'SYS1.LINKLIB*';
const EXPLORER_API_TEST_DATASET_NAME = 'SYS1.LINKLIB';
const EXPLORER_API_TEST_DATASET_MEMBER_NAME = 'ACCOUNT';

const MVD_EXPLORER_TREE_SECTION = 'div.tree-card > div';

let appLaunched = false;
let testDsIndex = -1;
let testDsMemberIndex = -1;


describe(`test ${APP_TO_TEST}`, function() {
  before('verify environment variable and load login page', async function() {
    expect(process.env.ZOWE_EXTERNAL_HOST, 'ZOWE_EXTERNAL_HOST is empty').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    // init webdriver
    driver = await getDefaultDriver();
    debug('webdriver initialized');

    //await setApimlAuthTokenCookie(driver, 	
    //  process.env.SSH_USER, 	
    //  process.env.SSH_PASSWD, 	
    //  `https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/gateway/api/v1/auth/login`, 	
    //  `https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/zlux/ui/v1/ZLUX/plugins/org.zowe.explorer-mvs/web/index.html`	
    //);

    await loginMVD(
      driver,
      `https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/zlux/ui/v1/ZLUX/plugins/org.zowe.zlux.bootstrap/web/`,
      process.env.SSH_USER,
      process.env.SSH_PASSWD
    );
  });


  it('should launch app correctly', async function() {
    // load app
    await launchApp(driver, APP_TO_TEST);
    const app = await locateApp(driver, APP_TO_TEST);
    expect(app).to.be.an('object');
    debug('app launched');

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'app-loading');
    addContext(this, file);

    // locate app iframe
    const iframe = await waitUntilIframe(driver, 'rs-com-mvd-iframe-component > iframe', app);
    expect(iframe).to.be.an('object');
    debug('app iframe found');

    // wait for page is loaded
    const treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);
    expect(treeContent).to.be.an('object');
    // the loading icon is not there right after page is loaded, so wait a little
    await driver.sleep(1000);
    await waitUntilElementIsGone(driver, 'div[role=progressbar]', treeContent);
    debug('page is fully loaded');

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'app-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTEXT);

    appLaunched = true;
  });

  it(`should be able to list ${EXPLORER_API_TEST_DATASET_PATTERN} data sets`, async function() {
    if (!appLaunched) {
      this.skip();
    }

    let treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);

    // replace qualifier
    const qualifier = await getElement(treeContent, 'input#datasets-qualifier-field');
    expect(qualifier).to.be.an('object');
    await qualifier.clear();
    await qualifier.sendKeys(EXPLORER_API_TEST_DATASET_PATTERN + Key.ENTER);
    debug('qualifier updated');

    // wait for results
    await driver.sleep(1000);
    await waitUntilElementIsGone(driver, 'svg#loading-icon', treeContent);
    debug('page reloaded');

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'ds-list-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTEXT);
    treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);

    const items = await getElements(treeContent, 'div.node ul li');
    expect(items).to.be.an('array').that.have.lengthOf.above(0);
    debug(`found ${items.length} of menu items`);
    for (let i in items) {
      const label = await getElement(items[i], 'div.react-contextmenu-wrapper span.node-label');
      if (label) {
        const text = await label.getText();
        if (text === EXPLORER_API_TEST_DATASET_NAME) {
          testDsIndex = parseInt(i, 10);
          break;
        }
      }
    }
    expect(testDsIndex).to.be.above(-1);
    debug(`found ${EXPLORER_API_TEST_DATASET_NAME} at ${testDsIndex}`);
    const testDsFound = items[testDsIndex];

    // find the dataset icon and click load members
    const dsLabelLink = await getElement(testDsFound, 'div.react-contextmenu-wrapper span.node-label');
    expect(dsLabelLink).to.be.an('object');
    await dsLabelLink.click();
    debug(`${EXPLORER_API_TEST_DATASET_NAME} is clicked`);

    // wait for members loaded
    await driver.sleep(1000);
    try {
      await driver.wait(
        async() => {
          const firstItem = await getElement(testDsFound, 'div.node ul li:nth-child(1)');
          if (firstItem) {
            return true;
          }

          await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
          return false;
        },
        DEFAULT_PAGE_LOADING_TIMEOUT
      );
    } catch (e) {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      const failureSS = await saveScreenshot(driver, testName, 'load-ds-member-failed');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        expect(e).to.be.null;
      }
    }
    debug(`${EXPLORER_API_TEST_DATASET_NAME} members list is updated`);


    const members = await getElements(testDsFound, 'div.node ul li');
    expect(members).to.be.an('array').that.have.lengthOf.above(0);
    debug(`found ${members.length} members of ${EXPLORER_API_TEST_DATASET_NAME}`);
    for (let i in members) {
      const label = await getElement(members[i], 'span.node-label');
      if (label) {
        const text = await label.getText();
        if (text === EXPLORER_API_TEST_DATASET_MEMBER_NAME) {
          testDsMemberIndex = parseInt(i, 10);
          break;
        }
      }
    }
    expect(testDsMemberIndex).to.be.above(-1);
    debug(`found ${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME}) at ${testDsMemberIndex}`);

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'ds-members-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTEXT);
  });

  it(`should be able to load content of ${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME}) data set member`, async function() {
    if (!appLaunched || testDsIndex < 0 || testDsMemberIndex < 0) {
      this.skip();
    }

    // prepare app context and find the li of EXPLORER_API_TEST_DATASET_NAME
    await switchToIframeAppContext(driver, APP_TO_TEST, MVD_IFRAME_APP_CONTEXT);
    const treeContent = await getElement(driver, MVD_EXPLORER_TREE_SECTION);
    expect(treeContent).to.be.an('object');
    const items = await getElements(treeContent, 'div.node > ul > div > li');
    const testDsFound = items[testDsIndex];

    // find the member we are testing
    const members = await getElements(testDsFound, 'div.node > ul li');
    const testDsMemberFound = members[testDsMemberIndex];

    // find the member icon and click load content
    const contentLink = await getElement(testDsMemberFound, 'span.content-link');
    expect(contentLink).to.be.an('object');
    await contentLink.click();
    debug(`${EXPLORER_API_TEST_DATASET_NAME} is clicked`);

    // find right panel header
    const fileContentPanelHeader = await getElement(driver, 'div.component-no-vertical-pad div.component-no-vertical-pad > div:nth-child(1)');
    expect(fileContentPanelHeader).to.be.an('object');
    try {
      await driver.wait(
        async() => {
          const text = await fileContentPanelHeader.getText();

          if (text.indexOf(EXPLORER_API_TEST_DATASET_NAME) > -1) {
            return true;
          }

          await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
          return false;
        },
        DEFAULT_PAGE_LOADING_TIMEOUT
      );
    } catch (e) {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      const failureSS = await saveScreenshot(driver, testName, 'load-content-failed');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        expect(e).to.be.null;
      }
    }
    debug('right panel is loaded');

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'ds-content-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTEXT);
  });


  after('quit webdriver', async function() {
    // quit webdriver
    if (driver) {
      await driver.quit();
    }
  });
});
