#!/bin/sh
#
root=/bld/zowe

chmod 755 $(find $root -level 0 -type f) 2>&1
chtag -r  $(find $root -level 0 -type f) 2>&1

chmod 755 $(find $root/_new -level 0 -type f) 2>&1
chtag -r  $(find $root/_new -level 0 -type f) 2>&1

rm -r $root/_new/tmp 2>/dev/null