# Kubernetes YAML Configurations

**NOTES**, all paths below are relative to current directory `containers/kubernetes`.

## Preparations

### Create Namespace and Service Account

Our default namespace is `zowe`, default service account name is `zowe-sa`. Please note that by default, `zowe-sa` service account has `automountServiceAccountToken` disabled for security purpose.

```
kubectl apply -f samples/zowe-ns.yaml
kubectl apply -f samples/zowe-sa.yaml
```

### Create Persistent Volume Claim

Double check the `storageClassName` value of `samples/workspace-pvc.yaml` and customize to your own value.

```
kubectl apply -f samples/workspace-pvc.yaml
```

### Create And Modify ConfigMaps and Secrets

On z/OS, run this command in your instance directory:

```
cd <instance-dir>
./bin/utils/convert-for-k8s.sh
```

This should display a set of YAML with `zowe-config` ConfigMap, `zowe-certificates-cm` ConfigMap and `zowe-certificates-secret` Secret. The content should looks similar to `samples/config-cm.yaml`, `samples/certificates-cm.yaml` and `samples/certificates-secret.yaml` but with real values. Copy the whole output and save as a YAML file `configs.yaml` on your local computer, verify and then run `kubectl apply -f /path/to/your/configs.yaml`.

## Apply Zowe Core Services and Start Zowe

```
kubectl apply -f core/
```

## Import New Component

### Build and Push Component Image

Component must create container image and the component image must follow Zowe Containerization Conformance to make sure it can be started within a Zowe cluster.

Zowe core components define component Dockerfiles and use Github Actions to build images. For example, `explorer-jes` component

- has Dockerfile defined at https://github.com/zowe/explorer-jes/blob/master/container/Dockerfile,
- and defines Github Actions workflow https://github.com/zowe/explorer-jes/blob/master/.github/workflows/explorer-jes-images.yml to build the image.

There are several shared Github Actions may help you build your own image:

- `zowe-actions/shared-actions/docker-prepare` will prepare required environment variables used by following steps.
- `zowe-actions/shared-actions/docker-build-local` can build docker image directory on Github Actions virtual machine. By default it will be `ubuntu-latest`. This action can be used to build image for `amd64` CPU architecture.
- `zowe-actions/shared-actions/docker-build-zlinux` can build docker image on a `Linux on Z` virtual machine. This is useful if you want to build image for `s390x` CPU architecture.
- `zowe-actions/shared-actions/docker-manifest` can collect all related images and define them as docker manifests. This is useful for end-user to automatically pull the correct image based on cluster node CPU architecture, and also pull images based on popular tags like `latest`, `latest-ubuntu`, etc.

Component image must be pushed to a container image registry.
### Define `Deployment` Object

In order to start your component in Kubernetes, you need to define a `Deployment` object. To define `Deployment` for your component, you can copy from `samples/sample-deployment.yaml` and modify all occurrences of these variables:

- `<my-component-name>`: this is your component name. For example, `sample-node-api`.
- `<my-component-image>`: this is your component image described in the above [section](#build-and-push-component-image). For example, `zowe-docker-release.jfrog.io/ompzowe/sample-node-api:latest-ubuntu`.
- `<my-component-port>`: this is the port of your service. For example, `8080`.

Continue to customize the specification to fit in your component requirements:

- `spec.replicas`: adjust how many pods you wish to start for your component,
- `spec.template.spec.containers[0].resources`: adjust the memory and CPU resource required to start the container,
- `metadata.annotations`, `spec.template.spec.volumes` and `spec.template.spec.securityContext` etc.

### Start Your Component

Once you defined your component `Deployment` object, you can run `kubectl apply -f /path/to/your/component-deployment.yaml` to apply it to Kubernetes cluster running Zowe. Now you can follow common Kubernetes practice to mange your component workload.

## Troubleshooting Tips

### ISSUE: `/tmp` Directory Is Not Writable

We enabled `readOnlyRootFilesystem` SecurityContext by default in `Deployment` object definition. This will result in `/tmp` is readonly and not writable to `zowe` runtime user.

**Recommended fix:**

Adjust your component to check `TMPDIR` or `TMP` environment variable to determine location of the temporary directory. Zowe runtime customizes those variables and points them to `/home/zowe/instance/tmp` directory, which is writable.

**Alternative fix:**

Disabling `readOnlyRootFilesystem` SecurityContext is not recommended. But you can make `/tmp` writable by replacing it with a new mounted volume. Here is an example of defining `/tmp` volume.

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      volumes:
        - name: tmp
          emptyDir: {}
      containers:
        - name: <my-component-name>
          volumeMounts:
            - name: tmp
              mountPath: "/tmp"
```

With this added to your `Deployment`, your component should be able to write to `/tmp` directory.

## Launch Single Image On Local Computer Without Kubernetes

**NOTES,** this is for debugging purpose and it's not recommended for end-user.

### Init `tmp` Folder

- Create `tmp` folder:

  ```
  mkdir -p tmp
  cd tmp
  ```

- Init with `zowe-launch-scripts` image:

  ```
  docker run -it --rm -v $(pwd):/home/zowe zowe-docker-snapshot.jfrog.io/ompzowe/zowe-launch-scripts:1.24.0-ubuntu.staging
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
