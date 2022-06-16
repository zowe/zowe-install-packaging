# Use Kustomization to setup Zowe cluster

[Kustomize](https://github.com/kubernetes-sigs/kustomize) is a standalone tool to customize Kubernetes objects through a [kustomization file](https://kubectl.docs.kubernetes.io/references/kustomize/glossary/#kustomization). Read [Declarative Management of Kubernetes Objects Using Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) for more details.

## Prepare zowe.yaml and keystore

### zowe.yaml

You can customize `zowe.yaml` from your z/OS instance and overwrite the `zowe.yaml` in this directory. Or you can update the `zowe.yaml` located in this directly. Please pay special attention on lines marked with `FIXME:`. Those are fields you must update for your environment.

### keystore

You can download keystore from your z/OS system where Zowe keystore is located and save to local `keystore/` directory. Please note these files should exist:

- `keystore.p12`: PKCS#12 format keystore file consists full chain of certificate with private key. This file MUST be transferred in binary mode and download to your local computer. DO NOT use `scp` to download p12 file since it always uses ascii mode will convert encoding.
- `trustore.p12`: PKCS#12 format truststore file consists all trusted certificate authorities. This file MUST be transferred in binary mode and download to your local computer. DO NOT use `scp` to download p12 file since it always uses ascii mode will convert encoding.
- `keystore.key`: Server certificate private key in PEM format. This file MUST be transferred in ascii mode and download to your local computer. You should be able to read the file content with regular file editor.
- `keystore.cer`: Server certificate in PEM format. This file MUST be transferred in ascii mode and download to your local computer. You should be able to read the file content with regular file editor.
- `keystore.ca`: Certificate authorities used to sign server certificate in PEM format. This file MUST be transferred in ascii mode and download to your local computer. You should be able to read the file content with regular file editor.

## Review your configuration

Read through `kustomization.yaml` file and make customization to your desired state. Add new patches if it's needed.

Run `kubectl kustomize ./` to review the generated Kubernetes manifest files.

## Apply and delete to your Zowe cluster

Run `kubectl apply -k ./` to apply and run `kubectl delete -k ./` to delete.
