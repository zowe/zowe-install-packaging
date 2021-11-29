# Zowe Container Installation: Ansible Kubernetes Testing


- [Zowe Container Installation: Ansible Kubernetes Testing](#zowe-container-installation-ansible-kubernetes-testing)
  - [Introduction](#introduction)
  - [Prerequisite](#prerequisite)
  - [Environment Variables](#environment-variables)
    - [More details about the environmental variables:](#more-details-about-the-environmental-variables)
  - [Examples:](#examples)

## Introduction

This README covers the Zowe containers installation using Ansible Kubernetes Test. In this installation test, given the list of prerequisites in place, ansible first removes any Zowe containers deployed previous in the Kubernetes cluster and then it deploys all the Zowe containers to Kuberenetes cluster and wait till all of the pods become in Ready state. Since there are different Kubernetes platform, it is necessary to provide all the possible way to run the test using correct environment variables. To learn more about the Zowe container installation, please check [Installation Document](https://github.com/zowe/zowe-install-packaging/tree/master/containers/kubernetes)


## Prerequisite

In order to run this test, make sure that you have the required software and environments.

1.	On the IBM Z – z/OS:
•	Zowe installed on z/OS for users of ZSS and ZIS (default when you use the Zowe Application Framework app-server, the Zowe Desktop, or products that are based on them)
•	z/OSMF installed on z/OS for users of it (default when you use gateway, API Mediation Layer, Web Explorers, or products that are based on them)
2.	Kubernetes Cluster  - it could be installed/configured on BareMetal (zLinux/x86) or cloud (IBM Cloud Kubernetes, Google Cloud Kubernetes, OpenShift) 
3.	Test Running System: Ansible – with module Kubernetes.core and kwoodson.yedit installed.
When running this ansible test you’ll be required to provide essential environmental variable based on the platform (Kubernetes cluster) targeted.

In the rest of the README, it will cover list of environmental variable and how to run the test for different platform. E.g. BareMetal (own Cluster with Kubernetes), IBM Cloud Kubernetes, Google Cloud Kubernetes and etc.

## Environment Variables

Here is the list of environmental variables with example or default value:


|Environmental Variable	| Default Value	| Example Value                                 |
|-----------------------|:-------------:|----------------------------------------------:|
|ansible_user           |               |       zowead3                                 |
|ansible_password		|               |       x123abc                                 |
|ansible_ssh_host		|               | zzow01.zowe.marist.cloud                      |
|kubeconfig	            |               |       ~/.kube/config                          |	
|k8s_context		    |               |   docker-desktop                              |
|convert_for_k8s        |               | /ZOWE/tmp/.zowe/bin/utils/convert-for-k8s.sh  |
|k8s_storageclass	    | hostpath      |                                               |	
|k8s_pv_name		    |               |       zowe-workspace-pv                       |
|k8s_pvc_labels		    |               |       [“billingType”, “region”, “zone”]       | 
|k8s_service	        | loadbalancer	|                                               |
|k8s_service_annot		|               |       [“ip-type”,”zone”,”vlan”]               |
|k8s_list_domain_ip	    | localhost 	|                                               |
|k8s_networking		    |               |       ingress                                 |
|k8s_gateway_domain		|               |       *.nio.io                                |
|k8s_discovery_domain	|               |       *.nio.io                                |


### More details about the environmental variables: 

**ansible_user**: z/OS host user name

**ansible_password**: z/OS host password

**ansible_ssh_host**: z/OS host IP address / domain

**kubeconfig**: Path to an existing Kubernetes config file. If not provided, and no other connection options are provided, it load the default configuration file from host's ~/.kube/config.json.

**k8s_context**: The name of a context found in the config file. 

**convert_for_k8s**: Location of the script file to create ConfigMaps and Secrets used by Zowe containers. This script is found in the z/OS system. i.e. convert_for_k8s=<zowe-instance-dir>/bin/utils/convert-for-k8s.sh

**k8s_storageclass**: Zowe's PVC has a default StorageClass value (=hostpath) that may not apply to all Kubernetes clusters. Check and provide the storageClassName. You can use kubectl get sc to confirm which StorageClass you can use.

**k8s_pv_name**: The name of the persistence volume name. If you provide PV name, it will be the main place to look for volume information (surpressing storageclass).

**k8s_pvc_labels**: IBM Cloud requires additional information about pvc through labels. You can get the information from https://cloud.ibm.com/docs/containers?topic=containers-file_storage#file_qs . Please provide in array format: k8s_pvc_labels: [“hourly”, “us-south”, “dal12”]
- billingType . For example, hourly.
- Region. Found in here: (https://cloud.ibm.com/kubernetes/clusters/"cluster-id"/overview?region=us-south&resourceGroup="resource-group-id")
- Zone. You should be able to see this zone in your cluster home information page (using above url)

**k8s_service**: Type of Service. Default is “loadbalancer”. Please use below table to check which service you’ll need based on the Kubernetes provider.

|Kubernetes provider |	k8s_service             |
|:-------------------|:-------------------------|
|docker-desktop	     | LoadBalancer             |
|bare-metal	         | LoadBalancer or NodePort |
|cloud-vendors	     | LoadBalancer             |
|OpenShift	         | LoadBalancer or NodePort |

**k8s_service_annot**: Used specifically for IBM Cloud Kubernetes, where addition information about the load-balancer provided using array. For example, please provide value in array format - k8s_service_annot: [“public”, “dal12”, “12345”]. 
- ibm-load-balancer-cloud-provider-ip-type: public (you can get them using the following link -  (https://cloud.ibm.com/docs/containers?topic=containers-cs_network_planning#public_access and https://cloud.ibm.com/docs/containers?topic=containers-loadbalancer) 
- ibm-load-balancer-cloud-provider-zone: dal12 (use `ibmcloud ks zone ls` to list zones)
- ibm-load-balancer-cloud-provider-vlan: 12345 (use `ibmcloud ks vlan ls --zone <zone>` to list VLANs)

**k8s_list_domain_ip**: Used by the convert_for_k8s script, it is a comma-separated list of domains you will use to visit the Zowe Kubernetes cluster. These domains and IP addresses will be added to your new certificate if needed. The default value is localhost.

**k8s_networking**: It gives Services externally-reachable URLs and may provide other abilities such as traffic load balancing. Please use the table below and use value if needed

|Kubernetes provider |	k8s_networking  |
|:-------------------|:-----------------|
|bare-metal	         |  Ingress         |
|OpenShift	         |  Route           |

**k8s_gateway_domain**: If you’re using k8s_networking, and if you have your own domain name for gatway service then please provided it here. i.e. k8s_gateway_domain: ”gateway.io”

**k8s_discovery_domain**: If you’re using k8s_networking, and if you have your own domain name for discovery service then please provided it here. i.e. k8s_discovery_domain: ”discovery.io”

## Examples:

**Install Zowe containers on local Kubernetes service provisioned by Docker-Desktop:**
```
ansible-playbook -l <server> install-kubernetes.yml -e k8s_context=docker-desktop -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e zowe_instance_dir=/ZOWE/tmp/.zowe
```
**Install Zowe containers on Kubernetes running on BareMetal:**
```
ansible-playbook -l <server> install-kubernetes.yml -e kubeconfig=<location_of_the_file>/kubeconfig -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e k8s_gateway_domain="*.nio.io" -e k8s_discovery_domain="*.nio.io" -e k8s_storageclass=<storageclassname> -e k8s_service=nodeport -e k8s_list_domain_ip="1.2.3.4.nip.io,1.2.3.4" -e k8s_networking=ingress -e zowe_instance_dir=/ZOWE/tmp/.zowe
```
**Install Zowe containers on OpenShift:**
```
ansible-playbook -l <server> install-kubernetes.yml -e kubeconfig=<location_of_the_file>/kubeconfig -e k8s_context=<name>  -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e k8s_storageclass=<storageclassname> -e k8s_list_domain_ip="1.2.3.4.gate.io,1.2.3.4.discover.io" -e k8s_networking=route -e zowe_instance_dir=/ZOWE/tmp/.zowe -e k8s_gateway_domain="gate.io" -e k8s_discovery_domain="discover.io"
```
**Install Zowe containers on IBM Cloud Kubernetes:**
```
ansible-playbook -l <server> install-kubernetes.yml -e kubeconfig=<location_of_the_file>/kubeconfig -e k8s_context=<name>  -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e k8s_storageclass=<storageclassname> -e k8s_list_domain_ip="1.2.3.4.nip.io,1.2.3.4" --extra-vars=’{“ k8s_service_annot”: [“type”, “zone”, “vlan”]}’ --extra-vars=’{“k8s_pvc_labels”: [“billingType”, “region”, “zone”]}’ -e k8s_gateway_domain="*.nio.io" -e k8s_discovery_domain="*.nio.io" -e zowe_instance_dir=/ZOWE/tmp/.zowe
```