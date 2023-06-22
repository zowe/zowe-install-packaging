# Zowe CICD Test Instructions using Github Actions

This guide will describe how you should input into Github Actions workflow inputs.

Currently we support three testing z/OS servers:

- zzow02 (ACF2)
- zzow03 (Top Secret/TSS)
- zzow04 (RACF)

Testing pipeline is running tests in parallel. The workflow will try to acquire the resource lock if available. If the resource lock is occupied, the workflow will wait until the lock is succesfully acquired.

Workflow trigger is at [cicd-test](https://github.com/zowe/zowe-install-packaging/actions/workflows/cicd-test.yml)

## Inputs

### Choose Test Server

- This input is a choice, and it's mandatory.  
- You can choose from one of `zzow02`, `zzow03`, `zzow04`, `zzow02,zzow03,zzow04` (if you want to run the test on all zzow servers), or `Any zzow servers` (pick any zzow servers, potentially help reduce wait time)
- Default is `Any zzow servers`

### Choose Install Test

- This input is a choice and it's mandatory.  
- You can choose from the list below:
  - Convenience Pax
  - SMPE FMID
  - SMPE PTF
  - Tech Preview Docker
  - Extensions
  - Keyring
  - z/OS node v14
  - z/OS node v16
  - Non-strict Verify External Certificate
  - Install PTF twice
  - VSAM Caching storage method
  - Infinispan Caching storage method
  - Generate API documentation
  - Zowe Nightly Tests
  - Zowe Release Tests
- Note that `Zowe Release Tests` is generally run by the DevOps engineer during RC phase. It includes most of the tests above across all three zzow servers.  
- Generally speaking, all tests listed above can be run on any zzow server.
- For the tests automatically triggered by your PR build, it is running `Convenience Pax` test on any zzow server.
- The time it takes to run each test see [appendix](#appendix)

### Custom Zowe Artifactory Pattern or Build Number

Background: CICD testing relies on a `zowe.pax` or `zowe-smpe.zip` (for SMPE install). Thus it is important for a user to tell the pipeline which `zowe.pax` or `zowe-smpe.zip` (for SMPE install) shall be picked up and utilized; this input serves this purpose.

- This input is optional, it is expecting either:
  - any `zowe.pax` or `zowe-smpe.zip` path/pattern on jfrog artifactory (note: the file path/pattern can be on any other branch as long as it exists)
  - or a specific **build number** on current running branch

- If you leave this input blank,
  - the pipeline will look for the most up to date build in your running branch, and use a default zowe artifactory pattern to search the exact artifactory file path. Default pattern will be either:
    - `libs-snapshot-local/org/zowe/*zowe*{branch-name}*.pax` for almost all tests except SMPE install related.  
    - or `libs-snapshot-local/org/zowe/*zowe-smpe*{branch-name}*.zip` when running SMPE related install test (SMPE FMID, SMPE PTF or Install PTF twice).
  - Note that `{branch-name}` will be substituted with the current running branch.
  - **Attention**: when you run SMPE related install tests, if the latest build does not include packaging SMPE (ie. no `zowe-smpe.zip` is found in the latest build), this pipeline will fail and throw an error. A bit of context: all zowe build will produce zowe.pax; other installation method artifacts like SMPE or docker artifact is on demand and can be skipped when building. Therefore, if you run a SMPE install test and not specifying this input, you are telling the pipeline to use latest build and the pipeline will assume the latest build contains the SMPE artifact. Error mentioned earlier rises when the latest build does not have SMPE artifact.

- If this input is specified,
  - you can input either a build number or a **valid existing** path/pattern on artifactory, otherwise an error will be thrown.
    - Build number must be an integer and must exist on the current running branch.
    - for path/pattern:
      - your pax file must contain `zowe` and end with `.pax`
      - or your smpe file must contain `zowe-smpe` and end with `.zip`
      - You can include `*` in the pattern as well, so that if multiple artifacts matches the pattern, last uploaded one will be picked up.
  - **Attention**: when you run SMPE related install tests, we will firstly find out which branch and what build number your specified zowe-smpe.zip is associated with. Same thing if specifying a build number. If it is not the latest build on this branch, the pipeline will throw a warning to indicate that you are possibly testing against an outdated code because there are newer builds after this current build (you specified). Pipeline will continue eventually. Warning will be something like this:

    ```
    I see that you are trying to grab an older SMPE build 1891 on zowe-install-packaging :: feature2.
    However just be aware that there are more code changes (newer builds) after 1891, which is 1915.
    You should always test latest code on your branch unless you want to compare with older builds for regression.
    ```

- Special note when running `Tech Preview Docker` test:
  - Background: Docker test will rely on `zowe.pax`, so the pipeline is actually looking on the same build of where `zowe.pax` is made to find out if a docker artifact exists. The docker artifact pattern will be like `server-bundle.amd64*.tar`.  
  - If you don't specify anything in this input, the to-be-used docker artifact will be from latest build number on current branch. If the latest build doesn't have docker artifact, pipeline will throw an error and fail.
  - If you specify a `zowe.pax` here (note that here must be a pax, because if you specify a `smpe.zip` here while running docker test, pipeline should already fail beforehand), the pipeline will find out which branch (we call it *processed branch*) and what build number (call it *processed build number*) your specified `zowe.pax` is, then look for the docker artifact on this build. The pipeline will continue but when the *processed build number* is not the latest on the *processed branch*, a warning will be given to indicate that you are possibly testing against an outdated code because there are newer builds after this current *processed build*. Warning will be something like this:
    ```
    I see that you are trying to grab an older docker build 101 on zowe-install-packaging/feature1.
    However just be aware that there are more code changes (newer builds) after 101, which is 105.
    You should always test latest code on your branch unless you want to compare with older builds for regression.
    ```

- Examples:
  - `my/path/zowe-123.pax`
  - `my/path/hello-zowe-smpe-223-20211210.zip`
  - `184`
- Unacceptable examples:
  - `my/path/zw-3455.pax`
  - `my/path/smpe-342.pax;`
  - `my/path/zowe-containerization-456.zip`
  - `68485345` (not exist)

### Custom Zowe CLI Artifactory Pattern

- This input is optional, it is designed to take in customized Zowe CLI path on artifactory.  
- If not specified, this pipeline will search the latest artifact using the pattern `libs-snapshot-local/org/zowe/cli/zowe-cli-package/*/zowe-cli-package-1*.zip`.

### Custom Extension List

- This input is pre-filled with `sample-node-api;sample-trial-app` to test [sample-node-api](https://github.com/zowe/sample-node-api) and [sample-trial-app](https://github.com/zowe/sample-trial-app) projects. In normal circumstances, you probably don't need to modify the pre-filled value here.
- By default, the extension artifact search pattern is using format `libs-snapshot-local/org/zowe/{ext-name}/*/{ext-name}-*.pax` where `{ext-name}` will be processed and substituted from this input (as an example above, `sample-node-api`). Then the latest uploaded artifact will be used.
- Optionally, you can customized your extension artifact path. Customized jfrog artifactory path should exist, be valid, and enclosed in brackets and put after the extension name, eg. `sample-node-api(my/new/path/sample-node-api-cus.pax)`. A pattern contains `*` is also supported, which the latest artifact will be picked up. If multiple extensions are included, make sure to separate them by semi-colon. In addition to the artifactory path/pattern, you can also put a full http URL to any other remote location that points to an extension pax here.
- The following regular expression will be used to check against your input

  ```
  ^([^;()]+(\([^;()]+\))*)(;[^;()]+(\([^;()]+\))*)*$
  ```

- Examples:
  - `sample-node-api`
  - `sample-node-api(my/new/path/sample-node-api-cus.pax);sample-trial-app`
  - `sample-node-api(my/new/path/sample-node-api-cus.pax);sample-trial-app(https://private-repo.org/new-zowe-ext/123.pax);sample-new-zowe-ext`
- This input is only honored when you are running `Extension` test.  

## Zowe Release Tests (DevOps only)

When running CICD integration tests during RC stage, the following string will be parsed into the Github Actions matrix. As a result, a total of 19 independent jobs will be spawned.

```
basic/install.ts(zzow02,zzow03,zzow04);basic/install-ptf.ts(zzow02,zzow03,zzow04);basic/install-docker.ts(zzow04);basic/install-ext.ts(zzow03);extended/keyring.ts(zzow02,zzow03,zzow04);extended/node-versions/node-v14.ts(zzow02,zzow03,zzow04);extended/node-versions/node-v16.ts(zzow02,zzow03,zzow04);extended/certificates/nonstrict-verify-external-certificate.ts(zzow02);extended/caching-storages/infinispan-storage.ts
```

Total elapsed time when running in parallel is approximately 3.5 hours on paper idealy if all parallel jobs are executing at the same time. In reality, from numerous tests performed, total elapsed time is around 4 hours.  

## Appendix

Selected test running elapsed time:
| Test | Elapsed time on each server |
| ---- | ------------ |
| Convenience Pax | 27m |
| SMPE PTF | 47m |
| Tech Preview Docker | 22m |
| z/OS node v16 | 25m |
| z/OS node v14 | 25m |
| Keyring | 27m |
| Non-strict Verify External Certificate | 25m |
| Extensions | 35m
| Infinispan caching storage | 30m
| Zowe Release Tests | 4hr  

