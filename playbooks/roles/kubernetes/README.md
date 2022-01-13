# Zowe Container Installation: Ansible Kubernetes Testing


- [Zowe Container Installation: Ansible Kubernetes Testing](#zowe-container-installation-ansible-kubernetes-testing)
  - [Introduction](#introduction)
  - [Prerequisite](#prerequisite)
  - [Environment Variables](#environment-variables)
    - [More details about the environmental variables:](#more-details-about-the-environmental-variables)
  - [Examples:](#examples)

## Introduction

This README covers the Zowe containers installation using Ansible Kubernetes Test. In this installation test, given the list of prerequisites in place, ansible first removes any Zowe containers deployed previous in the Kubernetes cluster and then it deploys all the Zowe containers to Kuberenetes cluster and wait till all of the pods become in Ready state. Since there are different Kubernetes platform, it is necessary to provide all the possible way to run the test using correct environment variables. To learn more about the Zowe container installation, please check [Installation Document](https://github.com/zowe/zowe-install-packaging/tree/master/containers/kubernetes).


## Prerequisite

In order to run this test, make sure that you have the required software and environments.

1.	On the IBM Z – z/OS:
    - Zowe installed on z/OS for users of ZSS and ZIS (default when you use the Zowe Application Framework app-server, the Zowe Desktop, or products that are based on them)
    - z/OSMF installed on z/OS for users of it (default when you use gateway, API Mediation Layer, Web Explorers, or products that are based on them)

2.	Kubernetes Cluster  - it could be installed/configured on BareMetal (zLinux/x86) or cloud (IBM Cloud Kubernetes, Google Cloud Kubernetes, OpenShift) 
3.	Test Running System: Ansible – with module Kubernetes.core and kwoodson.yedit installed.
    ```
    Testing Environment Requirement: Ansible versions: >=2.9.17; Collection supports Python 3.6+. 

    Ansible Required Module Installlation Steps:
    1. ansible-galaxy collection install kubernetes.core
    2. ansible-galaxy install kwoodson.yedit
    3. pip3 install openshift pyyaml kubernetes

    To check whether it is installed, run: ansible-galaxy collection list
    ```

When running Kubernetes ansible test you’ll be required to provide essential environmental variable based on the platform (Kubernetes cluster) targeted.

In the rest of the README, it will cover list of environmental variable and how to run the test for different platform. E.g. BareMetal (own Cluster with Kubernetes), IBM Cloud Kubernetes, OpenShift and etc.

## Environment Variables

Here is the list of environmental variables with example or default value:


|Environmental Variable	| Default Value	| Example Value                   |
|-----------------------|:-------------:|--------------------------------:|
|ansible_user           |               |                                 |
|ansible_password		|               |                                 |
|ansible_ssh_host		|               |                                 |
|kubeconfig	            |               | ~/.kube/config                  |	
|k8s_context		    |               | docker-desktop                  |
|zowe_instance_dir      |               |                                 |
|work_dir_remote        |               |                                 |
|k8s_storageclass	    | hostpath      |                                 |	
|k8s_pv_name		    |               | zowe-workspace-pv               |
|k8s_pvc_labels		    |               | “billingType”, “region”, “zone” | 
|k8s_service	        | loadbalancer	|                                 |
|k8s_service_annot		|               | “ip-type”,”zone”,”vlan”         |
|k8s_list_domain_ip	    | localhost 	|                                 |
|k8s_networking		    |               | ingress                         |
|k8s_gateway_domain		|               | *.nio.io                        |
|k8s_discovery_domain	|               | *.nio.io                        |


### More details about the environmental variables: 

**ansible_user**: z/OS host user name

**ansible_password**: z/OS host password

**ansible_ssh_host**: z/OS host IP address / domain

**kubeconfig**: Path to an existing Kubernetes config file. If not provided, and no other connection options are provided, it loads the default configuration file from host's ~/.kube/config.json.

**k8s_context**: The name of a context found in the kube config file. 

**zowe_instance_dir**: Location of the zowe instance directory. It's used to find `conver-for-k8.sh` script file, which runs to get configmap and secrets for z/OS system. 

**work_dir_remote**: Location of the working directory in z/OS. It's used to in `conver-for-k8.sh` script file to store config/secret files. 

**k8s_storageclass**: Zowe's PVC has a default StorageClass value (=hostpath) that may not apply to all Kubernetes clusters. Check and provide the storageClassName. You can use `kubectl get sc` to confirm which StorageClass you can use.

**k8s_pv_name**: The name of the persistence volume name. If you provide PV name, it will be the main location to look for volume information.

**k8s_pvc_labels**: Add information about the PVC using labels. For example, IBM Cloud requires additional information about pvc through labels. You can get the information from https://cloud.ibm.com/docs/containers?topic=containers-file_storage#file_qs and you can specify in host or group environment variables files, as following:

```
k8s_pvc_labels:
  billingType: <type> (For example, hourly.)
  region: <region> (Found in here: (https://cloud.ibm.com/kubernetes/clusters/"cluster-id"/overview?region=us-south&resourceGroup="resource-group-id"))
  zone: <zone> (ou should be able to see this zone in your cluster home information page (using above url))
```

**k8s_service**: Type of Service. Default is “loadbalancer”. Please use the below table to check which service you’ll need based on the Kubernetes provider.

|Kubernetes provider |	k8s_service             |
|:-------------------|:-------------------------|
|docker-desktop	     | LoadBalancer             |
|bare-metal	         | LoadBalancer or NodePort |
|cloud-vendors	     | LoadBalancer             |
|OpenShift	         | LoadBalancer or NodePort |

**k8s_service_annot**: Add information about the Service using Annotation. For example, IBM Cloud Kubernetes load-balancer's require additional information about service using Annotation. You can specify in host or group environment variables files, like the folllowing:
```
k8s_service_annot:
  service.kubernetes.io/ibm-load-balancer-cloud-provider-ip-type: <type> ( You can get them using the following link - https://cloud.ibm.com/docs/containers?topic=containers-cs_network_planning#public_access and https://cloud.ibm.com/docs/containers?topic=containers-loadbalancer )
  service.kubernetes.io/ibm-load-balancer-cloud-provider-zone: <zone> (use `ibmcloud ks zone ls` to list zones)
  service.kubernetes.io/ibm-load-balancer-cloud-provider-vlan: "vlan" (use `ibmcloud ks vlan ls --zone <zone>` to list VLANs)
```

**k8s_list_domain_ip**: Used by the `convert_for_k8s` script, it is a comma-separated list of domains you will use to visit the Zowe Kubernetes cluster. These domains and IP addresses will be added to your new certificate if needed. The default value is localhost.

**k8s_networking**: It gives the Services externally-reachable URLs and may provide other abilities such as traffic load balancing. Please use the table below to configure for your platoform.

|Kubernetes provider |	k8s_networking  |
|:-------------------|:-----------------|
|bare-metal	         |  Ingress         |
|OpenShift	         |  Route           |

**k8s_gateway_domain**: If you’re using k8s_networking, and if you have your own domain name for gatway service then please provided it here. i.e. k8s_gateway_domain: ”gateway.io”

**k8s_discovery_domain**: If you’re using k8s_networking, and if you have your own domain name for discovery service then please provided it here. i.e. k8s_discovery_domain: ”discovery.io”

## Examples:

**Install Zowe containers on local Kubernetes service provisioned by Docker-Desktop:**
```
ansible-playbook -l <server> install-kubernetes.yml -e k8s_context=docker-desktop -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e zowe_instance_dir=<instance-dir-path> -e work_dir_remote=<work-dir-path>
```
**Install Zowe containers on Kubernetes running on BareMetal:**
```
ansible-playbook -l <server> install-kubernetes.yml -e kubeconfig=<location_of_the_file>/kubeconfig -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e k8s_gateway_domain="*.nio.io" -e k8s_discovery_domain="*.nio.io" -e k8s_storageclass=<storageclassname> -e k8s_service=nodeport -e k8s_list_domain_ip="1.2.3.4.nip.io,1.2.3.4" -e k8s_networking=ingress -e zowe_instance_dir=<instance-dir-path> -e work_dir_remote=<work-dir-path>
```
**Install Zowe containers on OpenShift:**
```
ansible-playbook -l <server> install-kubernetes.yml -e kubeconfig=<location_of_the_file>/kubeconfig -e k8s_context=<name>  -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e k8s_storageclass=<storageclassname> -e k8s_list_domain_ip="1.2.3.4.gate.io,1.2.3.4.discover.io" -e k8s_networking=route -e zowe_instance_dir=<instance-dir-path> -e k8s_gateway_domain="gate.io" -e k8s_discovery_domain="discover.io" -e work_dir_remote=<work-dir-path>
```
**Install Zowe containers on IBM Cloud Kubernetes:**

Must provide `k8s_service_annot` info. For example, you can setup up in host or group variable file:
```
k8s_service_annot:
  service.kubernetes.io/ibm-load-balancer-cloud-provider-ip-type: <type>
  service.kubernetes.io/ibm-load-balancer-cloud-provider-zone: <zone>
  service.kubernetes.io/ibm-load-balancer-cloud-provider-vlan: <vlan>
```

Must provide `k8s_pvc_labels` info. For example, you can setup up in host or group environment variable file:
```
k8s_pvc_labels:
  billingType: <type> 
  region: <region>
  zone: <zone>
```

Run: 
```
ansible-playbook -l <server> install-kubernetes.yml -e kubeconfig=<location_of_the_file>/kubeconfig -e k8s_context=<name>  -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e k8s_storageclass=<storageclassname> -e k8s_list_domain_ip="1.2.3.4.nip.io,1.2.3.4" -e k8s_gateway_domain="*.nio.io" -e k8s_discovery_domain="*.nio.io" -e zowe_instance_dir=<instance-dir-path> -e work_dir_remote=<work-dir-path>
```
