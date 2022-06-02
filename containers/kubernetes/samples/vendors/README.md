# Kubernetes Vendors

There are many flavors of Kubernetes managed by different vendors. For each vendor, usually the way to configure persistent volume claim (storage), service and networking are different.

Please refer to the related folder based on your Kubernetes vendor for more details.

## Zowe requirements

- Persistent volume must support `ReadWriteMany` mode.
- The persistent volume mounted as Zowe `workspace` must allow write access to `zowe` user and group.
- `gateway` service must be able to expose to public access. A `LoadBalancer` type of service is required in most of use cases.
- If you have services outside of Kubernetes cluster need to register onto the `discovery` service, then it's also required to be exposed to public access. Otherwise `ClusterIP` type of `discovery` service is good enough.
- To apply `NetworkPolicy`, a network policy provider is required.
