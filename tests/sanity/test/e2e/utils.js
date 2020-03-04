/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

/*eslint no-console: ["error", { allow: ["log", "warn", "error"] }] */

const _ = require('lodash');
const fs = require('fs');
const path = require('path');
const util = require('util');
const expect = require('chai').expect;
const debug = require('debug')('test:e2e:utils');
const { Capabilities, Builder, By, logging } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const firefox = require('selenium-webdriver/firefox');
// method to attach screenshots and other content to mochawesome HTML report
const addContext = require('mochawesome/addContext');

const writeFile = util.promisify(fs.writeFile);
const testName = path.basename(__filename, path.extname(__filename));

const PRE_INSTALLED_APPS = [
  'JES Explorer',
  'MVS Explorer',
  'USS Explorer',
  'TN3270',
  'VT Terminal',
  'User Tasks/Workflows',
  // 'IFrame',
  // 'ZOS Subsystems',
  'API Catalog',
  'Editor',
  'Sample Angular App',
  'Sample React App',
  'IFrame Sample',
  // 'Hello World',
];
const PRE_PINNED_APPS = [
  'TN3270',
  'JES Explorer',
  'Editor',
  'VT Terminal',
];

// timeout of HTTP request to Zowe services, default is 3m
const DEFAULT_PAGE_LOADING_TIMEOUT = 180000;
// interval to check if element is in place
const DEFAULT_ELEMENT_CHECK_INTERVAL = 500;
// where to save screenshots
const DEFAULT_SCREENSHOT_PATH = './reports';
// screenshots unqiue index
let SCREENSHOT_FILECOUNT = 0;

// css selector to find MVD iframe app
const MVD_IFRAME_APP_CONTEXT = ['rs-com-mvd-iframe-component > iframe'];
// css selector to find MVD iframe app content
const MVD_IFRAME_APP_CONTENT = ['rs-com-mvd-iframe-component > iframe', 'iframe#zluxIframe'];

/**
 * Get unqiue screen shot image name
 *
 * @param  {WebDriver} driver         Selenium WebDriver
 * @param  {String}    testScript     name of file holds test cases
 * @param  {String}    screenshotName screen shot identity name
 * @return {String}                   file name
 */
const getImagePath = async(driver, testScript, screenshotName) => {
  const dc = await driver.getCapabilities();
  const browserName = dc.getBrowserName(),
    browserVersion = dc.getBrowserVersion() || dc.get('version'),
    platform = dc.getPlatform() || dc.get('platform');

  const file = [
    browserName ? browserName.toUpperCase() : 'ANY',
    browserVersion ? browserVersion.toUpperCase() : 'ANY',
    platform.toUpperCase(),
    testScript.replace(/ /g, '-').toLowerCase(),
    _.padStart(SCREENSHOT_FILECOUNT++, 3, '0'),
    screenshotName,
  ].join('_');

  return `${file}.png`;
};

/**
 * Save screenshot
 *
 * @param  {WebDriver} driver         Selenium WebDriver
 * @param  {String}    testScript     name of file holds test cases
 * @param  {String}    screenshotName screen shot identity name
 * @return {String}                   file name
 */
const saveScreenshot = async(driver, testScript, screenshotName) => {
  const base64png = await driver.takeScreenshot();
  const file = await getImagePath(driver, testScript, screenshotName);
  await writeFile(path.join(DEFAULT_SCREENSHOT_PATH, file), new Buffer(base64png, 'base64'));

  // expose screenshot information
  debug(`- screenshot saved: ${file}`);
  console.log(`[[ATTACHMENT|${file}]]`);

  return file;
};

/**
 * Get default Selenium WebDriver
 *
 * @param  {String}    browserType  browser type, can be: chrome, firefox
 * @return {WebDriver} driver       Selenium WebDriver
 */
const getDefaultDriver = async(browserType) => {
  if (!browserType) {
    browserType = 'firefox';
  }
  const browser = browserType === 'chrome' ? chrome : firefox;

  // define Logging Preferences
  const loggingPrefs = new logging.Preferences();
  loggingPrefs.setLevel(logging.Type.BROWSER, logging.Level.ALL);
  loggingPrefs.setLevel(logging.Type.CLIENT, logging.Level.ALL);
  loggingPrefs.setLevel(logging.Type.DRIVER, logging.Level.ALL);
  loggingPrefs.setLevel(logging.Type.PERFORMANCE, logging.Level.ALL);
  loggingPrefs.setLevel(logging.Type.SERVER, logging.Level.ALL);

  // configure ServiceBuilder
  const service = new browser.ServiceBuilder();
  if (browserType === 'firefox') {
    service.enableVerboseLogging(true);
  } else if (browserType === 'chrome') {
    service.loggingTo('./logs/chrome-service.log')
      .enableVerboseLogging();
  }
  service.build();

  // configure Options
  const options = new browser.Options()
    .setLoggingPrefs(loggingPrefs);
  if (browserType === 'firefox') {
    options.setPreference('dom.disable_beforeunload', true);
    // options.setBinary('/Applications/IBM Firefox.app/Contents/MacOS/firefox');
    // options.setPreference('marionette', true)
    // .setPreference('marionette.logging', 'ALL');
  } else if (browserType === 'chrome') {
    // options.setChromeBinaryPath('/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary');
    options.setChromeLogFile('./logs/chrome-options.log');
    options.addArguments('--no-sandbox', '--disable-gpu', '--allow-insecure-localhost', '--disable-dev-shm-usage', '--disable-popup-blocking');
  }
  // use headless mode
  options.headless();

  // define Capabilities
  const capabilities = browserType === 'chrome' ? Capabilities.chrome() : Capabilities.firefox();
  capabilities.setLoggingPrefs(loggingPrefs)
    .setAcceptInsecureCerts(true);

  // init webdriver
  let driver = await new Builder()
    .forBrowser(browserType)
    .withCapabilities(capabilities);
  if (browserType === 'firefox') {
    driver = driver.setFirefoxOptions(options).setFirefoxService(service);
  } else if (browserType === 'chrome') {
    driver = driver.setChromeOptions(options).setChromeService(service);
  }
  driver = driver.build();

  return driver;
};

/**
 * Helper function to login to MVD
 *
 * @param {WebDriver} driver    Selenium WebDriver
 * @param {String}    url       MVD URL
 * @param {String}    username  login username
 * @param {String}    password  login password
 */
const loginMVD = async(driver, url, username, password) => {
  // load MVD login page
  debug('loading login page');
  await driver.get(url);
  try {
    await driver.wait(
      async() => {
        const loginButton = await getElement(driver, '#\\#loginButton', true);
        if (loginButton) {
          return true;
        }

        await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
        return false;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT
    );
  } catch (e) {
    const errName = e && e.name;
    if (errName === 'TimeoutError') {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      await saveScreenshot(driver, testName, 'logon-mvd-loginbutton');

      expect(errName).to.not.equal('TimeoutError');
    } else {
      expect(e).to.be.null;
    }
  }
  debug('login form is ready');

  const loginForm = await getElement(driver, 'form.login-form');
  expect(loginForm).to.be.an('object');
  // fill in login form
  const usernameInput = await getElement(loginForm, 'input#usernameInput');
  expect(usernameInput).to.be.an('object');
  await usernameInput.clear();
  await usernameInput.sendKeys(username);
  const passwordInput = await getElement(loginForm, 'input#passwordInput');
  expect(passwordInput).to.be.an('object');
  await passwordInput.clear();
  await passwordInput.sendKeys(password);
  // submit login
  const loginButton = await getElement(driver, '#\\#loginButton');
  expect(loginButton).to.be.an('object');
  await loginButton.click();
  debug('login button clicked');
  // wait for login error or successfully
  try {
    await driver.wait(
      async() => {
        let result = false;

        let error = await getElementText(driver, 'p.login-error');
        if (error !== false) {
          error = error.trim();
          if (error && error !== '&nbsp;') {
            debug('login error message returned: %s', error);
            // authentication failed, no need to wait anymore
            result = true;
          }
        }

        if (!result) {
          const loginPanel = await getElement(driver, 'div.login-panel');
          const isDisplayed = await loginPanel.isDisplayed();
          if (!isDisplayed) {
            debug('login panel is hidden, login should be successfully');
            result = true;
          }
        }

        await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
        return result;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT
    );
  } catch (e) {
    const errName = e && e.name;
    if (errName === 'TimeoutError') {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      await saveScreenshot(driver, testName, 'logon-mvd-error');

      expect(errName).to.not.equal('TimeoutError');
    } else {
      expect(e).to.be.null;
    }
  }
  debug('login successfully');

  // make sure we are not hitting login error
  let error = await getElementText(driver, 'p.login-error');
  expect(error).to.be.a('string');
  error = error.trim();
  expect(error).to.be.oneOf(['', '&nbsp;']);
  debug('login error message is ok');
};

/**
 * Get multiple elements by css selector
 *
 * @param  {WebDriver|WebElement} driver          Selenium WebDriver or parent WebElement
 * @param  {String}               selector        css selector
 * @param  {Boolean}              checkDisplayed  optional, if verify the 1st element is visible
 * @return {Array}                                array of Selenium WebElement
 */
const getElements = async(driver, selector, checkDisplayed) => {
  const elements = await driver.findElements(By.css(selector));
  if (!elements[0]) {
    debug(`[getElements] cannot find "${selector}"`);
    return false;
  }
  debug(`[getElements] find ${elements.length} of "${selector}"`);
  if (!checkDisplayed) {
    return elements;
  }

  // check if element is visible
  const isDisplayed = await elements[0].isDisplayed();
  if (!isDisplayed) {
    return false;
  }
  debug('[getElements]     and the first element is displayed');

  return elements;
};

/**
 * Get element by css selector
 *
 * This method won't throw NoSuchElementError like Selenium WebDriver.findElement()
 *
 * @param  {WebDriver|WebElement} driver          Selenium WebDriver or parent WebElement
 * @param  {String}               selector        css selector
 * @param  {Boolean}              checkDisplayed  optional, if verify the 1st element is visible
 * @return {WebElement|Boolean}                 Selenium WebElement or false if not found
 */
const getElement = async(driver, selector, checkDisplayed) => {
  const elements = await getElements(driver, selector, checkDisplayed);
  return elements[0] || false;
};

/**
 * Get element text by css selector
 *
 * This method won't throw NoSuchElementError like Selenium WebDriver.findElement()
 *
 * @param  {WebDriver}      driver          Selenium WebDriver
 * @param  {String}         selector        css selector
 * @param  {Boolean}        checkDisplayed  optional, if verify the 1st element is visible
 * @return {String|Boolean}                 text of Selenium WebElement or false if element is not found
 */
const getElementText = async(driver, selector, checkDisplayed) => {
  const element = await getElement(driver, selector, checkDisplayed);
  if (!element) {
    return false;
  }
  const text = await element.getText();
  return text;
};

/**
 * Wait until elements with css selector are loaded
 *
 * NOTE: This method may exit with driver.wait timeout.
 *
 * @param  {WebDriver}  driver    Selenium WebDriver
 * @param  {String}     selector  css selector
 * @param  {WebElement} parent    optional, parent element where to find css selector
 * @return {Array}                array of Selenium WebElement if loaded
 */
const waitUntilElements = async(driver, selector, parent) => {
  let elements;

  if (!parent) {
    parent = driver;
  }

  try {
    await driver.wait(
      async() => {
        const elementsDisplayed = await getElements(parent, selector);
        if (elementsDisplayed) {
          elements = elementsDisplayed;
          return true;
        }

        await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
        return false;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT
    );
  } catch (e) {
    const errName = e && e.name;
    if (errName === 'TimeoutError') {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      await saveScreenshot(driver, testName, 'wait-until-elements');

      expect(errName).to.not.equal('TimeoutError');
    } else {
      expect(e).to.be.null;
    }
  }
  debug(`[waitUntilElements] find ${elements.length} of "${selector}"`);

  return elements;
};

/**
 * Wait until element with css selector are removed from web page
 *
 * NOTE: This method may exit with driver.wait timeout.
 *
 * @param  {WebDriver}  driver    Selenium WebDriver
 * @param  {String}     selector  css selector
 * @param  {WebElement} parent    optional, parent element where to find css selector
 * @return {Boolean}              true if the element cannot be found
 */
const waitUntilElementIsGone = async(driver, selector, parent) => {
  if (!parent) {
    parent = driver;
  }

  await driver.sleep(500);
  try {
    await driver.wait(
      async() => {
        const elementsDisplayed = await getElement(parent, selector, false);
        if (!elementsDisplayed) {
          return true;
        }

        await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
        return false;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT
    );
  } catch (e) {
    const errName = e && e.name;
    if (errName === 'TimeoutError') {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      await saveScreenshot(driver, testName, 'wait-until-element-is-gone');

      expect(errName).to.not.equal('TimeoutError');
    } else {
      expect(e).to.be.null;
    }
  }
  await driver.sleep(500);

  return true;
};

/**
 * Wait until element with css selector is loaded
 *
 * NOTE: This method may exit with driver.wait timeout.
 *
 * @param  {WebDriver}          driver    Selenium WebDriver
 * @param  {String}             selector  css selector
 * @param  {WebElement}         parent    optional, parent element where to find css selector
 * @return {WebElement|Boolean}           Selenium WebElement or false if not found
 */
const waitUntilElement = async(driver, selector, parent) => {
  const elements = await waitUntilElements(driver, selector, parent);

  return (elements && elements[0]) || false;
};

/**
 * Wait until iframe with css selector is loaded, and switch context to the iframe
 *
 * NOTE: This method may exit with driver.wait timeout.
 *
 * @param  {WebDriver}          driver          Selenium WebDriver
 * @param  {String}             iframeSelector  css selector
 * @param  {WebElement}         parent          optional, parent element where to find css selector
 * @return {WebElement|Boolean}                 Selenium WebElement or false if not found
 */
const waitUntilIframe = async(driver, iframeSelector, parent) => {
  const iframe = await waitUntilElement(driver, iframeSelector, parent);
  if (iframe) {
    await driver.switchTo().frame(iframe);
  }

  return iframe;
};

/**
 * Launch MVD application by name
 *
 * @param  {WebDriver}  driver   Selenium WebDriver
 * @param  {String}     appName  application name
 */
const launchApp = async(driver, appName) => {
  debug(`[launchApp] launching ${appName}`);
  await driver.switchTo().defaultContent();

  // find start icon
  const menu = await getElement(driver, 'rs-com-launchbar-menu');
  const menuIcon = await getElement(menu, '.launchbar-menu-icon');

  // popup menu
  await menuIcon.click();
  await driver.sleep(1000);

  // find the app icon
  const popup = await getElement(driver, 'rs-com-launchbar-menu .launch-widget-popup');
  const menuItems = await getElements(popup, '.launch-widget-row');
  let app;
  for (let item of menuItems) {
    const itemTitle = await getElement(item, 'p');
    const text = await itemTitle.getText();
    debug(`[launchApp] found menu item ${text}`);
    if (text === appName) {
      app = item;
      break;
    }
  }
  expect(app).to.not.be.undefined;
  debug(`[launchApp] found ${appName}: ${app}`);

  // start app
  if (app) { // this check is not neccessary but SonarQube reports it as major bug
    await app.click();
  }
};

/**
 * Find application among MVD windows by name
 *
 * @param  {WebDriver}          driver   Selenium WebDriver
 * @param  {String}             appName  application name
 * @return {WebElement|Boolean}          Selenium WebElement of the app viewport or false if cannot find the application
 */
const locateApp = async(driver, appName) => {
  await driver.switchTo().defaultContent();

  // find all app windows
  const windows = await waitUntilElements(driver, 'rs-com-window-pane rs-com-mvd-window');

  let appWin;
  // locate the app window
  for (let win of windows) {
    const caption = await win.findElements(By.css('.border-box-sizing .heading .caption'));
    if (caption[0]) {
      const text = await caption[0].getText();
      if (text === appName) {
        // app window launched
        appWin = win;
        break;
      }
    }
  }
  if (!appWin) {
    debug(`[locateApp] cannot find app ${appName} in ${windows.length} windows`);
    return false;
  }

  // find the app body
  const body = await waitUntilElement(driver, '.border-box-sizing .body com-rs-mvd-viewport', appWin);

  return body;
};

/**
 * Find and switch to iframe application context
 *
 * @param  {WebDriver}  driver    Selenium WebDriver
 * @param  {String}     appName   application name
 * @param  {Array}.     contexts  array of css selectors
 */
const switchToIframeAppContext = async(driver, appName, contexts) => {
  debug('[switchToIframeAppContext] started');
  const app = await locateApp(driver, appName);
  for (let i in contexts) {
    debug(`[switchToIframeAppContext] - ${i}: ${contexts[i]}`);
    if (i === 0) {
      await waitUntilIframe(driver, contexts[i], app);
    } else {
      await waitUntilIframe(driver, contexts[i]);
    }
  }
  debug('[switchToIframeAppContext] done');
};

/**
 * Save screenshot then switch back to iframe application context
 *
 * @param  {Object}    testcase       Mocha test case context object
 * @param  {WebDriver} driver         Selenium WebDriver
 * @param  {String}    testScript     name of file holds test cases
 * @param  {String}    screenshotName screen shot identity name
 * @param  {String}    appName        application name
 * @param  {Array}.    contexts       array of css selectors
 */
const saveScreenshotWithIframeAppContext = async(testcase, driver, testScript, screenshotName, appName, contexts) => {
  debug('[saveScreenshotWithIframeAppContext] started');
  await driver.switchTo().defaultContent();
  const file = await saveScreenshot(driver, testScript, screenshotName);
  addContext(testcase, file);
  await switchToIframeAppContext(driver, appName, contexts);
  debug('[saveScreenshotWithIframeAppContext] done');
};

// export constants and methods
module.exports = {
  PRE_INSTALLED_APPS,
  PRE_PINNED_APPS,
  DEFAULT_PAGE_LOADING_TIMEOUT,
  DEFAULT_ELEMENT_CHECK_INTERVAL,
  DEFAULT_SCREENSHOT_PATH,
  MVD_IFRAME_APP_CONTEXT,
  MVD_IFRAME_APP_CONTENT,

  saveScreenshot,
  getDefaultDriver,
  getElements,
  getElement,
  getElementText,
  waitUntilElements,
  waitUntilElement,
  waitUntilElementIsGone,
  waitUntilIframe,
  loginMVD,
  launchApp,
  locateApp,
  switchToIframeAppContext,
  saveScreenshotWithIframeAppContext,
};
