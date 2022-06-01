#!/bin/bash

# uncomment next line to enable debug mode
debug=true

# constants
SCRIPT_NAME=$(basename "$0")
SCRIPT_PWD=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT_PWD=$(cd "${SCRIPT_PWD}" && cd ../.. && pwd)
K8S_ROOT_PWD=$(cd "${PROJECT_ROOT_PWD}" && cd containers/kubernetes && pwd)
MANIFEST_FILE="${PROJECT_ROOT_PWD}/manifest.json"
if [ ! -f "${MANIFEST_FILE}" ]; then
  MANIFEST_FILE="${PROJECT_ROOT_PWD}/manifest.json.template"
fi

# parse manifest to look for imageDependencies
for eachImageDep in $(jq -r '.imageDependencies | to_entries[] | .key' "${MANIFEST_FILE}");
do
    kind=$(jq -r ".imageDependencies.\"${eachImageDep}\" | .kind" "${MANIFEST_FILE}")
    if [ "${kind}" = "null" ]; then
        kind=
    fi
    if [ -z "${kind}" ]; then
       kind=deployment
    fi
    registry=$(jq -r ".imageDependencies.\"${eachImageDep}\" | .registry" "${MANIFEST_FILE}")
    if [ "${registry}" = "null" ]; then
        registry=
    fi
    if [ -z "${registry}" ]; then
       registry=zowe-docker-release.jfrog.io
    fi
    name=$(jq -r ".imageDependencies.\"${eachImageDep}\" | .name" "${MANIFEST_FILE}")
    tag=$(jq -r ".imageDependencies.\"${eachImageDep}\" | .tag" "${MANIFEST_FILE}")
    if [ "${tag}" = "null" ]; then
        tag=
    fi
    if [ -z "${tag}" ]; then
        tag=2-ubuntu
    fi
    # construct image line
    image="${registry}/${name}:${tag}"

    if [ -n "${debug}" ]; then
        echo ">>> Current image dependency is "${eachImageDep};
        echo "    kind: ${kind}";
        echo "    image: ${image}";
    fi

    if [ "${eachImageDep}" = "zowe-launch-scripts" ]; then
        cd "${PROJECT_ROOT_PWD}/containers/kubernetes/workloads"
        for file in $(find . -type f -name "*.yaml"); do
            if [ -n "${debug}" ]; then
                echo "    updating: workloads/${file}"
            fi
            if [ "${file}" = "./cleanup-static-definitions-cronjob.yaml" ]; then
                IMAGE="${image}" yq e -i '.spec.jobTemplate.spec.template.spec.containers[0].image = strenv(IMAGE)' "${file}"
                if [ $? -eq 0 ]; then
                    echo "    updating: Ok"
                else
                    echo "    updating: Failed!"
                    exit 1
                fi
            else
                IMAGE="${image}" yq e -i '.spec.template.spec.initContainers[0].image = strenv(IMAGE)' "${file}"
                if [ $? -eq 0 ]; then
                    echo "    updating: Ok"
                else
                    echo "    updating: Failed!"
                    exit 1
                fi
            fi
        done
        # replace image line with information parsed from manifest
    elif [ "${eachImageDep}" = "base" ] || [ "${eachImageDep}" = "base-jdk" ] || [ "${eachImageDep}" = "base-node" ]; then
        # NOP do nothing
        if [ -n "${debug}" ]; then
            echo "    base image ${eachImageDep} will skip updating yml file"
        fi
    else
        if [ -n "${debug}" ]; then
            echo "    updating: workloads/${eachImageDep}-${kind}.yaml"
        fi
        yamlFile="${PROJECT_ROOT_PWD}/containers/kubernetes/workloads/${eachImageDep}-${kind}.yaml"
        IMAGE="${image}" yq e -i '.spec.template.spec.containers[0].image = strenv(IMAGE)' "${yamlFile}"
        if [ $? -eq 0 ]; then
            echo "    updating: Ok"
        else
            echo "    updating: Failed!"
            exit 1
        fi
    fi
done

# parse version in manifest and replace each file in kubernetes directory with current version
# ie. app.kubernetes.io/version: <CURRENT_PROJECT_VERSION>
CURRENT_PROJECT_VERSION=$(jq -r '.version' "${MANIFEST_FILE}")
i=0 #counter, for debug purpose
filesArray= #store an array of matched files, for debug purpose
for eachMatchedFile in $(grep -rlw $K8S_ROOT_PWD -e 'app.kubernetes.io/version:' --exclude 'sample-deployment.yaml');
do
    if [ -n "${debug}" ]; then
        echo "    updating: ${eachMatchedFile}"
    fi
    VERSION=${CURRENT_PROJECT_VERSION} yq e -i '.metadata.labels."app.kubernetes.io/version" = strenv(VERSION)' "${eachMatchedFile}"
    if [ $? -eq 0 ]; then
        echo "    updating: Ok"
    else
        echo "    updating: Failed!"
        exit 1
    fi
    let i++
    eachMatchedFile=${eachMatchedFile##*kubernetes/}
    filesArray="${filesArray}${eachMatchedFile}"$'\n'
done

if [ -n "${debug}" ]; then
    echo "There are $i files changed with line app.kubernetes.io/version: ${CURRENT_PROJECT_VERSION}, they are: "
    echo "${filesArray}"
fi

echo "SUCCESS! Yaml files replacement from manifest parsing complete!"
