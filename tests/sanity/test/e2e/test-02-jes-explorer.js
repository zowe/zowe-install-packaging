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
const debug = require('debug')('test:e2e:jes-explorer');
const addContext = require('mochawesome/addContext');
const testName = path.basename(__filename, path.extname(__filename));

const { Key, until } = require('selenium-webdriver');

const { ZOWE_JOB_NAME } = require('../constants');
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

const APP_TO_TEST = 'JES Explorer';
const JOB_TO_TEST = ZOWE_JOB_NAME;
const JCL_TO_TEST = 'JESJCL';

const MVD_EXPLORER_TREE_SECTION = '#tree-text-content';
let appLaunched = false;
let findZoweJob = -1;

describe(`test ${APP_TO_TEST}`, function() {
  before('verify environment variable and load login page', async function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
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
    debug('atlas iframe is ready');

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
    // wait for a little bit before checking loading icon
    await driver.sleep(10 * 1000);
    await waitUntilElementIsGone(driver, 'div#loading-icon', treeContent);
    debug('page is fully loaded');

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'app-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTENT);

    appLaunched = true;
  });

  it(`should be able to list ZWE* jobs and should include ${JOB_TO_TEST}`, async function() {
    if (!appLaunched) {
      this.skip();
    }

    let treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);

    // expand filter
    const filter = await getElement(treeContent, '#filter-view');
    expect(filter).to.be.an('object');
    await filter.click();
    debug('filter form expanded');

    const ownerInput = await getElement(treeContent, 'input#filter-owner-field');
    // wait until username is pre-filled into filter-owner-field input
    try {
      await driver.wait(
        async() => {
          const ownerInputValue = await ownerInput.getAttribute('value');
          if (ownerInputValue.toLowerCase().indexOf('loading') === -1) {
            debug(`owner is loaded: ${ownerInputValue}`);
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
      const failureSS = await saveScreenshot(driver, testName, 'load-owner-failed');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        debug(`error loading owner: ${e}`);
        expect(e).to.be.null;
      }
    }

    // fill in filters
    const filterInputs = await getElements(treeContent, 'input');
    for (let input of filterInputs) {
      const id = await input.getAttribute('id');
      if (id.indexOf('-owner-') > -1) {
        await input.clear();
        await input.sendKeys('ZWE*');
      } else if (id.indexOf('-prefix-') > -1) {
        await input.clear();
        await input.sendKeys('ZWE*');
      }
    }

    // find status dropdown
    const filterStatusDropdown = await getElement(treeContent, '#filter-status-field div[label=Status]');
    expect(filterStatusDropdown).to.be.an('object');
    await filterStatusDropdown.click();
    debug('filter form updated');
    const filterStatusActive = await waitUntilElement(driver, '#status-ACTIVE');
    expect(filterStatusActive).to.be.an('object');
    await filterStatusActive.click();
    // wait a little more until the dropdown disappeared
    await driver.sleep(3 * 1000);

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'reset-filter', APP_TO_TEST, MVD_IFRAME_APP_CONTENT);
    treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);

    // submit filter
    const applyButton = await getElement(treeContent, 'button[type=submit]');
    expect(applyButton).to.be.an('object');
    await applyButton.click();
    debug('filter button clicked');

    // wait for results
    try {
      await driver.wait(
        async() => {
          const items = await getElements(treeContent, 'ul#job-list div.job-instance');
          debug(`found ${items.length} of menu items`);
          try {
            for (let i in items) {
              const label = await getElement(items[i], 'li .react-contextmenu-wrapper span.content-link span');
              if (label) {
                const text = await label.getText();
                // find active job
                if (text.indexOf(JOB_TO_TEST) > -1 && text.indexOf('[ACTIVE]') > -1) {
                  findZoweJob = parseInt(i, 10);
                  break;
                }
              }
            }
          } catch (itemsErr) {
            // ignore error
            findZoweJob = -1;
          }
          if (findZoweJob > -1) {
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
      const failureSS = await saveScreenshot(driver, testName, 'load-zowejob-failed');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        debug(`error finding job: ${e}`);
        expect(e).to.be.null;
      }
    }

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'zowe-job-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTENT);
    treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);

    expect(findZoweJob).to.be.above(-1);
    debug(`found ${JOB_TO_TEST} at ${findZoweJob}`);
  });

  it(`should be able to load content of ${JOB_TO_TEST} ${JCL_TO_TEST}`, async function() {
    if (!appLaunched || findZoweJob < 0) {
      this.skip();
    }

    // prepare app context and find the li of DS_TO_TEST
    await switchToIframeAppContext(driver, APP_TO_TEST, MVD_IFRAME_APP_CONTENT);
    let treeContent = await getElement(driver, MVD_EXPLORER_TREE_SECTION);
    expect(treeContent).to.be.an('object');
    // await driver.sleep(10 * 60 * 1000);
    const items = await getElements(treeContent, 'div#full-height-tree ul#job-list > div');
    const zoweJob = items[findZoweJob];

    // find the expand icon and click to load children
    const expandButton = await getElement(zoweJob, 'li div.react-contextmenu-wrapper svg.node-icon');
    expect(expandButton).to.be.an('object');
    await expandButton.click();
    debug(`${JOB_TO_TEST} job expand icon is clicked`);

    // find the JESJCL
    let findZoweJclFile = -1;
    await driver.sleep(1000);
    try {
      await driver.wait(
        async() => {
          const items2 = await getElements(zoweJob, 'ul li');
          expect(items2).to.be.an('array').that.have.lengthOf.above(0);
          debug(`found ${items2.length} of menu items`);
          for (let i in items2) {
            const label = await getElement(items2[i], 'span.content-link span');
            if (label) {
              const text = await label.getText();
              if (text === JCL_TO_TEST) {
                findZoweJclFile = parseInt(i, 10);
                break;
              }
            }
          }
          if (findZoweJclFile > -1) {
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
      const failureSS = await saveScreenshot(driver, testName, 'load-zowejob-items-failed');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        expect(e).to.be.null;
      }
    }
    expect(findZoweJclFile).to.be.above(-1);
    debug(`found ${JCL_TO_TEST} at ${findZoweJclFile}`);
    const items2 = await getElements(zoweJob, 'ul li');
    const zoweJclFile = items2[findZoweJclFile];

    // find the expand icon and click to load children
    const contentLink = await getElement(zoweJclFile, 'span.content-link');
    expect(contentLink).to.be.an('object');
    await contentLink.click();
    debug(`Active ${JOB_TO_TEST} ${JCL_TO_TEST} file content link is clicked`);

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'jcl-loading', APP_TO_TEST, MVD_IFRAME_APP_CONTENT);

    // wait for right panel updated
    await driver.sleep(1000);
    try {
      await driver.wait(
        async() => {
          let isHeaderReady = false,
            isContentReady = false;

          const header = await getElement(driver, '#content-viewer div div span div div div div:nth-child(1)');
          if (header) {
            const text = await header.getText();

            if (text.indexOf(JCL_TO_TEST) > -1) {
              isHeaderReady = true;
            }
          }

          if (isHeaderReady) {
            const content = await getElement(driver, '#embeddedEditor');
            if (content) {
              const text = await content.getAttribute('innerHTML');

              if (text) {
                isContentReady = true;
              }
            }
          }

          if (isHeaderReady && isContentReady) {
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
    debug(`Active ${JOB_TO_TEST} ${JCL_TO_TEST} file content is loaded`);

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'jcl-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTENT);
  });


  after('quit webdriver', async function() {
    // quit webdriver
    if (driver) {
      await driver.quit();
    }
  });
});
