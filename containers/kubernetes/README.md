# Kubernetes YAML Configurations

**NOTES**, all paths below are relative to current directory `containers/kubernetes`.

## Preparations

### Create Namespace and Service Account

Our default namespace is `zowe`, default service account name is `zowe-sa`.

```
kubectl create namespace zowe
kubectl create serviceaccount zowe-sa --namespace zowe
```

or
```
kubectl apply -f samples/zowe-ns.yaml
kubectl apply -f samples/zowe-sa.yaml
```

### Create Persistent Volume

```
kubectl apply -f samples/workspace-pvc.yaml`
```

### Create And Modify ConfigMaps and Secrets

On z/OS, run this command in your instance directory:

```
cd <instance-dir>
./bin/utils/convert-for-k8s.sh
```

This should display a set of YAML with `zowe-config` ConfigMap, `zowe-certificates-cm` ConfigMap and `zowe-certificates-secret` Secret. The content should looks similar to `samples/config-cm.yaml`, `samples/certificates-cm.yaml` and `samples/certificates-secret.yaml` but with real values. Copy the whole output and save as a YAML file `configs.yaml` on your local computer, verify and then run `kubectl apply -f /path/to/your/configs.yaml`.

## Apply Zowe Services and Start

```
kubectl apply -f core/
```

## Launch Single Image on Local Computer

### Init `tmp` Folder

- Create `tmp` folder:

  ```
  mkdir -p tmp
  cd tmp
  ```

- Init with `zowe-launch-scripts` image:

  ```
  docker run -it --rm -v $(pwd):/home/zowe zowe-docker-snapshot.jfrog.io/ompzowe/zowe-launch-scripts:0.0.1-ubuntu.users-jack-k8s-yaml-35
  ```

- Create `tmp/instance/instance.env` with your desired content. This content you can modify from `samples/config-cm.yaml`.
- Create `tmp/keystore/` and `tmp/keystore/zowe-certificates.env` with your desired content.

### Start Component Container

For example, starting `explorer-jes` with `bash`:

```
docker run -it --rm \
    -v $(pwd):/home/zowe \
    --entrypoint /bin/bash \
    zowe-docker-release.jfrog.io/ompzowe/explorer-jes:latest
```

Or try to start the component:

```
docker run -it --rm \
    -v $(pwd):/home/zowe \
    --entrypoint /bin/bash \
    zowe-docker-release.jfrog.io/ompzowe/explorer-jes:latest \
    -- /home/zowe/instance/bin/internal/run-zowe.sh
```
