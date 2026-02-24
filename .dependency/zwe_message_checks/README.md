# ZWE CLI Message Checks

Run `npm install` in this directory and then `node index.js` to scan error messages defined in the ZWE command line and error messages used by the ZWE tool, whether in shell scripts or typescript source.

The tool leverages some code in the [Zowe Doc Generation Automation](../zwe_doc_generation/). It will output multiple evaluations of our message use within ZWE, including unused messages, mismatched message IDs and contents, and disparities between message definitions and their use in ZWE sources.

This is not 100% accurate in all cases, particularly when comparing message content, as the capture of message content from the sources is simplistic and therefore incomplete, but it is a decent starting point. If message content capture in the sources improves, the accuracy of the tool can improve with it. Alternatively, we may prefer a design where ZWE sources pull messages from a common library based on the message definitions, avoiding the need to check their usage in source code altogether.

If the tool finds errors it is confident in, it will return quit with exitCode=1, which should trigger a failure in Github Actions. 
