# Network Policy

## Network Policy in General

Check Kubernetes documentation on [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) for more details.

To enable network policy, you need a network policy provider. Choose from this list [Install a Network Policy Provider](https://kubernetes.io/docs/tasks/administer-cluster/network-policy-provider/) and follow the instruction to enable it.

### Use Calico with minikube

For example, if you choose [Calico](https://kubernetes.io/docs/tasks/administer-cluster/network-policy-provider/calico-network-policy/), follow these steps of [Quickstart for Calico on Kubernetes](https://docs.projectcalico.org/latest/getting-started/kubernetes/).

Minikube offers a built-in Calico implementation, this is a quick way to checkout Calico network policy features.

```
minikube start --network-plugin=cni --cni=calico
```

You can verify Calico installation in your cluster by issuing the following command.

```
kubectl get pods -l k8s-app=calico-node -A
```

You should see a result similar to the below. Note that the namespace might be different, depending on the method you followed.

```
NAMESPACE     NAME                READY   STATUS    RESTARTS   AGE
kube-system   calico-node-mlqvs   1/1     Running   0          5m18s
```

## Enable Zowe sample Network Policy

Before applying NetworkPolicy, you need to update policy with configurations fit in your environment by modifying `samples/network-policy/zowe-np.yaml`:

- Locate `spec.egress[2].to[0].ipBlock.cidr` option, it has comment `allow connections to z/OS`, update `<zos-ip>/32` with your real z/OS IP. You can put any valid CIDR to enable desired connection.
- Locate `spec.egress[2].ports[0].port` option, it has comment `z/OSMF`, update `443` with your real z/OSMF port.
- Locate `spec.egress[2].ports[1].port` option, it has comment `Zowe ZSS`, update `7557` with your real Zowe ZSS port.

Once the customizations are done, run this command to apply Zowe default network policy:

```
kubectl apply -f samples/network-policy/zowe-np.yaml
```

The default policy will,

- Ingress
  - allow network connections from pods with `zowe` namespace,
  - disable connections from pods NOT in `zowe` namespace,
- Egress
  - allow DNS query from pods with `zowe` namespace,
  - allow connections to z/OS system from pods with `zowe` namespace,
  - disable other general internet connections from pods with `zowe` namespace.

### Verify Ingress

`samples/network-policy/test-pod.yaml` is a test pod you can use to troubleshoot network connections. The pod has `curl` utility and will be applied to `default` namespace.

```
kubectl apply -f samples/network-policy/test-pod.yaml
```

Check gateway pod IP:

```
$ kubectl get pods -n zowe -o wide
NAMESPACE     NAME                                        READY   STATUS      RESTARTS        AGE     IP              NODE       NOMINATED NODE   READINESS GATES
zowe          gateway-7b4bb9ffbb-bsdtn                    1/1     Running     0               21m     10.244.120.90   minikube   <none>           <none>

<other lines are omitted>
```

Verify the connection is rejected from `default` namespace:

```
$ DEBUG= kubectl exec -it test-pod -n default -- /bin/sh
# curl -k -v https://10.244.120.90:7554
*   Trying 10.244.120.90:7554...
* TCP_NODELAY set
^C
# exit
command terminated with exit code 130
```

The expected behavior is no response from gateway pod. The NetworkPolicy shouldn't block you from accessing Zowe gateway from remote.

Delete the test pod once you done the verification:

```
kubectl delete -f samples/network-policy/test-pod.yaml
```

### Verify Egress

We can connect to a Zowe pod to verify egress setup. Use `gateway-7b4bb9ffbb-bsdtn` pod showing above as example:

```
$ DEBUG= kubectl exec -it gateway-7b4bb9ffbb-bsdtn -n zowe -- /bin/sh
Defaulted container "gateway" out of: gateway, init-zowe (init)
sh-5.0$ node /home/zowe/runtime/bin/utils/curl.js -k -v https://<zosmf-host>:<zosmf-port>/zosmf
> GET https://<zosmf-host>:<zosmf-port>/zosmf
> Headers:

< Status: 302
< Headers:
< - x-powered-by: Servlet/3.1
< - x-frame-options: SAMEORIGIN
< - x-content-type-options: nosniff
< - x-xss-protection: 1; mode=block
< - strict-transport-security: max-age=31536000; includeSubDomains
< - location: https://<zosmf-host>:<zosmf-port>/zosmf/
< - content-language: en-US
< - transfer-encoding: chunked
< - connection: Close
< - date: Wed, 25 May 2022 16:24:43 GMT
< Body:

sh-5.0$ node /home/zowe/runtime/bin/utils/curl.js -k -v https://google.com               
> GET https://google.com/
> Headers:

^C
sh-5.0$ exit
exit
command terminated with exit code 130
```

`<zosmf-host>:<zosmf-port>` is the location of your z/OSMF service.

Expected behaviors are:

- gateway should be able to connect to the z/OS system you defined,
- gateway should NOT be able to make other internet connections except DNS query.
