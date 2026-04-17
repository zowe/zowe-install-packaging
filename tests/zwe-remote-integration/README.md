# Zowe System-Integration Test

Runs integration-style tests for the `zwe` command line utility on a backend system. These tests rely largely on the `zwe` tool's dry-run capabilities in combination with its JCL output to create tests that can be used to assert functional accuracy with minimal impact on the target system, improving their execution time and avoiding disruptions between runs. Tests which do not modify system state are grouped under the `(SHORT)` label within test suites. There are some tests which must modify system state to determine if `zwe` would behave as expected, and these are grouped under `(LONG)` within test suites. `(LONG)` tests must clean up after themselves, but any unplanned termination of the test runner could leave the system in a dirty state. In these situations, manual intervention is required on the backend system, or repeated, failing runs of `(LONG)` tests should eventually clean up the system state.

## Suite coverage

Tests live under [`src/__tests__/`](./src/__tests__/). Highlights (paths are relative to that directory):

| Area | Focus |
|------|--------|
| [`init/`](./src/__tests__/init/) | `zwe init` flows: `mvs`, `generate`, `vsam`, `stc`, `certificate`, `apfauth`; includes **(LONG)** jobs where noted in each file |
| [`install/`](./src/__tests__/install/) | `zwe install` (dry-run and live JCL paths) |
| [`validate/`](./src/__tests__/validate/) | `zwe validate` (including port bind checks) |
| [`start-stop/`](./src/__tests__/start-stop/) | `zwe start` / `zwe stop` |
| [`migrate/`](./src/__tests__/migrate/) | `zwe migrate for kubernetes` (after `init certificate`) |
| [`config/`](./src/__tests__/config/) | `zwe config get`, `internal config set`, HA instance paths |
| [`internal/`](./src/__tests__/internal/) | `zwe internal start prepare` (z/OSMF scheme combinations, startup checks) |
| [`env/`](./src/__tests__/env/) | `.env` files produced under the workspace after `internal start prepare` (HA, masking) |
| [`launcher/`](./src/__tests__/launcher/) | Compare `.zowe-merged.yaml` from `zowe_launcher` vs `zwe` |
| [`version/`](./src/__tests__/version/) | `zwe version` and edge cases |
| [`support/`](./src/__tests__/support/) | `zwe support` (support package, z/OSMF, fingerprint stub) |
| [`features/`](./src/__tests__/features/) | Invalid YAML and expected return codes across several commands |
| [`unit/`](./src/__tests__/unit/) | Remote **configmgr** unit tests (`RunUnitTests`) and shell `update_zowe_yaml` (`UpdateYaml`) |
| [`init/canary.test.ts`](./src/__tests__/init/canary.test.ts) | Minimal connectivity smoke (`echo`, `zwe --help`) — **not** tagged `(SHORT)` (see [Running Tests](#running-tests)) |

The [`init/generate`](./src/__tests__/init/generate.test.ts) suite also defines a **`FLAKY`** block (job cancel/interrupt) that can disturb other work on the system if unrelated `ZWEGENER` jobs exist; it runs with `npm run test:extended` but not with the `(SHORT)`-only CI script.

## Programming Languages, Tools, Pre-Reqs

- Node.js, with recommended [v20.x LTS](https://nodejs.org/docs/latest-v20.x/api/index.html)
- Makes heavy use of [@zowe/cli](https://github.com/zowe/zowe-cli) Node SDKs
- [Jest](https://jestjs.io/)

## System Requirements

Your z/OS system must meet the following requirements:
- z/OS 2.5.0 or higher
- z/OSMF installed and configured with REST APIs enabled
- Java installation (17 or 21)
- Node.js installation (20 or higher)
- SDSF or another tool capable of running operator commands (e.g. Sysview, Omegamon)

### Disk space (approximate)

- ~300MB of free space in the target test directory (`remote_test_dir`)
- ~100MB of free space on the test volume and/or storage class (`test_volume`, optional `test_storclas`)

### Remote user (ACID) authorizations

#### MVS data sets

- **Broad ALTER/CONTROL (or your ESM equivalent) on `{test_ds_hlq}.ZWETEST.**`**: setup creates and loads multiple libraries; tests delete, rename, back up, and recreate data sets and members ([`src/globalSetup.ts`](./src/globalSetup.ts), [`RemoteTestRunner.removeDatasetForTest`](./src/zos/RemoteTestRunner.ts), [`install`](./src/__tests__/install/install.test.ts), [`init`](./src/__tests__/init/) suites).
- **`test_volume`** is required; **`test_storclas`** is optional and enables SMS-only cases in [`init/apfauth`](./src/__tests__/init/apfauth.test.ts).

#### JES / batch

With **`zowe.setup.jcl.enable: true`**, many flows **submit jobs** (non–dry-run `zwe install`, `zwe init generate`, `zwe init certificate`, `zwe init vsam`, `zwe init stc`, `zwe start` / `zwe stop`, `zwe support`, and related suites). The user must be able to **submit** those jobs, allow steps to **allocate and update** the test HLQ libraries (JCLLIB, PROCLIB, PARMLIB, and others), and **read job output** where spool collection is enabled.

#### Operator commands / SDSF (for LONG start/stop and typical `opercmd` use)

From [`bin/utils/opercmd.rex`](../../bin/utils/opercmd.rex) (RACF-oriented names; use ACF2 or Top Secret equivalents as appropriate):

- **OPERCMDS**: `MVS.MCSOPER.console`, `MVS.**`, `JES%.**` (and **OPERPARM AUTH** command groups if the EMCS path applies).
- **SDSF** (when using the SDSF REXX interface): profiles such as **`ISFOPER.SYSTEM`** and **`ISFCMD.ODSP.ULOG.jesx`** (JES name may differ).

Without these, **(LONG)** `zwe start` / `zwe stop` in [`start-stop`](./src/__tests__/start-stop/startstop.test.ts) is expected to fail; **(SHORT)** explicitly covers the stubbed SDSF case.

#### Network / ports

[`validate/config`](./src/__tests__/validate/config.test.ts) runs **`zwe validate port bind`** with ports shifted to reduce collisions; the user should be allowed to **bind** to those ports (typically non-reserved; no superuser bind should be required).

#### Additional Notes

- **JFrog** (`jfrog_user` / `jfrog_token` in [test configuration](./resources/test_config.yml)): required on the **machine that runs Jest** when `download_configmgr`, `download_zowe_tools`, and/or **`download_szwesamp`** (launcher/ZSS sample) are true. This runs from your local machine.
- **RACDCERT / key rings**: current **PKCS12** certificate tests ([`init/certificate`](./src/__tests__/init/certificate.test.ts)) do not exercise SAF key rings; if you switch to **JCERACFKS**, add the appropriate keyring and certificate profiles.

## Running Tests

In order to run these tests, you must first modify the [test configuration](./resources/test_config.yml) according to the instructions in that file.

Once complete, run `npm install` and `npm run build` in this directory. The build action will determine if there's a de-sync between the schemas in the repository's [schema directory](../../schemas/) and the project's type inferences built on those schemas [here](./src/config/ZoweYamlType.ts).

Jest is configured in [`jest.config.ts`](./jest.config.ts) with `globalSetup` / `globalTeardown`, a long default timeout, and JUnit output under [`reports/`](./reports/) when using the default reporters.

`npm run test:ci` runs Jest with `--testNamePattern='.*(SHORT).*'`, so **only tests whose full name contains the substring `(SHORT)`** are executed. That **excludes** the [`canary`](./src/__tests__/init/canary.test.ts) smoke tests, **`LONG`** tests, and the **`FLAKY`** block in [`init-generate`](./src/__tests__/init/generate.test.ts). Use `npm run test:extended` (or a custom `--testNamePattern`) when you need those.

To run `(SHORT)`-tagged tests, from this directory, or with the variable exported beforehand:

```sh
TEST_CONFIG_FILE="$(pwd)/resources/custom_config_you_created.yml" npm run test:ci
```

To run the full suite (including `(LONG)`, canary, and `FLAKY`):

```sh
TEST_CONFIG_FILE="$(pwd)/resources/custom_config_you_created.yml" npm run test:extended
```

To run a custom subset, e.g. only `init-mvs` tests marked `(SHORT)`:

```sh
TEST_CONFIG_FILE="$(pwd)/resources/custom_config_you_created.yml" \
  npx jest --testNamePattern='init-mvs.*SHORT.*'
```

## Testing Behaviors and Constructs

These tests currently work by deploying a working `zwe` command line environment to a remote system, using the `zwe` component as-is from this repo; i.e. not from a pre-built PAX file. All of `zwe`'s dependencies will be set in place on the remote system as part of setup using this repository's manifest.json.template file. If you want to test `zwe` with a custom version of any of it's dependencies outside this repo, e.g. `configmgr`, then update the [`manifest.json.template`](../../manifest.json.template) to point to a different binaryDependency version, and when the test suite runs, it will download and use that version of the dependency.

Test cases should be runnable on any backend system. Most cases rely on capturing `zwe` stdout, including JCL content, which can vary based on the backend system `zwe` is running on. To address this output with embedded backend-specific information, all test commands are run through a custom [RemoteTestRunner class](./src/zos/RemoteTestRunner.ts), which handles the execution of a `zwe` command, the collection of stdout and stderr, and the masking of sensitive or system-specific data which may appear in the output. The `RemoteTestRunner` additionally contains utility functions that are useful for developing test cases.

The RemoteTestRunner should be initialized and scoped in a `beforeAll()` block, closed in an `afterAll()` block, and called within test suites. RemoteTestRunner has a `postTest()` action which should be called in `afterEach()` blocks to collect any applicable spool output. If you use `removeUssFileOrDirForTest()` (or dataset helpers such as `removeDatasetForTest()`), then `postTest()` is also responsible for restoring the path at the end of a test block. Command helpers return **`stdout`** (raw console from the remote shell, analogous to what a user sees for `zwe` on USS) and **`cleanedStdout`** (masked for snapshots); see `TestOutput` in [`RemoteTestRunner.ts`](./src/zos/RemoteTestRunner.ts).

Other key APIs in RemoteTestRunner include:

- **`runRaw(command)`** — arbitrary USS command with the same masking behavior as `runZweTest`.
- **`uploadZoweYamlFromFile`**, **`downloadMaskedUssFilesMatching`**, **`downloadMaskedPdsMember`** — fixed YAML on disk or pull remote artifacts with masking applied.
- **`addCleanFn(fn)`** — register extra string transforms before built-in snapshot masking (for example normalizing ESM names).
- **`collectTestFile` / `collectTestContent`** — copy arbitrary local artifacts into `.build/output/.../other/` for post-run review.
- **`buildAndUploadUnitTests` + `runUnitTests`** — compile and run the configmgr JavaScript tests under [`src/__tests__/unit/__configmgr__/`](./src/__tests__/unit/__configmgr__/) on the remote system.
- **`maskSensitiveData`** — run the same cleaner used for `cleanedStdout` on arbitrary text.

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
    await TestFileActions.deleteAll(cleanupFiles); // try to delete everything. 404's (not found) count as deleted.
    cleanupFiles = []; // reset list to cleanup
  });

  afterAll(async () => {
    testRunner.shutdown();
  })

  it('(LONG): some test', async () => {
    cfgYaml.zowe.setup.runtimeDirectory = '/some/other/directory'; // this is type-checked!
    const result = await testRunner.runZweTest(cfgYaml, 'init mvs');
    cleanupFiles.push({
      type: FileType.DS_NON_CLUSTER,
      name: cfgYaml.zowe.setup.dataset.authPluginLib,
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
    await testRunner.removeUssFileOrDirForTest('files/defaults.yaml'); 
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
customYaml.zowe.certificate.keystore.type = 'SOMETHINGELSE'; // the custom YAML object comes with type-checking
const combinedYaml = ZoweConfig.overlayYaml(cfgYaml, customYaml); // overlay later
// run test with combinedYaml... await testRunner.runZweTest(combinedYaml, ...);
```

Zowe ships a baked-in `defaults.yaml` which must exist for `zwe` commands to run successfully. This framework uses the repository's [defaults](../../files/defaults.yaml), but a custom `defaults.yaml` can be provided to the test runner, which handles the backend configuration changes and restoration automatically:

```typescript
const cfgYaml = ZoweConfig.getZoweYaml();
const customDefaults = ZoweConfig.loadZoweYaml(yamlDir, 'custom.defaults.yaml', false); 
const result = await testRunner.runZweTestWithDefaults(cfgYaml, customDefaults, 'init stc --dry-run');
// handle results
// should restore state before running another test
await testRunner.restoreFiles(); // postTest() will also work in the afterEach() block
```

### Reviewing Test Output

This integration framework tries to make it easy to review test output without overwhelming volumes of output containing unrelated information.

For every test run, along with every `testRunner.postTest()` action, a new sub-directory is created with pertinent output data captured from the backend system. These sub-directories are present under the `.build/output` directory [(link)](./.build/output/), are created on a per-test basis using a truncated test name, and each contain further sub-directories with spool content (if applicable as in `(LONG)` tests), copies of the Zowe YAML (and defaults, when uploaded) used for that test, console output from the remote shell, and an **`other/`** folder for anything saved via `collectTestFile()` / `collectTestContent()`.

The YAML copies written under `yaml/` are especially helpful in debug scenarios, as a file can be re-uploaded manually to the backend system so `zwe` commands can be re-run exactly as they happen in the test cases.

Example snapshot assertion:

```typescript
const result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
expect(result.cleanedStdout).toMatchSnapshot();
```

