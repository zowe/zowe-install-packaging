# IBM Cloud Managed Kubernetes

Please note only `Classic` Infrastructure is supported. If your Kubernetes is VPC based, there is no default storage can support `ReadWriteMany` mode. You can setup your own storage provisioner if you are using VPC infrastructure.

## Collect information about your cluster

You need region and zone information of your cluster. Run this `ibmcloud` command to find information:

```
ibmcloud ks cluster get --show-resources --cluster <cluster-name>
```

Sample output:

```
$ ibmcloud ks cluster get --show-resources --cluster zowe-test
Retrieving cluster zowe-test and all its resources...
OK
                                   
Name:                           zowe-test   
ID:                             caceiiew0mghmdqdkqp0   
State:                          normal   
Created:                        2022-06-02T16:46:31+0000   
Location:                       wdc07   
Master URL:                     https://c106.us-east.containers.cloud.ibm.com:30858   
Public Service Endpoint URL:    https://c106.us-east.containers.cloud.ibm.com:30858   
Private Service Endpoint URL:   -   
Master Location:                Washington D.C.   
Master Status:                  Ready (1 hour ago)   
Master State:                   deployed   
Master Health:                  normal   
Ingress Subdomain:              zowe-test-f0a06ca5e48b190d5038fbf978b2e77a-0000.us-east.containers.appdomain.cloud   
Ingress Secret:                 zowe-test-f0a06ca5e48b190d5038fbf978b2e77a-0000   
Workers:                        2   
Worker Zones:                   wdc07   
Version:                        1.22.9_1549   
Creator:                        -   
Monitoring Dashboard:           -   
Resource Group ID:              b865a1baa45e480b90cf71f23b42075a   
Resource Group Name:            Giza   

Subnet VLANs
VLAN ID   Subnet CIDR        Public   User-managed   
3234046   169.62.57.136/29   true     false   
3234048   10.191.41.240/29   false    false   
```

The cluster is located in `us-east` region and `wdc07` zone. The public VLAN ID is `3234048`.

## Persistent Volume Claim

Check [Comparison of persistent storage options for single zone clusters](https://cloud.ibm.com/docs/containers?topic=containers-storage_planning#single_zone_persistent_storage) for list of supported Kubernetes access writes. Block storage, either Classic or VPC, does not support `ReadWriteMany` mode required by Zowe.

Customize `samples/vendors/ibmcloud/workspace-pvc.yaml` with values found in [Collect information about your cluster](#collect-information-about-your-cluster) section:

- `metadata.labels.region`
- `metadata.labels.zone`
- `spec.storageClassName`

Apply `samples/vendors/ibmcloud/workspace-pvc.yaml` with command:

```
kubectl apply -f samples/vendors/ibmcloud/workspace-pvc.yaml
```

Verify if `zowe-workspace-pvc` status is `Bound` with command `kubectl get pvc -n <zowe-namespace>`.

For more details, please check [Storing data on classic IBM Cloud File Storage](https://cloud.ibm.com/docs/containers?topic=containers-file_storage#file_qs).

## Permission of Persistent Volume

After persistent volume is created, when we mount it, the `zowe` user and `zowe` group may not have write permission to the mounted volume. We need to change the owner and permission of the volume.

Run this command to update file system permission:

```
kubectl apply -f samples/fixes/workspace-permission/update-workspace-permission-job.yaml
```

Please note, to successfully update file system permission, this pod is started as `root` user. This pod will reach `complete` status once the job is done. You can check the pod log by issuing this command:

```
kubectl logs job/update-workspace-permission -n <namespace>
```

This is a sample result,

```
$ kubectl logs job/update-workspace-permission -n zowe
Zowe workspace owner is 65534:4294967294 with 755 permission
Zowe workspace owner is 20000:20000 with 755 permission after chown or chmod
```

`owner is 20000:20000 with 755 permission` is the desired state.

Delete the job since it's not needed anymore.

```
kubectl delete -f samples/fixes/workspace-permission/update-workspace-permission-job.yaml
```

## Load Balancer Service

To configure `gateway` and `discovery` as `LoadBalancer` service, you can customize annotations metadata defined in `samples/vendors/ibmcloud/gateway-service-lb.yaml` and `samples/vendors/ibmcloud/discovery-service-lb.yaml` with values found in [Collect information about your cluster](#collect-information-about-your-cluster) section:

- `service.kubernetes.io/ibm-load-balancer-cloud-provider-ip-type`
- `service.kubernetes.io/ibm-load-balancer-cloud-provider-zone`
- `service.kubernetes.io/ibm-load-balancer-cloud-provider-vlan`

`api-catalog` service is `ClusterIP` type, no need to define as `LoadBalancer` and expose to public.

Please check [Planning public external load balancing](https://cloud.ibm.com/docs/containers?topic=containers-cs_network_planning#public_access) and [Setting up basic load balancing with an NLB 1.0](https://cloud.ibm.com/docs/containers?topic=containers-loadbalancer) document for more in-depth information.
