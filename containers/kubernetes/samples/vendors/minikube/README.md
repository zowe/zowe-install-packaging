# Minikube

## Network Policy

Minikube offers a built-in Calico implementation, this is a quick way to start minikube with Calico network policy features.

```
minikube start --network-plugin=cni --cni=calico
```

## Define and Access services

With minikube, you can use `LoadBalancer` type of services.

There are several ways you can access the services:

- use `minikube tunnel`,
- use Kubernetes port forwarding with `kubectl port-forward` command.

Check [Accessing apps - LoadBalancer access](https://minikube.sigs.k8s.io/docs/handbook/accessing/#loadbalancer-access) for more details.
