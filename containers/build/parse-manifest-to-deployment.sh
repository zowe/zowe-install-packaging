#!/bin/bash

# uncomment next line to enable debug mode
#debug=true    

# constants
SCRIPT_NAME=$(basename "$0")
SCRIPT_PWD=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT_PWD=$(cd "$SCRIPT_PWD" && cd ../.. && pwd)
K8S_ROOT_PWD=$(cd "$PROJECT_ROOT_PWD" && cd containers/kubernetes && pwd)
MANIFEST_FILE="$PROJECT_ROOT_PWD/manifest.json"

# parse manifest to look for imageDependencies
for eachImageDep in $(jq -r '.imageDependencies | to_entries[] | .key' $MANIFEST_FILE);
do
    registry=$(jq -r ".imageDependencies.\"$eachImageDep\" | .registry" $MANIFEST_FILE)
    name=$(jq -r ".imageDependencies.\"$eachImageDep\" | .name" $MANIFEST_FILE)
    tag=$(jq -r ".imageDependencies.\"$eachImageDep\" | .tag" $MANIFEST_FILE)
    # construct image line
    image="$registry/$name:$tag"

    if [[ -n "$debug" ]]; 
    then
        echo "Current image dependency is "$eachImageDep;
        echo "registry is $registry";
        echo "name is $name";
        echo "tag is $tag";
        echo "image line to be replaced is $image";
    fi

    yamlFile=
    if [ "$eachImageDep" = "cleanup-static-definitions-cronjob" ] || [ "$eachImageDep" = "discovery-statefulset" ];
    then
        yamlFile="$PROJECT_ROOT_PWD/containers/kubernetes/workloads/$eachImageDep.yaml"
    else
        yamlFile="$PROJECT_ROOT_PWD/containers/kubernetes/workloads/$eachImageDep-deployment.yaml"
    fi    

    # replace image line with information parsed from manifest
    if [ "$eachImageDep" = "cleanup-static-definitions-cronjob" ];
    then
        IMAGE=$image yq e -i '.spec.jobTemplate.spec.template.spec.containers[0].image = strenv(IMAGE)' $yamlFile 
    else
        IMAGE=$image yq e -i '.spec.template.spec.containers[0].image = strenv(IMAGE)' $yamlFile 
    fi
done

# parse version in manifest and replace each file in kubernetes directory with current version
# ie. app.kubernetes.io/version: <CURRENT_PROJECT_VERSION>
CURRENT_PROJECT_VERSION=$(jq -r '.version' $MANIFEST_FILE)
i=0 #counter, for debug purpose
filesArray= #store an array of matched files, for debug purpose
for eachMatchedFile in $(grep -rlw $K8S_ROOT_PWD -e 'app.kubernetes.io/version:' --exclude 'sample-deployment.yaml');
do
    VERSION=$CURRENT_PROJECT_VERSION yq e -i '.metadata.labels."app.kubernetes.io/version" = strenv(VERSION)' $eachMatchedFile 
    let i++
    eachMatchedFile=${eachMatchedFile##*kubernetes/}
    filesArray="${filesArray}${eachMatchedFile}"$'\n'
done

if [[ -n "$debug" ]];
then
    echo "There are $i files changed with line app.kubernetes.io/version: $CURRENT_PROJECT_VERSION, they are: "
    echo "$filesArray"
fi

echo "SUCCESS! Yaml files replacement from manifest parsing complete!"