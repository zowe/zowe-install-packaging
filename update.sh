#!/bin/bash -e

function updateAll {
  updateModule "apiml"
  updateModule "common-java"
  updateModule "jobs"
  updateModule "files"
  updateModule "explorer-api-common"
}

function getArtifactId {
  module=$1
  case "${module}" in
    apiml)
      echo "g=org.zowe.apiml&a=api-catalog-services";;
    common-java)
      echo "g=org.zowe.apiml.sdk&a=common-java-lib-package";;
    jobs)
      echo "g=org.zowe.explorer.jobs&a=jobs-api-server";;
    files)
      echo "g=org.zowe.explorer.files&a=data-sets-api-server";;
    explorer-api-common)
      echo "g=org.zowe.explorer.api&a=explorer-api-common";;
    *)
      exit 1
  esac
}

function getComponentRegex {
  module=$1
  case "${module}" in
    apiml)
      echo "api-catalog|caching|discovery|gateway|org.zowe.apiml.api-catalog-package|org.zowe.apiml.discovery-package|org.zowe.apiml.gateway-package|org.zowe.apiml.caching-service-package|org.zowe.apiml.metrics-service-package|org.zowe.apiml.apiml-common-lib-package|org.zowe.apiml.sdk.apiml-sample-extension-package|org.zowe.apiml.cloud-gateway-package|api-layer";;
    common-java)
      echo "org.zowe.apiml.sdk.common-java-lib-package|common-java";;
    jobs)
      echo "jobs-api|jobs|org.zowe.explorer.jobs.jobs-api-package";;
    files)
      echo "files-api|data-sets|org.zowe.explorer.files.files-api-package";;
    explorer-api-common)
      echo "explorer-api-common";;
    *)
    exit 1
  esac
}

function getValue {
  module="$1"

  fieldRegex="\"$2\".*:.*\"(.*)\""
  moduleRegex="\"($(getComponentRegex "${module}"))\""

  selected=0
  while read -r line; do
    if [[ "${line}" =~ ${moduleRegex} ]]; then
      selected=1
    elif [[ "${line}" =~ :.*{ ]]; then
      selected=0
    fi

    if [[ ${selected} -eq 1 ]]; then
      if [[ "${line}" =~ ${fieldRegex} ]]; then
        echo ${BASH_REMATCH[-1]}
        return
      fi
    fi
  done < manifest.json.template
}

function getVersion {
  module=$1

  currentVersion="$(getValue "${module}" "(tag|version)")"
  [[ "${currentVersion}" =~ ^[^0-9]([0-9]+)\. ]]
  majorVersion="${BASH_REMATCH[1]}"

  [[ "$(getValue "${module}" "name")" =~ .*/(.*) ]]
  artifactId="${BASH_REMATCH[1]}"

  lastVersion=$(curl -s -X GET "https://zowe.jfrog.io/artifactory/api/search/latestVersion?repos=libs-release-local&v=${majorVersion}.*&$(getArtifactId "${module}")")

  echo "${lastVersion}"
}

function update {
  module=$1
  version=$2

  moduleRegex="\"($(getComponentRegex "${module}"))\""

  selected=0
  IFS=""
  while read -r line; do
    if [[ "${line}" =~ ${moduleRegex} ]]; then
      selected=1
    elif [[ "${line}" =~ \"entries\".*:.*{ ]]; then
      # skipping entries line
      selected=${selected}
    elif [[ "${line}" =~ :.*{ ]]; then
      selected=0
    fi

    if [[ ${selected} -eq 1 ]]; then
      if [[ "${line}" =~ ^(.*\"(tag|version)\".*:[^0-9]*)[0-9.]+([^0-9]*)$ ]]; then
        echo "${BASH_REMATCH[1]}${version}${BASH_REMATCH[3]}"
        selected=0
      else
        echo ${line}
      fi
    else
      echo ${line}
    fi
  done < manifest.json.template
}

function updateModule {
  module="${1}"
  version="${2:-$(getVersion "${module}")}"

  echo "Updating ${module} to version $version"

  update "$module" "$version" > manifest.json.template.new
  rm manifest.json.template
  mv manifest.json.template.new manifest.json.template
}

if [ $# -ne 0 ]; then
  while (( $# )); do
    module=$1
    version=""
    if [[ ! "${2:-}" =~ ^- ]]; then
      version=$2
      if [[ ! -z "${2:-}" ]]; then
        shift
      fi
    fi
    shift

    updateModule "${module:1}" "$version"
  done
else
  updateAll
fi
