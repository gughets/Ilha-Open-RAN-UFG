# Open5GS Core Network

## Requirements

- Kubernetes (tested with 1.28)
- Helm v3

## Getting Started

### Open5GS K8s Deployment

Clone the repository

```sh
cd ~
git clone https://git.rnp.br/openran/fase-1/testbed/sw/5gc/open5gs.git
cd open5gs
```

Install the core network with Helm

```sh
helm upgrade --install open5gs -n open5gs --create-namespace oci://registry-1.docker.io/gradiant/open5gs --version 2.2.6 -f ./configs/values-testbed.yaml
```

> **_NOTE_**: nodeSelector is `kubernetes.io/hostname: open5gslocal`, change it if necessary.

The Open5GS GUI will be available at http://[open5gs-node-IP]:30999

- user: admin
- password: 1423


## Clean up

```sh
helm uninstall -n open5gs open5gs && kubectl delete ns open5gs
```