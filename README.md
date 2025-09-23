# Open5GS Core Network

## Requirements

- Kubernetes (1.28 or newer)
- Helm v3
- OpenEBS Storage Class
- sriov-cni and sriov-network-device-plugin (to use sr-iov with multus)

## Getting Started

### Open5GS K8s Deployment with Helm

Clone the repository

```sh
cd ~
git clone https://git.rnp.br/openran/fase-1/testbed/sw/5gc/open5gs.git
cd open5gs
```

Install the core network with Helm

```sh
helm upgrade --install open5gs -n open5gs --create-namespace charts/open5gs -f ./charts/open5gs/values/values-cloud2.yaml
```

> **_NOTE_**: nodeSelector is `kubernetes.io/hostname: oran-cloud5`, change it if necessary.

The Open5GS GUI will be available at http://[open5gs-node-IP]:30999

- user: admin
- password: 1423


### Clean up

```sh
helm uninstall -n open5gs open5gs && kubectl delete ns open5gs
```

## FIXME

- SRSUE doesn't work with multiple TACs in AMF configuration;

## TODO

- Configure eUPF with Open5gs (not yet functional);