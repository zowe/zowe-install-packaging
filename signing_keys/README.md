# Code Signing Public Keys

This folder has GPG code signing public keys which are used to sign official Zowe releases.

## Available Keys

### KEYS.matt

- ID: `BE7CCF980C6045AB1A35CBC6DC8633F77D1253C3`
- Short ID: `DC8633F77D1253C3`
- Algorithm: `rsa4096`
- Name: `Matt Hogstrom (CODE SIGNING KEY) <matt@hogstrom.org>`
- Download URL: https://raw.githubusercontent.com/zowe/zowe-install-packaging/master/signing_keys/KEYS.matt

### KEYS.jack

- ID: `88685BABBDF1B06A1F70C5AEADA180F59191D808`
- Short ID: `ADA180F59191D808`
- Algorithm: `rsa4096`
- Name: `Jack Tiefeng Jia (CODE SIGNING KEY) <jack-tiefeng.jia@ibm.com>`
- Download URL: https://raw.githubusercontent.com/zowe/zowe-install-packaging/master/signing_keys/KEYS.jack

## How to Verify Official Releases With Signature File

For each official Zowe release, it comes with a `.asc` signature file. After you download the official build, in the post download page, there is section `Verify Hash and Signature of Zowe Binary` - `Step 2 - Verify With Signature File`, which includes the link to the `.asc` file. Or you can fetch the `.asc` with this url pattern: `https://d1xozlojgf8voe.cloudfront.net/builds/<version>/zowe-<version>.pax.asc`. For example, download link for version v1.4.0 is https://d1xozlojgf8voe.cloudfront.net/builds/1.4.0/zowe-1.4.0.pax.asc.

You also need the public key in this folder: https://github.com/zowe/zowe-install-packaging/tree/master/signing_keys.

Then you can verify the build following these steps:

- Import the public key with command: `gpg --import <KEY>`. The `<KEY>` should either be the key file list in [Available Keys](#available-keys) section. For example: `gpg --import KEYS.jack`.
- Optional, if you never use gpg before, you can generate your personal key first: `gpg --gen-key`. This is required if you want to sign the imported key. Otherwise, please proceed to next step.
- Optional, sign the downloaded public key with command: `gpg --sign-key <KEY-SHORT-ID>`. For example: `gpg --sign-key ADA180F59191D808`.
- Verify the file with command: `gpg --verify zowe-<version>.pax.asc zowe-<version>.pax`. For example: `gpg --verify zowe-1.4.0.pax.asc zowe-1.4.0.pax`.
- Optional, you can remove the imported key with command: `gpg --delete-key <KEY-SHORT-ID>`. For example: `gpg --delete-key ADA180F59191D808`.

If you see output like this that matches the info in the public key you downloaded you can be assured that the binary file you have has come from the Zowe project.

```
gpg: Signature made Thu 07 Mar 2019 02:36:19 PM EST
gpg:         using RSA key ADA180F59191D808
gpg: Good signature from "Jack Tiefeng Jia (CODE SIGNING KEY) " [full]
```

*Note: the key ID and signature shown above are depended on which key is used to sign the build.*
