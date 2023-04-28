## Manifest Metadata

Zowe's releases are composed of several individual components which are built in other repositories, by other Zowe squads, and in different formats. `manifest.json.template` defines which components are included into official build, where they're located in remote registries, and some general information regarding the current build of Zowe.

The manifest file includes:

- [General Information](#general-information)
- [Build Information](#build-information)
- [Binary Dependencies](#binary-dependencies)
- [Source Dependencies (Provenance)](#source-dependencies)
- [Container Image Dependencies](#image-dependencies)
- [Deprecated Fields](#deprecated-fields)

### General information

These information are represented in these properties: `name`, `version`, `description`, `license` and `homepage`.

### Build information

These information includes details when building the Zowe artifact. During build process, `manifest.json.template` will be converted to `manifest.json` and the template variables like `{BUILD_COMMIT_HASH}` will be filled in with real value. The modified `manifest.json` will be placed into root folder of Zowe build.

Here is an example of build information after build, you can find it in the `manifest.json` file from every Zowe build:

```
  "build": {
    "branch": "staging",
    "number": "202",
    "commitHash": "dad00f0a9c45f34bfbe3ec56a8443f2e818e59f4",
    "timestamp": "1568205429441"
  },
```

The above build information means this Zowe build is from `staging` branch build #202, git commit hash is [dad00f0a9c45f34bfbe3ec56a8443f2e818e59f4](https://github.com/zowe/zowe-install-packaging/commit/dad00f0a9c45f34bfbe3ec56a8443f2e818e59f4). Build time is `1568205429441`, which means `Wed Sep 11 2019 08:37:09 GMT-0400 (Eastern Daylight Time)`.

### Binary Dependencies

`binaryDependencies` section defines how many components will be included into the binary build. Each component has an unique ID, which hints where the pipeline should pick up the component artifact. Also for each the component, it defines which version will be included into the build.

Here is an example of component definition:

```
    "org.zowe.explorer.jobs": {
      "version": "~0.2.8-STAGING",
      "explode": "true"
    }
```

`org.zowe.explorer.jobs` is the component ID, which also tell the pipeline to pick the component from Artifactory path `<repo>/org/zowe/explorer/jobs/`. `version` defines which version we should pick. In this case, we should pick the max version matches `0.2.*-STAGING` and `>= 0.2.8-STAGING`. So version `0.2.10-STAGING` is a good match if it exists.

For details of **how to define a component**, please check examples and explanations from https://zowe.github.io/jenkins-library/jenkins_shared_library/artifact/JFrogArtifactory.html#interpretArtifactDefinition(java.lang.String,%20java.util.Map,%20java.util.Map).

### Source Dependencies

`sourceDependencies` section defines how the component binary matches to the Zowe github repository, branch or tag. It is grouped by `componentGroup`. For example, `Zowe Application Framework` componentGroup includes all repositories related it and listed in `entries` section.

One example component entry looks like:

```
  {
    "repository": "imperative",
    "tag": "v2.4.9"
  }
```

This means the Zowe build is using https://github.com/zowe/imperative repository tag [v2.4.9](https://github.com/zowe/imperative/tree/v2.4.9).

**Please note, this section may not reflect the correct value for non-formal-release.** Only for formal releases, we will update these sections to match the correct repository tags.

To check for each release, what source code from repositories will be used, you can:

- go to https://github.com/zowe/zowe-install-packaging,
- click on [?? releases](https://github.com/zowe/zowe-install-packaging/releases),
- find the release name. For example [v1.4.0](https://github.com/zowe/zowe-install-packaging/releases/tag/v1.4.0),
- click on the tag name on the left. In the above case, it shows [v1.4.0](https://github.com/zowe/zowe-install-packaging/tree/v1.4.0),
- find and check file `manifest.json.template`. In the above case, it links to [v1.4.0/manifest.json.template](https://github.com/zowe/zowe-install-packaging/blob/v1.4.0/manifest.json.template).
- check the `sourceDependencies` section. In the above case, it's line #96.
- In the above example, you will see Zowe release v1.4.0 is using https://github.com/zowe/imperative repository tag [v2.4.9](https://github.com/zowe/imperative/tree/v2.4.9).

### Image Dependencies

### Deprecated Fields
