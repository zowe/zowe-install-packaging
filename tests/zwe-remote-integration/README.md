# Zowe System-Integration Test

Runs integration-style tests for the `zwe` command line utility on a backend system. These tests rely largely on the `zwe` tool's dry-run capabilities in combination with its JCL output to create tests that can be used to assert functional accuracy with minimal impact on the target system, improving their execution time and avoiding disruptions between runs. Tests which do not modify system state are grouped under the `(SHORT)` label within test suites. There are some tests which must modify system state to determine if `zwe` would behave as expected, and these are grouped under `(LONG)` within test suites. `(LONG)` tests must clean up after themselves, but any unplanned termination of the test runner could leave the system in a dirty state. In these situations, manual intervention is required on the backend system, or repeated, failing runs of `(LONG)` tests should eventually clean up the system state.

## Programming Languages, Tools, Pre-Reqs

- Node.js, with recommended [v20.x LTS](https://nodejs.org/docs/latest-v20.x/api/index.html)
- Makes heavy use of [@zowe/cli](https://github.com/zowe/zowe-cli) Node SDKs
- [Jest](https://jestjs.io/)

## Running Tests

In order to run these tests, you must first modify the [test configuration](./resources/test_config.yml) according to the instructions in that file.

Once complete, run `npm install` and `npm run build` in this directory. The build action will determine if there's a de-sync between the schemas in the repository's [schema directory](../../schemas/) and the project's type inferences built on those schemas [here](./src/config/ZoweYamlType.ts). 

To run `(SHORT)` designated tests, from this directory as-is, or run with the env's exported beforehand:

```
TEST_CONFIG_FILE=`pwd`/resources/custom_config_you_created.yml \ 
  npm run test:ci
```

To run both `(SHORT)` and `(LONG)` tests, run with:

```
 TEST_CONFIG_FILE=`pwd`/resources/custom_config_you_created.yml \
   npm run test:extended
```

To run a custom subset of tests, e.g. only the `init-mvs` tests marked `(SHORT)`, use `npx` and run with:

```
 TEST_CONFIG_FILE=`pwd`/resources/custom_config_you_created.yml \ 
  npx jest --testNamePattern="init-mvs.*SHORT.*"
```

## Testing Behaviors and Constructs

These tests currently work by deploying a working `zwe` command line environment to a remote system, using the `zwe` component as-is from this repo; i.e. not from a pre-built PAX file. All of `zwe`'s dependencies will be set in place on the remote system as part of setup using this repository's manifest.json.template file. If you want to test `zwe` with a custom version of any of it's dependencies outside this repo, e.g. `configmgr`, then update the [`manifest.json.template`](../../manifest.json.template) to point to a different binaryDependency version, and when the test suite runs, it will download and use that version of the dependency.

Test cases should be runnable on any backend system. Most cases rely on capturing `zwe` stdout, including JCL content, which can vary based on the backend system `zwe` is running on. To address this output with embedded backend-specific information, all test commands are run through a custom [RemoteTestRunner class](./src/zos/RemoteTestRunner.ts), which handles the execution of a `zwe` command, the collection of stdout and stderr, and the masking of sensitive or system-specific data which may appear in the output. The `RemoteTestRunner` additionally contains utility functions that are useful for developing test cases.

The RemoteTestRunner should be initialized and scoped in a `beforeAll()` block, closed in an `afterAll()` block, and called within test suites. RemoteTestRunner has a `postTest()` action which should be called in `afterEach()` blocks to collect any applicable spool output. If you use any of the RemoteTestRunner's utility functions, like `removeUssFileForTest()`, then `postTest()` is also responsible for restoring the file at the end of a test block. The `RemoteTestRunner` returns a combined stream of stdout and stderr, as this is how data is presented to end-users invoking `zwe` in a USS environment.

Most `zwe` commands require some `zowe.yaml` to be present with configuration information on the backend system. This test suite makes simple, type-checked `zowe.yaml` objects available by integrating the zowe schema into typescript directly. Where field specifications are missing in the schema, the zowe.yaml objects will no longer have typing information available. Configuration YAML should be initialized and reset in `beforeAll()` and `beforeEach()`, so test cases can freely modify the config YAML without impacting other test cases. 

For commands which modify the backend system, as in `(LONG)` tests, a way to cleanup datasets, files, or revert system actions is required. Currently, this framework has a [TestFileActions class](./src/zos/TestFileActions.ts) which can be used to delete files created during a test. The test author must specify which files need removal; the suite cannot auto-detect created files or datasets. Test file removal typically happens in the `afterEach()` code block. If this class could not delete a given file or dataset, it will try again during teardown so long as `remote_teardown` is set in the test configuration file, and if removal fails again or `remote_teardown` is set to false, a list of potentially lingering datasets and files will be present in the `.build/lingering_ds.txt` file.

A simple test setup looks like the following:

```typescript
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
  });

  afterAll(async () => {
    testRunner.shutdown();
  })

  it('some test', async () => {
    cfgYaml.zowe.setup.runtimeDirectory = '/some/other/directory'; // this is type-checked!
    const result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
    result.stdout        // raw stdout+stderr
    result.cleanedStdout // masked stdout+stderr - used in snapshots
    result.rc            // command return code
  })
```


Using the `TestFileActions` to cleanup datasets:

```typescript
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupFiles = [];

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFilesActions.deleteAll(cleanupFiles); // try to delete everything. 404's (not found) count as deleted.
    cleanupFiles = [] // reset list to cleanup
  });

  afterAll(async () => {
    testRunner.shutdown();
  })

  it('(LONG): some test', async () => {
    cfgYaml.zowe.setup.runtimeDirectory = '/some/other/directory'; // this is type-checked!
    const result = await testRunner.runZweTest(cfgYaml, 'init mvs');
    cleanupFiles.push({
      type: FileType.DS_NON_CLUSTER
      name: cfgYaml.zowe.setup.dataset.authPluginLib
    });
    result.stdout        // raw stdout+stderr
    result.cleanedStdout // masked stdout+stderr
    result.rc            // command return code
  })
```

Sample using `RemoteTestRunner#postTest()` to modify files pre-test and restore them post-test. The removed file, `defaults.yaml`, will be restored by `testRunner.postTest()`. It can be optionally restored by `testRunner.restoreFiles()` if preferred.

```typescript
...
  afterEach(async () => {
    await testRunner.postTest();
  });

  it('sample - missing defaults.yaml', async () => {
    // dir relative to 'runtimeDirectory', i.e. root working dir on remote
    await testRunner.removeUssFileForTest('files/defaults.yaml'); 
    const res = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run'); // will fail RC!=0
    // ....assertions
    // await testRunner.restoreFiles() here will also work if you prefer it for clarity
  })

```

### Working with Zowe.yaml in Tests

The Zowe YAML file used during tests is created using the [example-zowe.yaml](../../example-zowe.yaml) in this repository in combination with the information provided in the [test configuration file](./resources/test_config.yml). This creates a basic working Zowe YAML for most test cases, though customization is required for testing different code paths and scenarios. You can modify the Zowe YAML for test cases one of two ways: either using the object directly in code, or by overlaying a YAML document on top of the YAML file.

Accessing the Zowe YAML directly is easy enough:

```typescript
let cfgYaml = ZoweConfig.getZoweYaml();
cfgYaml.zowe.setup.dataset.parmlib = 'some.other.parmlib';
cfgYaml.zowe.useConfigmgr = false;
cfgYaml.zOSMF.host = 'doesnt-exist.anywhere.cloud';
cfgYaml.zowe.certificate.keystore.type = 'JCERACFKS';
```

Overlaying the Zowe YAML with another YAML document is supported and useful for cases where large blocks of related changes are required and more easily managed in an external YAML file. There is template support available for these YAML files, with template values filled out by the `REMOTE_SYSTEM_INFORMATION` tracked within the test framework. This makes it simple to access fields such as `host`, `storclas`, `volume`, `dataset`, `ussTestDir`, and more, within external YAML files. A full list of supported variables can be found by reviewing `REMOTE_SYSTEM_INFORMATION` in the [TestConfig](./src/config/TestConfig.ts) class. Templated YAML requires use of `{@` and `@}` template brackets to avoid collision with template support in configmgr. 

Sample YAML with templates:
```yaml
zowe:
  setup:
    dataset:
      jcllib: ${{ zowe.setup.dataset.prefix }}.JCLLIB
    vsam:
      mode: NONRLS
      volume: {@ volume @}
      storageClass: {@ storclas @}
```

Loading the YAML and overlaying it on top of the framework's base YAML:
```typescript
const cfgYaml = ZoweConfig.getZoweYaml();
const yamlDir = path.resolve('path', 'to', 'custom', 'yaml');
const combinedYaml = ZoweConfig.loadAndOverlay(cfgYaml, yamlDir, 'my.custom.yaml'); // loads and renders
// run test with combinedYaml...  await testRunner.runZweTest(combinedYaml, ...);
```

The load and overlay steps can be separated:

```typescript
const cfgYaml = ZoweConfig.getZoweYaml();
const yamlDir = path.resolve('path', 'to', 'custom', 'yaml');
const customYaml = ZoweConfig.loadZoweYaml(yamlDir, 'my.custom.yaml', false); // don't render - any unquoted '{@ @}' will cause YAML load failures
customYml.zowe.certificate.keystore.type = 'SOMETHINGELSE'; // the custom YAML object comes with type-checking
const combinedYaml = ZoweConfig.overlayYaml(cfgYaml, customYaml); // overlay later
// run test with combinedYaml... await testRunner.runZweTest(combinedYaml, ...);
```

Zowe ships a baked-in `defaults.yaml` which must exist for `zwe` commands to run successfully. This framework uses the repository's [defaults](../../files/defaults.yaml), but a custom `defaults.yaml` can be provided to the test runner, which handles the backend configuration changes and restoration automatically:

```typescript
const cfgYaml = ZoweConfig.getZoweYaml();
const customDefaults = ZoweConfig.loadZoweYaml(yamlDir, 'custom.defaults.yaml', false); 
const result = testRunner.runZweTestWithDefaults(cfgYaml, customDefaults, 'init stc --dry-run');
// handle results
// should restore state before running another test
await testRunner.restoreFiles(); // postTest() will also work in the afterEach() block
```

### Reviewing Test Output

This integration framework tries to make it easy to review test output without overwhelming volumes of output containing unrelated information. 

For every test run, along with every `testRunner.postTest()` action, a new sub-directory is created with pertinent output data captured from the backend system. These sub-directories are present under the `.build/output` directory [(link)](./.build/output/), are created on a per-test basis using a truncated test name, and each contain further sub-directories with spool content (if applicable as in `(LONG)` tests) as well as the final Zowe YAML used to run the test on the backend. The final Zowe YAML is especially helpful in debug scenarios, as the file can be re-uploaded manually to the backend system so zwe commands can be re-run exactly as they happen in the test cases.

Console output from the tests are not currently captured in these output sub-directories, but that output is available in the test case itself as part of terminal output and snapshot data.

i.e.: 

```typescript
const result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
expect(result.cleanedOutput).toMatchSnapshot(); // cleanedOutput has stdout+stderr
```

