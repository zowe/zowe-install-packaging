# Kubernetes YAML Configurations

**NOTES**, all paths below are relative to current directory `containers/kubernetes`.

## Prerequisites

### Kubernetes Cluster

There are many ways to prepare a Kubernetes cluster based on your requirements.

For development purpose, you can setup a Kubernetes cluster on your local computer by:

- [enabling Kubernetes shipped with Docker Desktop](https://docs.docker.com/desktop/kubernetes/)
- or [setting up minikube](https://minikube.sigs.k8s.io/docs/start/)

For production purpose, you can:

- bootstrap your own cluster by following this official document [Installing Kubernetes with deployment tools](https://kubernetes.io/docs/setup/production-environment/tools/).
- or provision a Kubernetes cluster from popular Cloud vendors:
  * [Amazon Elastic Kubernetes Service](https://aws.amazon.com/eks/)
  * [Microsfot Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes)
  * [IBM Cloud Kubernetes Service](https://www.ibm.com/ca-en/cloud/kubernetes-service)
  * [Google Cloud Kubernetes Engine](https://cloud.google.com/kubernetes-engine)

### `kubectl` Tool

You need `kubectl` CLI tool installed on your local computer where you want to manage the Kubernetes cluster. Please follow appropriate steps from official documentation [Install Tools](https://kubernetes.io/docs/tasks/tools/).

## Preparations

This section assumes you already have a Kubernetes cluster setup and have `kubectl` tool installed.

### Create Namespace and Service Account

Run:

```
kubectl apply -f common/zowe-ns.yaml
kubectl apply -f common/zowe-sa.yaml
```
Our default namespace is `zowe`, default service account name is `zowe-sa`. Please note that by default, `zowe-sa` service account has `automountServiceAccountToken` disabled for security purpose.

To verify this step,

- `kubectl get namespaces` should show a Namespace `zowe`.
- `kubectl get serviceaccounts --namespace zowe` should show a ServiceAccount `zowe-sa`.

### Create Persistent Volume Claim

Double check the `storageClassName` value of `samples/workspace-pvc.yaml` and replace `hostpath` to customize to your own value. You can use `kubectl get sc` to list all StorageClass-es on your cluster. 
For example:
```
kubectl get sc
  NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
  standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  29m
```
Your `storageClassName` line in `workspace-pvc.yaml` shall be `storageClassName: standard`
After making all necessary changes, run the following command to apply:

```
kubectl apply -f samples/workspace-pvc.yaml
```

To verify this step, `kubectl get pvc --namespace zowe` should show a PersistentVolumeClaim `zowe-workspace-pvc` and the `STATUS` should be `Bound`.

### Create And Modify ConfigMaps and Secrets

On z/OS, run this command in your instance directory:

```
cd <instance-dir>
./bin/utils/convert-for-k8s.sh
```

This should display a set of YAML with `zowe-config` ConfigMap, `zowe-certificates-cm` ConfigMap and `zowe-certificates-secret` Secret. The content should looks similar to `samples/config-cm.yaml`, `samples/certificates-cm.yaml` and `samples/certificates-secret.yaml` but with real values. Copy the whole output and save as a YAML file `configs.yaml` on your local computer, verify and then run `kubectl apply -f /path/to/your/configs.yaml`.

If you want to manually define `zowe-config` ConfigMap based on your `instance.env`, please notice these differences comparing running on z/OS:

- `ZOWE_EXPLORER_HOST`, `ZOWE_IP_ADDRESS`, `ZWE_LAUNCH_COMPONENTS`, `ZWE_DISCOVERY_SERVICES_LIST` and `SKIP_NODE` are not needed for Zowe running in Kubernetes and will be ignored. You can remove them.
- `JAVA_HOME` and `NODE_HOME` are not usually needed if you are using Zowe base images.
- `ROOT_DIR` must be set to `/home/zowe/runtime`.
- `KEYSTORE_DIRECTORY` must be set to `/home/zowe/keystore`.
- `ZWE_EXTERNAL_HOSTS` is suggested to define as a list domains you are using to access your Kubernetes cluster.
- `ZOWE_EXTERNAL_HOST=$(echo "${ZWE_EXTERNAL_HOSTS}" | awk -F, '{print $1}' | tr -d '[[:space:]]')` is needed to define after `ZWE_EXTERNAL_HOSTS`. It's the primary external domain.
- `ZOWE_ZOS_HOST` is recommended to be set to where the z/OS system where your Zowe ZSS/ZIS is running.
- `ZWE_DISCOVERY_SERVICES_REPLICAS` should be set to same value of `spec.replicas` defined in `workloads/discovery-statefulset.yaml`.
- All components running in Kubernetes should use default ports:
  * `CATALOG_PORT` is `7552`,
  * `DISCOVERY_PORT` is `7553`,
  * `GATEWAY_PORT` is `7554`,
  * `ZWE_CACHING_SERVICE_PORT` is `7555`,
  * `JOBS_API_PORT` is `8545`,
  * `FILES_API_PORT` is `8547`,
  * `JES_EXPLORER_UI_PORT` is `8546`,
  * `MVS_EXPLORER_UI_PORT` is `8548`,
  * `USS_EXPLORER_UI_PORT` is `8550`,
  * `ZOWE_ZLUX_SERVER_HTTPS_PORT` is `8544`.
- `ZOWE_ZSS_SERVER_PORT` should be set to the port where your Zowe ZSS is running on `ZOWE_ZOS_HOST`.
- `APIML_GATEWAY_EXTERNAL_MAPPER` should be set to `https://${GATEWAY_HOST}:${GATEWAY_PORT}/zss/api/v1/certificate/x509/map`.
- `APIML_SECURITY_AUTHORIZATION_ENDPOINT_URL` should be set to `https://${GATEWAY_HOST}:${GATEWAY_PORT}/zss/api/v1/saf-auth`.
- `ZOWE_EXPLORER_FRAME_ANCESTORS` should be set to `${ZOWE_EXTERNAL_HOST}:*`
- `ZWE_CACHING_SERVICE_PERSISTENT` should NOT be set to `VSAM`. `redis` is suggested. Follow [Redis configuration](https://docs.zowe.org/stable/extend/extend-apiml/api-mediation-redis/#redis-configuration) documentation to customize other redis related variables. Leave the value to empty for debugging purpose.
- Must append and customize these 2 values:
  * `ZWED_agent_host=${ZOWE_ZOS_HOST}`
  * `ZWED_agent_https_port=${ZOWE_ZSS_SERVER_PORT}`

To verify this step,

- `kubectl get configmaps --namespace zowe` should show two ConfigMaps `zowe-config` and `zowe-certificates-cm`.
- `kubectl get secrets --namespace zowe` should show a Secret `zowe-certificates-secret`.

### Expose Gateway and Discovery

This section is highly related to your Kubernetes cluster configuration. If you are not sure about these sections, please contact your Kubernetes administrator or us.

#### Create Service

Depends on how your Kubernetes network setup, you may choose from `LoadBalancer` or `NodePort` service.

Choose `LoadBalancer` (`samples/gateway-service-lb.yaml` and `samples/discovery-service-lb.yaml`) if you are using Kubernetes provided by:

- Cloud vendors,
- Docker Desktop.

Choose `NodePort` (`samples/gateway-service-np.yaml` and `samples/discovery-service-np.yaml`) if you are using Kubernetes is created on Bare Metal and you don't have load balancer.

Double check these values of files you choose:

- `spec.type`.
- `spec.ports[0].nodePort`, this will be the port be exposed to external. Which means, if you are using `NodePort` service, the default gateway port is not `7554` but `32554`. You can use `https://<your-k8s-node>:32554/` to access APIML Gateway.

If you choose `LoadBalancer` services, run these commands:

```
kubectl apply -f samples/gateway-service-lb.yaml
kubectl apply -f samples/discovery-service-lb.yaml
```

If you choose `NodePort` services, run these commands:

```
kubectl apply -f samples/gateway-service-np.yaml
kubectl apply -f samples/discovery-service-np.yaml
```

To verify this step,

- `kubectl get services --namespace zowe` should show two Services `gateway-service` and `discovery-service`.

#### Create Ingress

You may not need to define `Ingress` if are using Kubernetes and:

- you choose `NodePort` services,
- the Kubernetes is provided by Cloud vendors or Docker Desktop.

Double check this value of file `samples/gateway-ingress.yaml` and `samples/discovery-ingress.yaml` before apply:

- `spec.rules[0].http.host` which is not defined by default.

Then:

```
kubectl apply -f samples/gateway-ingress.yaml
kubectl apply -f samples/discovery-ingress.yaml
```

To verify this step,

- `kubectl get ingresses --namespace zowe` should show two Ingresses `gateway-ingress` and `discovery-ingress`.

#### Create Route

If you are using OpenShift, usually you need to define `Route` instead of `Ingress`.

Double check this value of file `samples/gateway-route.yaml` and `samples/discovery-route.yaml`:

- `spec.port.targetPort`.

Then:

```
oc apply -f samples/gateway-route.yaml
oc apply -f samples/discovery-route.yaml
```

To verify this step,

- `oc get routes --namespace zowe` should show two Services `gateway` and `discovery`.

## Apply Zowe Core Components Workloads and Start Zowe

```
kubectl apply -f workloads/
```

To verify this step,

- `kubectl get deployments --namespace zowe` should show you a list of deployments including `explorer-jes`, `explorer-mvs`, `explorer-uss`, `files-api`, `jobs-api`, etc. Each deployment should show `1/1` in `READY` column.
- `kubectl get statefulsets --namespace zowe` should show you a StatefulSet `discovery` which `READY` column should be `1/1`.
- `kubectl get cronjobs --namespace zowe` should show you a CronJob `cleanup-static-definitions` which `SUSPEND` should be `False`.

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

## Configuration, Operation And Troubleshooting Tips

When Zowe workload running in Kubernetes cluster, it follows common Kubernetes operation recommendations.

### Monitoring Zowe Workload Running In Kubernetes

There are many ways to monitor workload running in Kubernetes, Kubernetes Dashboard could be a quick choice. Please follow this [Deploy and Access the Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) instruction.

If you are using a development Kubernetes shipped with Docker Desktop, the dashboard is already installed and `kubernetes-dashboard` namespace is already configuration.

[Metrics Server](https://github.com/kubernetes-sigs/metrics-server) is also recommended and is required if you want to define [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/). Check if you have `metrics-server` `Service` in `kube-system` namespace with this command `kubectl get services --namespace kube-system`. If you don't have, you can follow this [Installation](https://github.com/kubernetes-sigs/metrics-server#installation) instruction to install.

### Pause, Resume Or Remove Component

To temporarily stop a component, you can find the component `Deployment` and scale down to `0`. To use `jobs-api` as example, run this command:

```
kubectl scale -n zowe deployment jobs-api --replicas=0
```

Scaling the component back to 1 or more to re-enable the component.

If you want to permanently remove a component, you can delete the component `Deployment`. To use `jobs-api` as example, run this command:

```
kubectl delete -n zowe deployment jobs-api
```

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
