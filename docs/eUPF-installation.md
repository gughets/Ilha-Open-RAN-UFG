# eUPF Installation

## Requirements

- k8s cluster;
- helm;
- XDP support;

## Getting Starting

### Helm Install (eUPF only)

```sh
helm upgrade --install eupf -n eupf --create-namespace charts/eupf -f charts/eupf/values-cloud2.yaml
```

### Helm Install (Open5GS + eUPF)

To install Open5GS 5G Core with integrated eUPF, run the following command:

```sh
helm upgrade --install open5gs -n open5gs --create-namespace charts/open5gs -f ./values/values-eupf.yaml
```

### Clean up

```
helm uninstall -n eupf eupf && kubectl delete ns eupf

# or 

helm uninstall -n open5gs open5gs && kubectl delete ns open5gs
```