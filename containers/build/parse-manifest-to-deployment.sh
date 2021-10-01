#!/bin/bash

# uncomment next line to enable debug mode
#debug=true    

# constants
SCRIPT_NAME=$(basename "$0")
SCRIPT_PWD=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT_PWD=$(cd "$SCRIPT_PWD" && cd ../.. && pwd)
manifestFile="$PROJECT_ROOT_PWD/manifest.json"

for eachImageDep in $(jq -r '.imageDependencies | to_entries[] | .key' $manifestFile);
do
    registry=$(jq -r ".imageDependencies.\"$eachImageDep\" | .registry" $manifestFile)
    name=$(jq -r ".imageDependencies.\"$eachImageDep\" | .name" $manifestFile)
    tag=$(jq -r ".imageDependencies.\"$eachImageDep\" | .tag" $manifestFile)
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
    
    if [ "$eachImageDep" = "cleanup-static-definitions-cronjob" ];
    then
        IMAGE=$image yq e -i '.spec.jobTemplate.spec.template.spec.containers[0].image = strenv(IMAGE)' $yamlFile 
    else
        IMAGE=$image yq e -i '.spec.template.spec.containers[0].image = strenv(IMAGE)' $yamlFile 
    fi
done

