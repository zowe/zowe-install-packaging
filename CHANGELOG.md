# Change Log

All notable changes to the Zowe Installer will be documented in this file.

## Recent Changes

- When the hostname cannot be resolved use the IP address instead.  This covers the scenario when the USS `hostname` command returned a system name that wasn't externally addressable, such as `S0W1.DAL-EBIS.IHOST.COM` which occurs on an image created from the z/OS Application Developers Controlled Distribution (ADCD).
- Separate zss component from app-server component
