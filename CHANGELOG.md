# Change Log

All notable changes to the Zowe Installer will be documented in this file.

## `1.14.0`
<!--Add the PR or issue number to the entry if applicable.-->
### New features and enhancements

- Added the fingerprint tool (script and files) to verify the authenticity of the contents of ROOT_DIR ([#1316](https://github.com/zowe/zowe-install-packaging/pull/1316)).  Reference fingerprint files for prior releases were uploaded as a single PAX file ([#1553](https://github.com/zowe/zowe-install-packaging/pull/1553)).

### Bug fixes


## `1.13.0`

#### Minor enchancements/defect fixes
- Updated zowe-configure-instance upgrade to update ROOT_DIR [#1414](https://github.com/zowe/zowe-install-packaging/pull/1414)
- Update port validation logic to reduce false negatives [#1399](https://github.com/zowe/zowe-install-packaging/pull/1399)
- Update install and configure to tolerate ZERT Network Analyzer better [#1124](https://github.com/zowe/zowe-install-packaging/pull/1124)



## `1.12.0`

- Edit default plugin references to point to $ROOT_DIR env var

2020-05-08 Timothy Gerstel <tgerstel@rocketsoftware.com>

  - Set up SSO in a standard install of Zowe via new environment variables set
in zowe-setup-certificates.env

  - Automate conversion of APIML public key and storage within PKCS#11 token

- When the hostname cannot be resolved use the IP address instead.  This covers the scenario when the USS `hostname` command returned a system name that wasn't externally addressable, such as `S0W1.DAL-EBIS.IHOST.COM` which occurs on an image created from the z/OS Application Developers Controlled Distribution (ADCD).
- Separate zss component from app-server component
