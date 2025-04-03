# eUPF Installation

## Requirements

- k8s cluster;
- helm;
- XDP support;

## Getting Starting

### Helm Install

```sh
helm upgrade --install eupf -n eupf --create-namespace charts/eupf -f charts/eupf/values-cloud2.yaml
```


### Clean up

```
helm uninstall -n eupf eupf && kubectl delete ns eupf
```