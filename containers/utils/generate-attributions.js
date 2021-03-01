/*
This program and the accompanying materials are
made available under the terms of the Eclipse Public License v2.0 which accompanies
this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html

SPDX-License-Identifier: EPL-2.0

Copyright Contributors to the Zowe Project.
*/

//images->0->image->layers->foreach->packages->name+copyright+proj_url+download_url
//layers is first-to-last
const fs = require('fs');

let parent = JSON.parse(fs.readFileSync('server-bundle.json')).images;
parent = parent[0].image;

let packages = [];

parent.layers.forEach((layer)=> {
  layer.packages.forEach((package)=> {
    if (package.copyright) {
      packages[package.name]=package;
    }
  });
});

let text = 'ATTRIBUTIONS\n\nThe following software is either included in the docker image or was used in making the docker image. Each piece of software is listed by name, version, website if known, and associated copyright text.\n\n';

let packagenames = Object.keys(packages);

packagenames.forEach((packagename)=> {
  let package = packages[packagename];
  text+= `\n----------------------------------------\n${package.name} version ${package.version}\n`
  if (package.proj_url) {
    website +=`\nWebsite: ${package.proj_url}`
  }
  else if (package.download_url) {
    website +=`\nWebsite: ${package.download_url}`
  }
  text+= `\n\nCopyright:\n${package.copyright}\n`
});

fs.writeFileSync('NOTICE.txt', text);
