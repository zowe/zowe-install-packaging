# Change Log

All notable changes to the Zowe Installer will be documented in this file.

## '1.14.0'

#### Minor enchancements/defect fixes
- Allow multiple domains (names/IP Addresses) when generating certificates [#1511](https://github.com/zowe/zowe-install-packaging/issues/1511).  This also includes SMP/E `HOLDDATA` for the affect function `Zowe Configuration`
- Documentation changed so that SZWEAUTH PDSE load library members should not be copied elsewhere, but instead the original instalation target SZWEAUTH PDSE should be APF authorized and used as runtime load library.  This also includes SMP/E `HOLDDATA` for the affected function `STC JCL` as well as changes to the documentation chapters [Installing and configuring the Zowe cross memory server (ZWESISTC)](https://docs.zowe.org/stable/user-guide/configure-xmem-server.html#step-1-copy(-the-cross-memory-proclib-and-load-library) and [nstalling and starting the Zowe started task (ZWESVSTC)](https://docs.zowe.org/stable/user-guide/configure-zowe-server.html).  A new documentation chapter [Installing and configuring Zowe z/OS components using scripts](https://docs.zowe.org/stable/user-guide/scripted-configure-server.html) has been added.
- Allow verification of a Zowe driver for authenticity/provenance.     ,  and for pre-1.14 releases available separately as [#1552](https://github.com/zowe/zowe-install-packaging/issues/1552).
- Inclusion of z/OSMF workflows for Zowe z/OS configuration [#1527](https://github.com/zowe/zowe-install-packaging/issues/1527)
- Warning check if `ZWESVSTC` runs under user ID `IZUSVR` [#1534](https://github.com/zowe/zowe-install-packaging/issues/1534)


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
