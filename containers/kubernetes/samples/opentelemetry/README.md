# README

## Install OpenTelemetry Collector

We will be using the OpenTelemetry Operator for Kubernetes to setup OTEL collector. To install the operator in an existing cluster, `cert-manager` is required.

Use the following commands to install `cert-manager` and the operator:

```
# cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.yaml

# open telemetry operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

Once the `opentelemetry-operator` deployment is ready, we need to create an OpenTelemetry Collector instance.

The `samples/opentelemetry/collector.yaml` configuration provides a good starting point, however, you may change as per your requirement. To apply, use this command:

```
kubectl apply -f samples/opentelemetry/collector.yaml
```

## Install Jaeger

We will using the Jaeger Operator for Kubernetes to deploy Jaeger. To install the operator, run:

```
kubectl create namespace observability
kubectl create -n observability -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.29.1/jaeger-operator.yaml
```

Note that you’ll need to download and customize the Role Bindings if you are using a namespace other than observability.

Once the `jaeger-operator` deployment in the namespace observability is ready, create a Jaeger instance, like:

```
kubectl apply -n observability -f samples/opentelemetry/jaeger.yaml
```

## Verify and port forwarding

Check if the `otel-collector` and `jaeger-query` service has been created:

```
kubectl get svc --all-namespaces

NAMESPACE                       NAME                                                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                  AGE
cert-manager                    cert-manager                                                ClusterIP   10.96.164.235    <none>        9402/TCP                                 9m52s
cert-manager                    cert-manager-webhook                                        ClusterIP   10.111.113.88    <none>        443/TCP                                  9m52s
observability                   jaeger-agent                                                ClusterIP   None             <none>        5775/UDP,5778/TCP,6831/UDP,6832/UDP      99s
observability                   jaeger-collector                                            ClusterIP   10.102.255.8     <none>        9411/TCP,14250/TCP,14267/TCP,14268/TCP   99s
observability                   jaeger-collector-headless                                   ClusterIP   None             <none>        9411/TCP,14250/TCP,14267/TCP,14268/TCP   99s
observability                   jaeger-operator-metrics                                     ClusterIP   10.101.196.203   <none>        8443/TCP                                 6m44s
observability                   jaeger-query                                                ClusterIP   10.108.235.50    <none>        16686/TCP,16685/TCP                      99s
opentelemetry-operator-system   opentelemetry-operator-controller-manager-metrics-service   ClusterIP   10.98.217.60     <none>        8443/TCP                                 9m33s
opentelemetry-operator-system   opentelemetry-operator-webhook-service                      ClusterIP   10.108.3.106     <none>        443/TCP                                  9m33s
opentelemetry-operator-system   otel-collector                                              NodePort    10.105.160.200   <none>        4317:30080/TCP,8889:31809/TCP            7m39s
< ... other services >
```

Now, setup a port forward to the `jaeger-query` service:

```
kubectl port-forward service/jaeger-query -n observability 8080:16686
```

You should now be able to access Jaeger at http://localhost:8080/.
