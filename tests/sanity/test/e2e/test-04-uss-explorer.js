/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const path = require('path');
const expect = require('chai').expect;
const debug = require('debug')('test:e2e:uss-explorer');
const addContext = require('mochawesome/addContext');
const testName = path.basename(__filename, path.extname(__filename));

const { Key, until } = require('selenium-webdriver');

const {
  DEFAULT_PAGE_LOADING_TIMEOUT,
  DEFAULT_ELEMENT_CHECK_INTERVAL,
  MVD_IFRAME_APP_CONTENT,
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

const APP_TO_TEST = 'USS Explorer';
const DIR_TO_TEST = 'scripts';
const FILE_TO_TEST = 'instance.template.env';

const MVD_EXPLORER_INPUT_SECTION = 'div.tree-card div.component-header';
const MVD_EXPLORER_TREE_SECTION = 'div.tree-card div.node';

let appLaunched = false;
let testDirIndex = -1;


describe(`test ${APP_TO_TEST}`, function() {
  before('verify environment variable and load login page', async function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ROOT_DIR, 'ZOWE_ROOT_DIR is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;

    // init webdriver
    driver = await getDefaultDriver();
    debug('webdriver initialized');

    // load MVD login page
    await loginMVD(
      driver,
      `https://${process.env.SSH_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}/`,
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

    // wait for atlas iframe
    const atlas = await waitUntilIframe(driver, 'iframe#zluxIframe');
    expect(atlas).to.be.an('object');
    debug('zlux iframe is ready');

    // FIXME: shouldn't pop out authentication
    const alert = await driver.wait(until.alertIsPresent(), DEFAULT_PAGE_LOADING_TIMEOUT);
    await alert.sendKeys(process.env.SSH_USER + Key.TAB + process.env.SSH_PASSWD);
    await alert.accept();
    // to avoid StaleElementReferenceError, find the iframes context again
    await switchToIframeAppContext(driver, APP_TO_TEST, MVD_IFRAME_APP_CONTENT);
    debug('atlas login successfully');

    // wait for page is loaded
    const treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);
    expect(treeContent).to.be.an('object');
    // the loading icon is not there right after page is loaded, so wait a little
    await driver.sleep(1000);
    await waitUntilElementIsGone(driver, 'div[mode=indeterminate]', treeContent);
    debug('page is fully loaded');

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'app-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTENT);

    appLaunched = true;
  });

  it('should be able to list Zowe installation folder', async function() {
    if (!appLaunched) {
      this.skip();
    }

    let treeContent = await waitUntilElement(driver, MVD_EXPLORER_INPUT_SECTION);

    // replace inputPath
    const inputPath = await getElement(treeContent, 'input#path');
    expect(inputPath).to.be.an('object');
    await inputPath.clear();
    await inputPath.sendKeys(process.env.ZOWE_ROOT_DIR + Key.ENTER);
    debug('inputPath updated');

    // wait for results
    await driver.sleep(1000);
    await waitUntilElementIsGone(driver, 'div[mode=indeterminate]', treeContent);
    debug('page reloaded');

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'file-list-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTENT);
    treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);

    // load children of DIR_TO_TEST
    const items = await getElements(treeContent, 'ul li');
    expect(items).to.be.an('array').that.have.lengthOf.above(0);
    debug(`found ${items.length} of menu items`);
    for (let i in items) {
      const label = await getElement(items[i], 'div.node div.react-contextmenu-wrapper div.node-label');
      if (label) {
        const text = await label.getText();
        if (text === DIR_TO_TEST) {
          testDirIndex = parseInt(i, 10);
          break;
        }
      }
    }
    expect(testDirIndex).to.be.above(-1);
    debug(`found ${DIR_TO_TEST} at ${testDirIndex}`);
  });

  it(`should be able to load content of ${DIR_TO_TEST}/${FILE_TO_TEST} file`, async function() {
    if (!appLaunched || testDirIndex < 0) {
      this.skip();
    }

    // prepare app context and find the li of DIR_TO_TEST
    await switchToIframeAppContext(driver, APP_TO_TEST, MVD_IFRAME_APP_CONTENT);
    const treeContent = await getElement(driver, MVD_EXPLORER_TREE_SECTION);
    expect(treeContent).to.be.an('object');
    const items = await getElements(treeContent, 'ul li');
    const testDirFound = items[testDirIndex];

    // find the file icon and click load content
    const expandButton = await getElement(testDirFound, 'div.node div.react-contextmenu-wrapper div.node-label');
    expect(expandButton).to.be.an('object');
    await expandButton.click();
    debug(`${DIR_TO_TEST} is clicked`);

    // wait until dir content is loaded
    await driver.sleep(1000);
    try {
      await driver.wait(
        async() => {
          const firstItem = await getElement(testDirFound, 'div.node ul li:nth-child(1)');
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
      const failureSS = await saveScreenshot(driver, testName, 'load-items-failed');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        expect(e).to.be.null;
      }
    }
    debug(`${DIR_TO_TEST} content list is updated`);

    // load children of DIR_TO_TEST
    const fileItems = await getElements(testDirFound, 'div.node ul li');
    expect(fileItems).to.be.an('array').that.have.lengthOf.above(0);
    debug(`found ${fileItems.length} of menu items`);
    let testFileIndex = -1;
    for (let i in fileItems) {
      const label = await getElement(fileItems[i], 'div.node div.react-contextmenu-wrapper div.node-label span.node-label');
      if (label) {
        const text = await label.getText();
        if (text === FILE_TO_TEST) {
          testFileIndex = parseInt(i, 10);
          break;
        }
      }
    }
    expect(testFileIndex).to.be.above(-1);
    debug(`found ${DIR_TO_TEST}/${FILE_TO_TEST} at ${testFileIndex}`);
    const testFileFound = fileItems[testFileIndex];

    // find the file icon and click load content
    const contentLink = await getElement(testFileFound, 'div.node div.react-contextmenu-wrapper div.node-label span.node-label');
    expect(contentLink).to.be.an('object');
    await contentLink.click();
    debug(`${DIR_TO_TEST}/${FILE_TO_TEST} is clicked`);

    // find right panel header
    const fileContentPanelHeader = await getElement(driver, 'div.component-no-vertical-pad div.component-no-vertical-pad > div:nth-child(1)');
    expect(fileContentPanelHeader).to.be.an('object');
    try {
      await driver.wait(
        async() => {
          const text = await fileContentPanelHeader.getText();

          if (text.indexOf(`/${DIR_TO_TEST}/${FILE_TO_TEST}`) > -1) {
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
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'file-content-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTENT);
  });


  after('quit webdriver', async function() {
    // quit webdriver
    if (driver) {
      await driver.quit();
    }
  });
});
