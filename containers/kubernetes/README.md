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

## Launch Single Image on Local

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
