# Kubernetes YAML Configurations

**NOTES**, all paths below are relative to current directory `containers/kubernetes`.

## Preparations

### Create `zowe` Namespace

```
kubectl create namespace zowe
```

### Create And Modify Zowe ConfigMap

Check and modify configurations in `samples/config-cm.yaml`, then run:

```
kubectl apply -f samples/config-cm.yaml`
```

### Create Certificates ConfigMap and Secret

On z/OS, run this command in your instance directory:

```
cd <instance-dir>
./bin/utils/convert-keystore-for-k8s.sh
```

This should display a set of YAML with `zowe-certificates-cm` ConfigMap and `zowe-certificates-secret` Secret. They should looks similar to `samples/certificates-cm.yaml` and `samples/certificates-secret.yaml` but with real values. Copy the whole output and save as a YAML file `certificates.yaml` on your local computer. Then run `kubectl apply -f /path/to/your/certificates.yaml`.

### Create Persistent Volume

```
kubectl apply -f samples/workspace-pvc.yaml`
```

## Apply Zowe Services and Start

```
kubectl apply -f core/
```
