# Zowe CICD Test Instructions using Github Actions

This guide will list all possible zowe install test scenarios and how you should input into Github Actions workflow inputs.  

Currently we support three testing z/OS servers:

- zzow02 (ACF2)
- zzow03 (Top Secret/TSS)
- zzow04 (RACF)

Testing pipeline is running tests in parallel. The workflow will try to acquire the resource lock if available. If the resource lock is occupied, the workflow will wait until the lock is succesfully acquired.

Workflow trigger is at [cicd-test](https://github.com/zowe/zowe-install-packaging/actions/workflows/cicd-test.yml)

## Inputs

### Test File and Running Server

- This input is mandatory, expecting the test file path you want to run, and also on which server. Test path is relative to `tests/installation/src/__tests__`  
- You must put test path first, followed by server enclosed in brackets. If multiple tests are planned in a single workflow, separate them in semi-colon.  
- The following regular expression will be used to check against your input:

  ```
  ^([A-Za-z0-9/-]+\.ts\((zzow02|zzow03|zzow04)(,(zzow02|zzow03|zzow04))*\))(;[A-Za-z0-9/-]+\.ts\((zzow02|zzow03|zzow04)(,(zzow02|zzow03|zzow04))*\))*$
  ```

- Examples:
  - `basic/install-ptf.ts(zzow03)`
  - `basic/install.ts(zzow03,zzow02);extended/keyring.ts(zzow02,zzow03)`
  - `extended/certificates/verify-certificates.ts(zzow04);basic/install-ext.ts(zzow02,zzow03,zzow04)`
  - and etc

- Below is a list of supported installation tests and all possible servers you can use, you can also choose to run on one or two servers:  
  - Convenience pax build: `basic/install.ts(zzow02,zzow03,zzow04)`
  - SMPE FMID: `basic/install-fmid.ts(zzow02,zzow03,zzow04)`
  - SMPE PTF: `basic/install-ptf.ts(zzow02,zzow03,zzow04)`
  - Tech preview docker test: `basic/install-docker.ts(zzow04)`
  - Extensions test: `basic/install-ext.ts(zzow03)`
  - Keyring test: `extended/keyring.ts(zzow02,zzow03,zzow04)`
  - z/OS node v8 test: `extended/node-versions/node-v8.ts(zzow02,zzow03,zzow04)`
  - z/OS node v12 test: `extended/node-versions/node-v12.ts(zzow02,zzow03,zzow04)`
  - z/OS node v14 test: `extended/node-versions/node-v14.ts(zzow02,zzow03,zzow04)`
  - Non strict verify external cerntitiate test: `extended/certificates/nonstrict-verify-external-certificate.ts(zzow02)`
  - Install PTF two times: `extended/install-ptf-two-times.ts(zzow04)`
  - Generate API documentation: `basic/install-api-gen.ts(zzow04)`

### Custom Zowe Artifactory Pattern

- This input is optional, it is designed to take in customized zowe.pax or zowe-smpe.zip path on artifactory.  
- If not specified, default will be `libs-snapshot-local/org/zowe/*{branch-name}*.pax`. If workflows detects you are running SMPE related tests (install-fmid.ts or install-ptf.ts or install-ptf-two-times.ts), default will select `libs-snapshot-local/org/zowe/*zowe-smpe*{branch-name}*.zip`. Note that `{branch-name}` will be substituted with the branch where you triggered your workflow. Then the latest uploaded artifact will be used.
- If specified, you must put valid path on artifactory, otherwise your input will be ignored.
  - for customized pax, your pax file must contain `zowe` and end with `.pax`
  - for customized smpe, your smpe file must contain `zowe-smpe` and end with `.zip`
- If you are running smpe related tests and other tests in a single workflow and wish to overwrite both pax file and smpe zip file, you can include both paths in this input as well, and separated them by semi-colon. Note that only two paths are accepted because there should be no more than two customized paths here (only pax and smpe). More than two paths input here will result in validation check failure.
- This regular expression will be used to check against your input: 
  ```
  ^([^;]+)(;[^;]+)?$
  ```
- Examples:
  - `my/path/zowe-123.pax`
  - `my/path/zowe-223.pax;my/path/zowe-smpe-464.zip`
- Unacceptable examples (will be ignored):
  - `my/path/zw-3455.pax`
  - `my/path/smpe-342.pax;`
  - `my/path/zowe-containerization-456.zip`
  - `my/path/zowe-164.pax;my/path/zowe-smpe-644.zip;my/path/smpe-877.pax`

### Custom Zowe CLI Artifactory Pattern

- This input is optional, it is designed to take in customized Zowe CLI path on artifactory.  
- If not specified, default will be `libs-snapshot-local/org/zowe/cli/zowe-cli-package/*/zowe-cli-package-1*.zip`. Then the latest uploaded artifact will be used.

### Custom Extension List

- This input is prefilled with `sample-node-api;sample-trial-app` to test [sample-node-api](https://github.com/zowe/sample-node-api) and [sample-trial-app](https://github.com/zowe/sample-trial-app) projects. In normal circumstances, you probably don't need to modify the prefilled value here.
- By default, the extension artifact pattern is using format `libs-snapshot-local/org/zowe/{ext-name}/*/{ext-name}-*.pax` where `{ext-name}` will be processed and substituted from this input. Then the latest uploaded artifact will be used.
- Optionally, you can customized your extension artifact path. Customized path should be put after the extension name and a colon, eg. `sample-node-api:my/new/path/sample-node-api-cus.pax`. If multiple extensions are included, make sure to separate them in semi-colon.
- The following regular expression will be used to check against your input
  ```
  ^([^;:]+(:[^;:]+)*)(;[^;:]+(:[^;:]+)*)*$
  ```
- Examples:
  - `sample-node-api`
  - `sample-node-api:my/new/path/sample-node-api-cus.pax;sample-trial-app`
  - `sample-node-api:my/new/path/sample-node-api-cus.pax;sample-trial-app:my/old/path/cust.pax;sample-new-zowe-ext`
- This input is only honored when you are running `install-ext.ts` test.

### Custom Zowe Tech Preview Docker Artifactory Pattern

- This input is optional, it is designed to take in customized technical preview docker path on artifactory.  
- If not specified, default will be `libs-snapshot-local/org/zowe/*server-bundle.amd64*{branch-name}*.tar` where `{branch-name}` will be substituted with the branch where you triggered your workflow. Then the latest uploaded artifact will be used. 
- This input is only honored when you are running `install-docker.ts` test.
