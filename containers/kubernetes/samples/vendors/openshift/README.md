# Openshift

## Zowe Role Binding

Applying the role binding will help Zowe service account to have proper permissions mandatory for Openshift. Run this command to apply:

```
kubectl apply -f samples/vendors/openshift/zowe-role-binding.yaml
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
Zowe workspace owner is 20000:20000 with 755 permission after chown
```

`owner is 20000:20000 with 755 permission` is the desired state.

Delete the pod since it's not needed anymore.

```
kubectl delete -f samples/update-workspace-permission-pod.yaml
```

## Exposing services

If you are using OpenShift and choose to use `LoadBalancer` services, Openshift may have already provisioned external IP for the services. You can use that external IP to access Zowe APIML Gateway. To verify your service external IP, run:

```
oc get svc -n zowe
```

If you see an IP in the `EXTERNAL-IP` column, that means your OpenShift is properly configured and can provision external IP for you. If you see `<pending>` and it does not change after waiting for a while, that means you may not be able to use `LoadBalancer` services with your current configuration. You can try `ClusterIP` services and define `Route`. A `Route` is a way to expose a service by giving it an externally-reachable hostname.

To create a routes for `gateway` and `discovery`, run the following commands:

```
oc apply -f samples/vendors/openshift/gateway-route.yaml
oc apply -f samples/vendors/openshift/discovery-route.yaml
```

To verify, run the following commands:

```
oc get routes --namespace zowe
```

This command must display the two Services `gateway` and `discovery`.

NOTE: when using default domains created by `Route`, the default https port 443 will be used. In this case, you should modify `zowe.externalPort` to `443` in zowe.yaml. You can use the domain without port to access gateway.

You can learn more details from [Exposing apps with routes in Red Hat OpenShift 4](https://cloud.ibm.com/docs/openshift?topic=openshift-openshift_routes).
