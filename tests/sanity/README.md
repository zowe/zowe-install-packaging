# Zowe Sanity Test

Perform fast sanity test on a Zowe instance to see if Zowe service is running as expected.

Contents of this readme:

- [Programming Language And Main Testing Method](#programming-language-and-main-testing-method)
- [Run Test Cases On Your Local](#run-test-cases-on-your-local)
  * [Prepare NPM Packages](#prepare-npm-packages)
  * [Prerequisite For E2E UI Test](#prerequisite-for-e2e-ui-test)
  * [Start Test](#start-test)
- [General Guideline For Adding Test Cases](#general-guideline-for-adding-test-cases)
  * [Test Cases Directory Structure](#test-cases-directory-structure)
  * [Output Debugging Information](#output-debugging-information)
  * [Add Extra Information To HTML Result](#add-extra-information-to-html-result)
  * [Save Screenshot And Add To HTML Report](#save-screenshot-and-add-to-html-report)
- [Add More Test Cases](#add-more-test-cases)
  * [Add CLI Test Cases](#add-cli-test-cases)
  * [Add API Test Cases](#add-api-test-cases)
  * [Add E2E UI Test Cases](#add-e2e-ui-test-cases)
  * [Add Installation (SSH) Test Cases](#add-installation-ssh-test-cases)
- [Troubleshooting](#troubleshooting)


## Programming Language And Main Testing Method

- Node.js, with recommended [v8.x LTS](https://nodejs.org/docs/latest-v8.x/api/index.html)
- [Mocha](https://mochajs.org/)
- [Chai Assertion Library - BDD Expect/Should](https://www.chaijs.com/api/bdd/)
- [Selenium WebDriver](https://seleniumhq.github.io/selenium/docs/api/javascript/index.html)

_Please note, currently package.json doesn't include *Babel JS*, which means all test cases are written in vanilla node.js v8.x supported syntax. ES2017 and ES2018 syntax are not fully supported. Please check [Node.js Support](https://node.green/) website._

## Run Test Cases On Your Local

### Prepare NPM Packages

We have a dependency on NPM registry of Zowe Artifactory. You will need to configure npm registry to be `https://zowe.jfrog.io/zowe/api/npm/npm-release/`. This should have been handled by the `.npmrc` file in this folder.

With correct npm registry, you can run `npm install` to install all dependencies.

### Prerequisite For E2E UI Test

By default, E2E UI test cases are launched by Selenium with Firefox driver. If you run test cases on your local, you need Firefox installed.

The existing test cases are tested on Firefox v61.0.2 which is pre-installed in Jenkins Docker Slaves. In theory, the e2e test cases should be able to run on Firefox v53 and above.

### Start Test

Example command:

```
ZOWE_ROOT_DIR=/path/to/zowe \
  ZOWE_INSTANCE_DIR=/path/to/zowe/instanceDir \
  SSH_HOST=test-server \
  SSH_PORT=12022 \
  SSH_USER=********* \
  SSH_PASSWD=********* \
  ZOSMF_PORT=10443 \
  ZOWE_DS_MEMBER=ZWESVSTC \
  ZOWE_JOB_PREFIX=ZWE \
  ZOWE_ZLUX_HTTPS_PORT=8544 \
  ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT=7554 \
  ZOWE_EXPLORER_JOBS_PORT=8545 \
  ZOWE_EXPLORER_DATASETS_PORT=8547 \
  npm test
```

## General Guideline For Adding Test Cases

### Test Cases Directory Structure

- All test cases are located in `test` directory.
- Test cases are grouped as sub-directories:
  * `test/cli`: includes all CLI test cases,
  * `test/e2e`: includes all E2E UI test cases,
  * `test/explorer`: includes all Zowe Explorer API test cases,
  * `test/install`: includes all test cases validating Zowe installation.

### Output Debugging Information

Test case can use [debug](https://www.npmjs.com/package/debug) package to output debugging information. For example:

```javascript
// declare debug
const debug = require('debug')('zowe-sanity-test:my-testsuite:my-testcase');

// output debug information
debug('result:', result);
```

To show debugging information on your local, you can add `DEBUG=zowe-sanity-test:*` to the test command:

```
ZOWE_ROOT_DIR=/path/to/zowe \
  ZOWE_INSTANCE_DIR=/path/to/zowe/instanceDir \
  SSH_HOST=test-server \
  SSH_PORT=12022 \
  SSH_USER=********* \
  SSH_PASSWD=********* \
  ZOSMF_PORT=10443 \
  ZOWE_DS_MEMBER=ZWESVSTC \
  ZOWE_JOB_PREFIX=ZWE \
  ZOWE_ZLUX_HTTPS_PORT=8544 \
  ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT=7554 \
  ZOWE_EXPLORER_JOBS_PORT=8545 \
  ZOWE_EXPLORER_DATASETS_PORT=8547 \
  DEBUG=zowe-sanity-test:* \
  npm test
```

In Jenkins Pipeline, we have pre-defined build parameter `TEST_CASE_DEBUG_INFORMATION`, which can enable to show debugging information. For example, give `TEST_CASE_DEBUG_INFORMATION` value `zowe-sanity-test:*` will show all test debugging information.

### Add Extra Information To HTML Result

We use [mochawesome](https://www.npmjs.com/package/mochawesome) to render HTMl test report. To show more test information, like CLI result, we can use [addContext](https://www.npmjs.com/package/mochawesome#addcontexttestobj-context). For example:

```javascript
// declare addContext
const addContext = require('mochawesome/addContext');

it('my test case', async function() {
  // ...

  // I have a variable result want to show in HTML report
  addContext(this, {
    title: 'my test result',
    value: result
  });

  // ...
});
```

### Save Screenshot And Add To HTML Report

There is helper function `saveScreenshot` located in [test/e2e/utils.js](test/e2e/utils.js). You can use this function to save screenshot and add to HTML Report. For example:

```javascript
// declare mochawesome/addContext
const addContext = require('mochawesome/addContext');
// declare test name
const testName = path.basename(__filename, path.extname(__filename));
// declare saveScreenshot
const { saveScreenshot } = require('./utils');

it('my test case', async function() {
  // ...

  // save screenshot
  const file = await saveScreenshot(driver, testName, 'my-screen-shot-name');
  addContext(this, file);

  // ...
});
```

If you are testing IFrame Application, you need to set correct driver **content** to save screenshot, otherwise you will only have part of the whole screen be captured. In this case, you may use `saveScreenshotWithIframeAppContext`. For Example,

```javascript
// declare mochawesome/addContext
const addContext = require('mochawesome/addContext');
// declare test name
const testName = path.basename(__filename, path.extname(__filename));
// declare saveScreenshotWithIframeAppContext
const { saveScreenshotWithIframeAppContext } = require('./utils');
// which app you are testing
const APP_TO_TEST = 'My Application';

it('my test case', async function() {
  // ...

  // save screenshot
  await saveScreenshotWithIframeAppContext(this, driver, testName, 'my-screen-shot-name', APP_TO_TEST, ['rs-com-mvd-iframe-component > iframe', 'iframe#atlasIframe']);

  // ...
});
```

`saveScreenshotWithIframeAppContext` will switch to **default content** before taking a screenshot:

```javascript
  await driver.switchTo().defaultContent();
```

Then switch back to IFrame Application content by locating the application iFrame window we are testing:

```javascript
  await switchToIframeAppContext(driver, appName, contexts);
```

## Add More Test Cases

### Add CLI Test Cases

This section will provide brief example how to add new CLI test cases.

- Use `createDefaultZOSMFProfile` function to create dafault z/OSMF profile with name `defaultZOSMFProfileName`.
- Use `execZoweCli` to issue a CLI command and get `result`.
- Verify `result.stdout`, or `result.stderr`.

For example:

```javascript
// import chai expect
const expect = require('chai').expect;
// import createDefaultZOSMFProfile & execZoweCli
const { execZoweCli, defaultZOSMFProfileName, createDefaultZOSMFProfile } = require('./utils');

describe('my test suite', function() {
  before('ensure profile', async function() {
    // ensure z/OSMF profile existence
    await createDefaultZOSMFProfile(
      zosmf_host,
      zosmf_port,
      username,
      password
    );
  });

  it('should succeed on my command', async function() {
    // issue my CLI command
    const result = await execZoweCli(`zowe ?????? --response-format-json --zosmf-profile ${defaultZOSMFProfileName}`);

    // execZoweCli should return an object with stdout and stderr properties
    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    // we choose to --response-format-json, then stdout should be a valid JSON string
    const res = JSON.parse(result.stdout);
    expect(res).to.be.an('object');
  });
});
```

### Add API Test Cases

This section will provide brief example how to add new API test cases. Below examples uses [axios](https://www.npmjs.com/package/axios) to make HTTP requests.

- Create axios object by using `axios.create`.
- Make request and verify response

For example:

```javascript
// import chai expect
const expect = require('chai').expect;
// import axios
const axios = require('axios');
let REQ;

describe('my test suite', function() {
  before('prepare axios', function() {
    // create axios object, set base url
    REQ = axios.create({
      baseURL: 'https://my.host-name.com:api-port/',
      timeout: 30000,
    });
  });

  it('should succeed on my api call', function() {
    const req = {
      method: 'get',
      url: '/path/to/my/api',
      // optional basic authentication
      auth: {
        username,
        password,
      }
    };

    return REQ.request(req)
      .then(function(res) {
        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);

        // ...
      });
  });
});
```

### Add E2E UI Test Cases

This section will provide brief example how to add new E2E UI test cases.

- Call helper function `getDefaultDriver` to get default Selenium webdriver.
- Login to MVD with function `loginMVD`.
- Launch the application you are testing with `launchApp`.
- Use `waitUntilElement` to wait for a certain element to be visible.
- You can also do click, input.
- Check [test/e2e/utils.js](test/e2e/utils.js) to find more helper functions like:
  * `getElements`
  * `getElement`
  * `getElementText`
  * `waitUntilElements`
  * `waitUntilElement`
  * `waitUntilElementIsGone`
  * `waitUntilIframe`
  * `locateApp`
  * `switchToIframeAppContext`
  * `saveScreenshot`
  * `saveScreenshotWithIframeAppContext`

For example:

```javascript
// import chai expect
const expect = require('chai').expect;
// import helper functions
const {
  getDefaultDriver,
  waitUntilElement,
  loginMVD,
  launchApp,
} = require('./utils');
let driver;
const APP_TO_TEST = 'JES Explorer';

describe('my test suite', function() {
  before('prepare webdriver and login to mvd', async function() {
    // init webdriver
    driver = await getDefaultDriver();

    // login to MVD
    await loginMVD(
      driver,
      'https://my.host-name.com:zlux-port/',
      username,
      password
    );
  });

  it('should succeed on loading application', async function() {
    // load app
    await launchApp(driver, APP_TO_TEST);
    const app = await locateApp(driver, APP_TO_TEST);
    expect(app).to.be.an('object');

    // wait until mvd viewport is ready
    const viewport = await waitUntilElement(driver, 'rs-com-mvd-window .body com-rs-mvd-viewport');
    expect(viewport).to.be.an('object');
  });
});
```

If you want to see the browser, you will need to disable the headless mode and let the browser wait for you.

To disable headless mode, you can find the line `options.headless();` in [test/e2e/utils.js](test/e2e/utils.js) `getDefaultDriver` function and comment it out. With this change, you can see the browser window popout from your computer when you start the e2e tests.

Then you can hold the test case to make it wait for you.

```javascript
  // ...

  // hold my test case for 10 minutes so I can inspect on browser window
  await driver.sleep(10 * 60 * 1000);

  // ...
```

### Add Installation (SSH) Test Cases

This section will provide brief example how to add new test cases to run SSH command on testing server.

- We have created a helper class `ssh-helper.js` to assist with new ssh tests.
- You should follow the pattern of establishing a connection, using one of the test methods, then making sure the connection is correctly disposed.

For example:

```javascript
const sshHelper = require('./ssh-helper');

describe('my test suite', function() {
  before('establish ssh connection', async function() {
    await sshHelper.prepareConnection();
  });

  it('should succeed on my command', async function() {
    await sshHelper.executeCommandWithNoError('pwd');
  });

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
```

## Troubleshooting

### Error 'ZOWE_ROOT_DIR' is not recognized as an internal or external command

When you start test on Windows, you may see this error: `'ZOWE_ROOT_DIR' is not recognized as an internal or external command, operable program or batch file.`

**Solution:**

Run `npm install -g cross-env` and then run command

```
cross-env ZOWE_ROOT_DIR=/path/to/zowe ZOWE_INSTANCE_DIR=/path/to/zowe/instanceDir SSH_HOST=test-server SSH_PORT=12022 SSH_USER=********* SSH_PASSWD=********* ZOSMF_PORT=10443 ZOWE_DS_MEMBER=ZWESVSTC ZOWE_JOB_PREFIX=ZWE ZOWE_ZLUX_HTTPS_PORT=8544 ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT=7554 ZOWE_EXPLORER_JOBS_PORT=8545 ZOWE_EXPLORER_DATASETS_PORT=8547 npm test
```

to start test.

### Error: The geckodriver.exe executable could not be found on the current PATH

You may see this error if you run e2e test cases on Windows:

```
   Error: The geckodriver.exe executable could not be found on the current PATH. Please download the latest version from https://github.com/mozilla/geckodriver/releases/ and ensure it can be found on your PATH.
    at findGeckoDriver (node_modules\selenium-webdriver\firefox.js:427:11)
    at new ServiceBuilder (node_modules\selenium-webdriver\firefox.js:516:22)
    at getDefaultDriver (test\e2e\utils.js:128:19)
    at Context.<anonymous> (test\e2e\test-01-login.js:41:20)
```

This is because it cannot find `geckodriver.exe`. This file is already installed under `node_modules\geckdriver`.

**Solution:**

Run this command to add it to `PATH`: `set "PATH=.\node_modules\geckodriver;%PATH%"`.

### Error: SessionNotCreatedError: Unable to find a matching set of capabilities

You may receive this error when you run e2e test cases:

```
   SessionNotCreatedError: Unable to find a matching set of capabilities
    at Object.throwDecodedError (node_modules\selenium-webdriver\lib\error.js:550:15)
    at parseHttpResponse (node_modules\selenium-webdriver\lib\http.js:542:13)
    at Executor.execute (node_modules\selenium-webdriver\lib\http.js:468:26)
    at <anonymous>
    at process._tickCallback (internal/process/next_tick.js:189:7)
```

This could be caused by incompatible GechoDriver and Firefox. Here is more detail explanation on [Marionette and GeckoDriver](https://stackoverflow.com/a/43920453). You may find these lines in [test/e2e/utils.js](test/e2e/utils.js) and try your combinations by changing binary path and marionette option.

```javascript
  if (browserType === 'firefox') {
    // options.setBinary('/Applications/IBM Firefox.app/Contents/MacOS/firefox');
    // options.setPreference('marionette', true)
    //   .setPreference('marionette.logging', 'ALL');
  } else if (browserType === 'chrome') {
```
