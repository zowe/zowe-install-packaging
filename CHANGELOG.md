# Change Log

All notable changes to the Zowe Installer will be documented in this file.
<!--Add the PR or issue number to the entry if available.-->
## `1.16.0`

### New features and enhancements
- Moved explorer-ui-server out of explorers into new `shared` folder under Zowe Runtime Directory. It involved following PRs (https://github.com/zowe/zowe-install-packaging/pull/1545), (https://github.com/zowe/explorer-jes/pull/207), (https://github.com/zowe/explorer-ui-server/pull/37). Thanks @stevenhorsman, @nakulmanchanda, @jackjia-ibm
- Created `zowe-setup-keyring-certificates.env` and removed the overloaded properties from `zowe-setup-certificates.env` to try and clarify the user experience when setting up certificates in the keyring and USS keystore modes. [#1603](https://github.com/zowe/zowe-install-packaging/issues/1603)


## `1.14.0`

### New features and enhancements
- Allow the user to verify the authenticity of a Zowe driver. The script `zowe-verify-authenticity.sh` will check that a Zowe `ROOT_DIR` for an installed release matches the contents for when that release was created, which assists with support and troubleshooting. To verify pre-1.14 releases, the script and its associated code are available [separately](https://github.com/zowe/zowe-install-packaging/blob/staging/files/fingerprint.pax) (see [#1552](https://github.com/zowe/zowe-install-packaging/issues/1552)). For more information, see the new topic [Verify Zowe Runtime Directory](https://docs.zowe.org/stable/troubleshoot/verify-fingerprint.html) that describes the operation of the script. 
- Allow multiple domains (names/IP Addresses) when generating certificates. This also includes SMP/E `HOLDDATA` for the affected function `Zowe Configuration`. [#1511](https://github.com/zowe/zowe-install-packaging/issues/1511)
- Included z/OSMF workflows for Zowe z/OS configuration. [#1527](https://github.com/zowe/zowe-install-packaging/issues/1527)
- Added warning if `ZWESVSTC` runs under user ID `IZUSVR`. [#1534](https://github.com/zowe/zowe-install-packaging/issues/1534)
- [Docs] Changed the documentation to say that SZWEAUTH PDSE load library members should not be copied elsewhere, but instead that the original installation target SZWEAUTH PDSE should be APF-authorized and used as the runtime load library.  This also includes SMP/E `HOLDDATA` for the affected function `STC JCL` as well as changes to topics [Installing and configuring the Zowe cross memory server (ZWESISTC)](https://docs.zowe.org/stable/user-guide/configure-xmem-server.html) and [Installing and starting the Zowe started task (ZWESVSTC)](https://docs.zowe.org/stable/user-guide/configure-zowe-server.html).  
- [Docs] Added a new topic [Installing and configuring Zowe z/OS components using scripts](https://docs.zowe.org/stable/user-guide/scripted-configure-server.html).

## `1.13.0`

#### Minor enhancements/defect fixes
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
