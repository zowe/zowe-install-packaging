# Kubernetes YAML Configurations

**NOTES:** all paths below are relative to current directory `containers/kubernetes`.
<br /> <br />

## Prerequisites

### 1. Kubernetes Cluster

There are many ways to prepare a Kubernetes cluster based on your requirements.

For development purpose, you can setup a Kubernetes cluster on your local computer by:

- [enabling Kubernetes shipped with Docker Desktop](https://docs.docker.com/desktop/kubernetes/)
- or [setting up minikube](https://minikube.sigs.k8s.io/docs/start/)

For production purpose, you can:

- bootstrap your own cluster by following this official document [Installing Kubernetes with deployment tools](https://kubernetes.io/docs/setup/production-environment/tools/).
- or provision a Kubernetes cluster from popular Cloud vendors:
  - [Amazon Elastic Kubernetes Service](https://aws.amazon.com/eks/)
  - [Microsfot Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes)
  - [IBM Cloud Kubernetes Service](https://www.ibm.com/ca-en/cloud/kubernetes-service)
  - [Google Cloud Kubernetes Engine](https://cloud.google.com/kubernetes-engine)

### 2. `kubectl` Tool

You need `kubectl` CLI tool installed on your local computer where you want to manage the Kubernetes cluster. Please follow appropriate steps from official documentation [Install Tools](https://kubernetes.io/docs/tasks/tools/).
<br /> <br />

## Preparations

This section assumes you already have a Kubernetes cluster setup and have `kubectl` tool installed.

### 1. Create Namespace and Service Account

Run:

```bash
kubectl apply -f common/zowe-ns.yaml && kubectl apply -f common/zowe-sa.yaml
```

Our default namespace is `zowe`, default service account name is `zowe-sa`. Please note that by default, `zowe-sa` service account has `automountServiceAccountToken` disabled for security purpose.

To verify this step, run:

```bash
kubectl get namespaces
```

and it should show a Namespace `zowe`;  

then run:

```bash
kubectl get serviceaccounts --namespace zowe
```

and it should show a ServiceAccount `zowe-sa`.

### 2. Create Persistent Volume Claim

Open [samples/workspace-pvc.yaml](samples/workspace-pvc.yaml), Double check `storageClassName` value (line 24) and replace `hostpath` to customize to your own value. You can run

```bash
kubectl get sc
```

to list all StorageClasses on your cluster. A sample output will look like this:

```bash
  NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
  standard (default)   k8s.io/example-hostpath    Delete          Immediate           false                  29m
```

Following the example above, your `storageClassName` line in `workspace-pvc.yaml` should be `storageClassName: standard`. Note that this is just an example, you should have a different storageClassName value based on your specific environment.

After making all necessary changes, run the following command to apply:

```bash
kubectl apply -f samples/workspace-pvc.yaml
```

To verify this step, run

```bash
kubectl get pvc --namespace zowe
```

and it should show a PersistentVolumeClaim `zowe-workspace-pvc`, and the `STATUS` should be `Bound`.

### 3. Create And Modify ConfigMaps and Secrets

On the z/OS you have, run `convert-for-k8s.sh` in your instance directory:

```bash
cd <instance-dir>
./bin/utils/convert-for-k8s.sh
```

This script should display a set of YAML with `zowe-config` ConfigMap, `zowe-certificates-cm` ConfigMap and `zowe-certificates-secret` Secret. The content should look similar to `samples/config-cm.yaml`, `samples/certificates-cm.yaml` and `samples/certificates-secret.yaml` but with real values.

Now, copy the whole output and save as a YAML file `configs.yaml` on your server that you have set up kubernetes, next run following command to apply configurations:

```bash
kubectl apply -f /path/to/your/configs.yaml
```

Upon success, you should see the following output: `configmap/zowe-config created`, `configmap/zowe-certificates-cm created`, and `secret/zowe-certificates-secret created`

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
  - `CATALOG_PORT` is `7552`,
  - `DISCOVERY_PORT` is `7553`,
  - `GATEWAY_PORT` is `7554`,
  - `ZWE_CACHING_SERVICE_PORT` is `7555`,
  - `JOBS_API_PORT` is `7558`,
  - `FILES_API_PORT` is `7559`,
  - `JES_EXPLORER_UI_PORT` is `7560`,
  - `MVS_EXPLORER_UI_PORT` is `7561`,
  - `USS_EXPLORER_UI_PORT` is `7562`,
  - `ZOWE_ZLUX_SERVER_HTTPS_PORT` is `7556`.
- `ZOWE_ZSS_SERVER_PORT` should be set to the port where your Zowe ZSS is running on `ZOWE_ZOS_HOST`.
- `APIML_GATEWAY_EXTERNAL_MAPPER` should be set to `https://${GATEWAY_HOST}:${GATEWAY_PORT}/zss/api/v1/certificate/x509/map`.
- `APIML_SECURITY_AUTHORIZATION_ENDPOINT_URL` should be set to `https://${GATEWAY_HOST}:${GATEWAY_PORT}/zss/api/v1/saf-auth`.
- `ZOWE_EXPLORER_FRAME_ANCESTORS` should be set to `${ZOWE_EXTERNAL_HOST}:*`
- `ZWE_CACHING_SERVICE_PERSISTENT` should NOT be set to `VSAM`. `redis` is suggested. Follow [Redis configuration](https://docs.zowe.org/stable/extend/extend-apiml/api-mediation-redis/#redis-configuration) documentation to customize other redis related variables. Leave the value to empty for debugging purpose.
- Must append and customize these 2 values:
  - `ZWED_agent_host=${ZOWE_ZOS_HOST}`
  - `ZWED_agent_https_port=${ZOWE_ZSS_SERVER_PORT}`

To verify this step, run:  

```bash
kubectl get configmaps --namespace zowe
```

and it should show two ConfigMaps `zowe-config` and `zowe-certificates-cm`.  
Run:

```bash
kubectl get secrets --namespace zowe
```

and it should show a Secret `zowe-certificates-secret`.

### 4. Expose Gateway and Discovery

This section is highly related to your Kubernetes cluster configuration. If you are not sure about these sections, please contact your Kubernetes administrator or us.

#### 4a. Create Service

You may choose between `LoadBalancer` or `NodePort` service depending on your kubenetes provider.  
The table below provides a guidance for you:
<a id="table"></a>
| Kubernetes provider       | Service (_preferred_)      | Additional setups required                                 |
| :------------------------ | :------------------------  | :--------------------------------------------------------- |
| minikube                  | NodePort                   | [Port Forward](#4b-port-forward-for-minikube-only)         |
| docker-desktop            | LoadBalancer               | none                                                       |
| bare-metal                | _NodePort_ or LoadBalancer | [Create Ingress](#4c-create-ingress-for-bare-metal-only)   |
| cloud-vendors             | LoadBalancer               | none                                                       |
| openshift                 | _LoadBalancer_ or NodePort | [Create Route](#4d-create-route-for-openshift-only)        |

__Note__: Complete current section "4a. Create Service section" first, then work on additional setups listed in the table above if necessary.

##### <ins>Expose gateway service</ins>

- If you choose `LoadBalancer` service, run:

    ```bash
    kubectl apply -f samples/gateway-service-lb.yaml
    ```

- If you choose `NodePort` services, 
  - First check `spec.ports[0].nodePort` as this will be the port to be exposed to external. The default gateway port is __not__ `7554` but `32554`. You can use `https://<your-k8s-node>:32554/` to access APIML Gateway.
  - Then run:

    ```bash
    kubectl apply -f samples/gateway-service-np.yaml 
    ```

Either way, upon success, you should see following output: `service/gateway-service created`

##### <ins>Expose discovery service</ins>

Exposing discovery service is mandatory when there is zowe component running on z/OS side (outside of kubernetes) and requries doing dynamic registration.  

If you choose to enable, simply run the following step:

- If using `LoadBalancer`, run:

  ```bash
  kubectl apply -f samples/discovery-service-lb.yaml
  ```

- If using `NodePort`, run:

  ```bash
  kubectl apply -f samples/discovery-service-np.yaml
  ```

However, if you choose not to expose discovery service, you must do one extra step before applying above command.  
Depending on `LoadBalancer` or `NodePort` used, in [discovery-service-lb.yaml](samples/discovery-service-lb.yaml) or [discovery-service-np.yaml](samples/discovery-service-np.yaml) (line 15), specify `ClusterIP` as type. Then apply discovery-service yaml file depending on what service you are using (see above).

Upon success, you shall see `service/discovery-service created`.

<br>
To verify above steps, run

```bash
kubectl get services --namespace zowe
```

and it should show services `gateway-service` and `discovery-service`.

Upon completion of this 4a. Create Service section, you would probably need to run additional setups. Refer to "Additional setups required" in the table. [Return to table](#table)  
If you don't need additional setups, you can skip 4b, 4c, 4d and jump directly to [Apply Zowe](#apply-zowe-core-components-workloads-and-start-zowe) section.

#### 4b. Port Forward (for minikube only)

Run following two commands to enable port-forward:

```bash
kubectl port-forward --address 0.0.0.0 --namespace zowe service/gateway-service 7554:7554 &
```

and

```bash
kubectl port-forward --address 0.0.0.0 --namespace zowe service/discovery-service 7553:7553 &
```

Note: Because kubectl port-forward is running in foreground, because we have more commands to run in next steps, so we need to run in background here.

Upon completion, next [apply zowe](#apply-zowe-core-components-workloads-and-start-zowe).

#### 4c. Create Ingress (for bare-metal only)

Before applying, here are a series of steps to do:
- Open files [samples/bare-metal/gateway-ingress.yaml](samples/bare-metal/gateway-ingress.yaml) and [samples/bare-metal/discovery-ingress.yaml](samples/bare-metal/discovery-ingress.yaml),
- Go to line 19 `spec.rules[0].host`,
- Uncomment line 19 and 20,
- Fill in the value of host on line 19,
- Comment out line 21
  
Then:

```bash
kubectl apply -f samples/bare-metal/gateway-ingress.yaml && kubectl apply -f samples/bare-metal/discovery-ingress.yaml
```

To verify this step,

- `kubectl get ingresses --namespace zowe` should show Ingresses `gateway-ingress` and `discovery-ingress`.

Upon completion, next [apply zowe](#apply-zowe-core-components-workloads-and-start-zowe).

#### 4d. Create Route (for OpenShift only)

If you are using OpenShift, usually you need to define `Route` instead of `Ingress`.

Open files [samples/openshift/gateway-route.yaml](samples/openshift/gateway-route.yaml) and [samples/openshift/discovery-route.yaml](samples/openshift/discovery-route.yaml), double check the value of `spec.port.targetPort` (line 18). Then run:

```bash
oc apply -f samples/openshift/gateway-route.yaml && oc apply -f samples/openshift/discovery-route.yaml
```

To verify this step, run:

```bash
oc get routes --namespace zowe
```

and it should show two Services `gateway` and `discovery`.
Upon completion, next [apply zowe](#apply-zowe-core-components-workloads-and-start-zowe).
<br /><br /><br />

## Apply Zowe Core Components Workloads and Start Zowe

Run:

```bash
kubectl apply -f workloads/
```

To verify this step, run:

```bash
kubectl get deployments --namespace zowe
```

It should show you a list of deployments including `explorer-jes`, `explorer-mvs`, `explorer-uss`, `files-api`, `jobs-api`, and etc. Wait for a bit as it takes time to bring each deployment up; time varies depending on your machine environment.  
Upon success, eventually each deployment should show `1/1` in `READY` column.  

Run:

```bash
kubectl get statefulsets --namespace zowe
```

should show you a StatefulSet `discovery` which `READY` column should be `1/1`.  

Run:

```bash
kubectl get cronjobs --namespace zowe
```

should show you a CronJob `cleanup-static-definitions` which `SUSPEND` should be `False`.
<br /><br /><br />

## Access Zowe

If you are using `LoadBalancer`, Zowe instance is accessible through port 7554: `https://\<ip-adress\>:7554`
<br /><br /><br />

## Import New Component

### 1. Build and Push Component Image

Component must create container image and the component image must follow Zowe Containerization Conformance to make sure it can be started within a Zowe cluster.

Zowe core components define component Dockerfiles and use Github Actions to build images. For example, `explorer-jes` component

- has Dockerfile defined at <https://github.com/zowe/explorer-jes/blob/master/container/Dockerfile>,
- and defines Github Actions workflow <https://github.com/zowe/explorer-jes/blob/master/.github/workflows/explorer-jes-images.yml> to build the image.

There are several shared Github Actions may help you build your own image:

- `zowe-actions/shared-actions/docker-prepare` will prepare required environment variables used by following steps.
- `zowe-actions/shared-actions/docker-build-local` can build docker image directory on Github Actions virtual machine. By default it will be `ubuntu-latest`. This action can be used to build image for `amd64` CPU architecture.
- `zowe-actions/shared-actions/docker-build-zlinux` can build docker image on a `Linux on Z` virtual machine. This is useful if you want to build image for `s390x` CPU architecture.
- `zowe-actions/shared-actions/docker-manifest` can collect all related images and define them as docker manifests. This is useful for end-user to automatically pull the correct image based on cluster node CPU architecture, and also pull images based on popular tags like `latest`, `latest-ubuntu`, etc.

Component image must be pushed to a container image registry.

### 2. Define `Deployment` Object

In order to start your component in Kubernetes, you need to define a `Deployment` object. To define `Deployment` for your component, you can copy from `samples/sample-deployment.yaml` and modify all occurrences of these variables:

- `<my-component-name>`: this is your component name. For example, `sample-node-api`.
- `<my-component-image>`: this is your component image described in the above [section](#build-and-push-component-image). For example, `zowe-docker-release.jfrog.io/ompzowe/sample-node-api:latest-ubuntu`.
- `<my-component-port>`: this is the port of your service. For example, `8080`.

Continue to customize the specification to fit in your component requirements:

- `spec.replicas`: adjust how many pods you wish to start for your component,
- `spec.template.spec.containers[0].resources`: adjust the memory and CPU resource required to start the container,
- `metadata.annotations`, `spec.template.spec.volumes` and `spec.template.spec.securityContext` etc.

### 3. Start Your Component

Once you defined your component `Deployment` object, you can run `kubectl apply -f /path/to/your/component-deployment.yaml` to apply it to Kubernetes cluster running Zowe. Now you can follow common Kubernetes practice to mange your component workload.
<br /><br /><br />

## Configuration, Operation

When Zowe workload running in Kubernetes cluster, it follows common Kubernetes operation recommendations.

### 1. Monitoring Zowe Workload Running In Kubernetes

There are many ways to monitor workload running in Kubernetes, Kubernetes Dashboard could be a quick choice. Please follow this [Deploy and Access the Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) instruction.

If you are using a development Kubernetes shipped with Docker Desktop, the dashboard is already installed and `kubernetes-dashboard` namespace is already configuration.

[Metrics Server](https://github.com/kubernetes-sigs/metrics-server) is also recommended and is required if you want to define [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/). Check if you have `metrics-server` `Service` in `kube-system` namespace with this command `kubectl get services --namespace kube-system`. If you don't have, you can follow this [Installation](https://github.com/kubernetes-sigs/metrics-server#installation) instruction to install.

### 2. Pause, Resume Or Remove Component

To temporarily stop a component, you can find the component `Deployment` and scale down to `0`. To use `jobs-api` as example, run this command:

```bash
kubectl scale -n zowe deployment jobs-api --replicas=0
```

Scaling the component back to 1 or more to re-enable the component.

If you want to permanently remove a component, you can delete the component `Deployment`. To use `jobs-api` as example, run this command:

```bash
kubectl delete -n zowe deployment jobs-api
```

### 3. `PodDisruptionBudget`

Zowe provides default `PodDisruptionBudget` which can help on providing high availability during upgrade. By default, Zowe defines `minAvailable` to be `1` for all deployments. This configuration is optional but recommended. To apply `PodDisruptionBudget`, run this command:

```
kubectl apply -f samples/pod-disruption-budget/
```

To verify this step, run:

```bash
kubectl get pdb --namespace zowe
```

should show you list of `PodDisruptionBudget` like this:

```
NAME               MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
api-catalog-pdb    1               N/A               0                     1d
app-server-pdb     1               N/A               0                     1d
caching-pdb        1               N/A               0                     1d
discovery-pdb      1               N/A               0                     1d
explorer-jes-pdb   1               N/A               0                     1d
explorer-mvs-pdb   1               N/A               0                     1d
explorer-uss-pdb   1               N/A               0                     1d
files-api-pdb      1               N/A               0                     1d
gateway-pdb        1               N/A               0                     1d
jobs-api-pdb       1               N/A               0                     1d
```

### 4. `HorizontalPodAutoscaler`

Zowe provides default `HorizontalPodAutoscaler` which can help on automatically scaling Zowe components based on resource usage. By default, each workload has minimal 1 replica and maximum 3 to 5 replicas based on CPU usage. This configuration is optional but recommended. `HorizontalPodAutoscaler` relies on Kubernetes [Metrics server](https://github.com/kubernetes-sigs/metrics-server) monitoring to provide metrics through the [Metrics API](https://github.com/kubernetes/metrics). To learn how to deploy the metrics-server, see the [metrics-server documentation](https://github.com/kubernetes-sigs/metrics-server#deployment). Please adjust the `HorizontalPodAutoscaler` definitions based on your cluster resources, then run this command to apply them to your cluster:

```
kubectl apply -f samples/horizontal-pod-autoscaler/
```

To verify this step, run:

```bash
kubectl get hpa --namespace zowe
```

should show you list of `HorizontalPodAutoscaler` like this:

```
NAME               REFERENCE                 TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
api-catalog-hpa    Deployment/api-catalog    60%/70%   1         3         1          20m
app-server-hpa     Deployment/app-server     2%/70%    1         5         1          9m59s
caching-hpa        Deployment/caching        7%/70%    1         3         1          9m59s
discovery-hpa      StatefulSet/discovery     34%/70%   1         3         1          8m15s
explorer-jes-hpa   Deployment/explorer-jes   10%/70%   1         3         1          9m59s
explorer-mvs-hpa   Deployment/explorer-mvs   10%/70%   1         3         1          9m59s
explorer-uss-hpa   Deployment/explorer-uss   10%/70%   1         3         1          9m59s
files-api-hpa      Deployment/files-api      8%/70%    1         3         1          9m59s
gateway-hpa        Deployment/gateway        20%/60%   1         5         1          9m59s
jobs-api-hpa       Deployment/jobs-api       8%/70%    1         3         1          9m59s
```

<br />

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
<br /><br />

## Launch Single Image On Local Computer Without Kubernetes

**NOTES,** this is for debugging purpose and it's not recommended for end-user.

### 1. Init `tmp` Folder

- Create `tmp` folder:

  ```bash
  mkdir -p tmp
  cd tmp
  ```

- Init with `zowe-launch-scripts` image:

  ```bash
  docker run -it --rm -v $(pwd):/home/zowe zowe-docker-snapshot.jfrog.io/ompzowe/zowe-launch-scripts:1.25.0-ubuntu.staging
  ```

- Create `tmp/instance/instance.env` with your desired content. This content you can modify from `samples/config-cm.yaml`.
- Create `tmp/keystore/` and `tmp/keystore/zowe-certificates.env` with your desired content.

### 2. Start Component Container

For example, starting `explorer-jes` with `bash`:

```bash
docker run -it --rm \
    -v $(pwd):/home/zowe \
    --entrypoint /bin/bash \
    zowe-docker-release.jfrog.io/ompzowe/explorer-jes:latest
```

Or try to start the component:

```bash
docker run -it --rm \
    -v $(pwd):/home/zowe \
    --entrypoint /bin/bash \
    zowe-docker-release.jfrog.io/ompzowe/explorer-jes:latest \
    -- /home/zowe/instance/bin/internal/run-zowe.sh
```
