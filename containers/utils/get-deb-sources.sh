#!/bin/bash
# SPDX-License-Identifier: MIT

### This will be copied into and run from within the working container.
### Do not run it on your local system!

# generate list of currently-installed packages, in format
# to be used for pulling sources
dpkg-query -f '${Package}=${Version}\n' -W > /root/packages.list

# back up and modify sources.list to add deb-src sources
cp /etc/apt/sources.list /etc/apt/sources.list.backup
sed 's/deb /deb-src /' /etc/apt/sources.list > /etc/apt/sources-deb-src.list
cat /etc/apt/sources-deb-src.list >> /etc/apt/sources.list

# update so apt sees the deb-src sources
apt-get update

# create and change into sources directory
mkdir -p /root/sources
cd /root/sources

# and get the sources
xargs -a /root/packages.list apt-get source --download-only

# tar them up and clean up
cd /root
tar -czvf ./sources.tar.gz ./sources
rm -rf ./sources

# restore the original sources.list
mv /etc/apt/sources.list.backup /etc/apt/sources.list
