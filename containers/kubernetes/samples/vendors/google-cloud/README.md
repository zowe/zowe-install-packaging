# Google Cloud Kubernetes Engine

## Headless Discovery Service

GKE doesn't support DNS resolution of `<pod-name>.<service-name>.<namespace>.svc.cluster.local` if the service is not headless. To define discovery as a headless service, please only apply `samples/discovery-service-ci.yaml`. `LoadBalancer` or `NodePort` type of discovery service is not supported.

## Persistent Volume Claim

By default, the storage classes created by GKE does not support `ReadWriteMany` mode. You may see error messages like this,

```
FailedMount Failed to attach volume "zowe-workspace-pv" on node "xyz" with: googleapi: Error 400: The disk resource 'zowe-workspace-pv' is already being used by 'xyz'
```

There are several ways to setup a persistent volume support `ReadWriteMany` mode in Google Cloud, here uses [Filestore](https://cloud.google.com/filestore) as example.

Follow [Accessing file shares from Google Kubernetes Engine clusters](https://cloud.google.com/filestore/docs/accessing-fileshares) instruction to setup persistent volume.

After you created Filestore, update these fields of `samples/vendors/google-cloud/workspace-pvc.yaml` with your Filestore information:

- `spec.nfs.path` with your Filestore File share name,
- `spec.nfs.server` with your Filestore IP address.

Apply `samples/vendors/google-cloud/workspace-pvc.yaml` with this command to create PersistentVolumeClaim:

```
kubectl apply -f samples/vendors/google-cloud/workspace-pvc.yaml
```

## Permission of Persistent Volume

After persistent volume is created, when we mount it, the `zowe` user and `zowe` group may not have write permission to the mounted volume. We need to change the owner and permission of the volume.

Run this command to update file system permission:

```
kubectl apply -f samples/update-workspace-permission-pod.yaml 
```

Please note, to successfully update file system permission, this pod is started as `root` user. This pod will reach `complete` status once the job is done. You can check the pod log by issuing this command:

```
kubectl logs update-workspace-permission -n <namespace>
```

This is a sample result,

```
$ kubectl logs update-workspace-permission -n zowe
Zowe workspace owner is 65534:4294967294 with 755 permission
Zowe workspace owner is 20000:20000 with 755 permission after chown or chmod
```

`owner is 20000:20000 with 755 permission` is the desired state.

Delete the pod since it's not needed anymore.

```
kubectl delete -f samples/update-workspace-permission-pod.yaml
```

## Network Policy

By default, network policy is not enabled for Google Cloud managed Kubernetes. Please follow [Creating a network policy](https://cloud.google.com/kubernetes-engine/docs/how-to/network-policy) instruction to enable it before applying Zowe network policies.
