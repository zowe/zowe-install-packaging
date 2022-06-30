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
- Review the full NetworkPolicy definition to fit in your requirements.

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

### Prepare test pods for verification

`samples/network-policy/test-np-pod.yaml` consists 2 test pods definitions. One is deployed to `default` namespace and the other one is deployed to `zowe` workspace. If your Zowe workspace is not `zowe`, please customize the namespace to yours. The test pods has `curl` utility for network verification purpose.

```
kubectl apply -f samples/network-policy/test-np-pod.yaml
```

### Verify Ingress

Check gateway pod IP:

```
$ kubectl get pods -n zowe -o wide
NAMESPACE     NAME                                        READY   STATUS      RESTARTS        AGE     IP              NODE       NOMINATED NODE   READINESS GATES
zowe          discovery-0                                 1/1     Running     0               21m     10.244.120.89   minikube   <none>           <none>
zowe          gateway-7b4bb9ffbb-bsdtn                    1/1     Running     0               21m     10.244.120.90   minikube   <none>           <none>

<other lines are omitted>
```

Verify the connection is rejected from `default` namespace:

```
$ DEBUG= kubectl exec -it test-np-default-pod -n default -- /bin/sh
# curl -k -v https://10.244.120.90:7554
*   Trying 10.244.120.90:7554...
* TCP_NODELAY set
* Connected to 10.244.120.90 (10.244.120.90) port 7554 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):

....

</body>
</html>
* Connection #0 to host 10.244.120.90 left intact
# curl -k -v https://10.244.120.89:7553
*   Trying 10.244.120.89:7553...
* TCP_NODELAY set
^C
# exit
command terminated with exit code 130
```

Expected behaviors are:

- you should be able to connect to gateway pod. The NetworkPolicy shouldn't block you from accessing Zowe gateway from remote and other namespaces.
- you should NOT be able to connect to discovery pod or other Zowe pods.

### Verify Egress

We can connect to a `test-np-zowe-pod` pod to verify egress setup.

```
$ DEBUG= kubectl exec -it test-np-zowe-pod -n zowe -- /bin/sh
$ curl -k -v https://<zosmf-host>:<zosmf-port>/zosmf
*   Trying <zosmf-ip>:<zosmf-port>...
* TCP_NODELAY set
* Connected to <zosmf-host> (<zosmf-ip>) port <zosmf-port> (#0)
* ALPN, offering h2
* ALPN, offering http/1.1

...

< HTTP/1.1 302 Found
< X-Powered-By: Servlet/3.1
< X-Frame-Options: SAMEORIGIN
< X-Content-Type-Options: nosniff
< X-XSS-Protection: 1; mode=block
< Strict-Transport-Security: max-age=31536000; includeSubDomains
< Location: https://<zosmf-host>:<zosmf-port>/zosmf/
< Content-Language: en-US
< Transfer-Encoding: chunked
< Date: Mon, 06 Jun 2022 20:24:18 GMT
< 
* Connection #0 to host <zosmf-host> left intact
$ curl -k -v https://google.com               
*   Trying 142.250.125.139:443...
* TCP_NODELAY set
*   Trying 2607:f8b0:4001:c2f::8a:443...
^C
$ exit
exit
command terminated with exit code 130
```

`<zosmf-host>:<zosmf-port>` is the location of your z/OSMF service.

Expected behaviors are:

- you should be able to connect to the z/OS system you defined,
- you should NOT be able to make other internet connections except DNS query.

### Delete test pods

Delete the test pods once you done the verification:

```
kubectl delete -f samples/network-policy/test-np-pod.yaml
```
