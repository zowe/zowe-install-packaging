# Amazon EKS

## Collect information of your cluster and your login

Follow [Create a kubeconfig for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html) instruction to update your kubeconfig and connect to your EKS cluster. The command you need should look like:

```
aws eks update-kubeconfig --region <region-name> --name <cluster-name>
```

These information could be needed for following setup:

- Caller identity

  ```
  aws sts get-caller-identity
  ```

- Cluster information

  ```
  aws eks describe-cluster --region <region-name> --name <cluster-name>
  ```

## Persistent Volume Claim

You can use [Amazon EFS](https://aws.amazon.com/efs/) to create `PersistentVolume` with `ReadWriteMany` access mode.

Follow instruction from [Amazon EFS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html) to setup IAM role, policy and create EFS.

If you follow the above instruction, the storage class created is `efs-sc`. You can update `spec.storageClassName` defined in `samples/workspace-pvc.yaml` with this value.

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
Zowe workspace owner is 1000:1000 with 700 permission
chown: changing ownership of '/home/zowe/instance/workspace': Operation not permitted
Zowe workspace owner is 1000:1000 with 777 permission after chown or chmod
```

`owner is 20000:20000 with 755 permission` or `owner is 1000:1000 with 777 permission` is the desired state.

Please note, EFS mount point may fail with `chown` command. The update permission script will `chmod` instead to grant write permission to `zowe` user.

Delete the pod since it's not needed anymore.

```
kubectl delete -f samples/update-workspace-permission-pod.yaml
```
