# Azure Kubernetes Engine

## Storage Class

Azure by default creates storage classes support `ReadWriteMany` mode. For example, use `azurefile` storage class showing in `samples/vendors/azure/workspace-pvc.yaml`.

## Network Policy

When creating the cluster, AKE has option to enable Calico network policy provider. Please make sure this option is enabled if you plan to apply `NetworkPolicy`.
