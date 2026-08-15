# POC Open5GS — Múltiplas UPFs, PFCP e Failover
![Experimento feito e validado no ambiente IlhaOpenRAN (assets/images/ArqTestes.png)
## 1. Objetivo

Este documento registra a configuração e os testes realizados no ambiente Open5GS em Kubernetes para utilização de duas UPFs:

- **UPF1** — UPF principal;
- **UPF2** — segunda UPF;
- **SMF** — configurado para conhecer as duas UPFs via PFCP;
- **DNN:** `oranbr`;
- **Pool de usuários:** `10.45.0.0/16`.

O objetivo dos testes foi validar:

1. associação PFCP entre o SMF e as duas UPFs;
2. conectividade da UE através da UPF;
3. identificação de qual UPF está transportando o tráfego;
4. perda de uma UPF;
5. recuperação da sessão/conectividade;
6. observação do tráfego GTP-U durante o processo;
7. preparação de captura para medir o tempo de interrupção.

---

## 2. Ambiente

### Open5GS

- Open5GS: `2.7.6`
- Imagem utilizada:

```yaml
registry: docker.io
repository: gradiant/open5gs
tag: "2.7.6"
```

### Kubernetes

Namespace:

```text
open5gs
```

Nós utilizados:

```text
sm-cerise
```

### Componentes principais

No teste final foram utilizados:

```text
SMF
UPF1
UPF2
AMF
AUSF
BSF
MongoDB
NRF
NSSF
PCF
SCP
UDM
UDR
WebUI
```

Em uma etapa inicial, somente SMF/UPFs estavam habilitados. Posteriormente o ambiente foi renderizado/aplicado com os demais componentes habilitados para o POC.

---

# 3. Configuração Helm

O chart utilizado foi:

```text
~/core/open5gs/charts/open5gs-poc
```

O arquivo de valores utilizado foi:

```text
values/ufg/values-ufg-poc.yaml
```

Renderização:

```bash
helm template open5gs . \
  -n open5gs \
  -f values/ufg/values-ufg-poc.yaml \
  > /tmp/open5gs-poc-rendered.yaml
```

---

# 4. Configuração do SMF

A configuração principal do SMF foi:

```yaml
smf:
  enabled: true

  updateStrategy:
    type: Recreate

  image:
    registry: docker.io
    repository: gradiant/open5gs
    tag: "2.7.6"

  config:
    upf:
      pfcp:
        hostnames:
          - open5gs-upf-pfcp
          - open5gs-upf2-pfcp

    pcrf:
      enabled: false

    dnsList:
      - 8.8.8.8
      - 8.8.4.4
      - 2001:4860:4860::8888
      - 2001:4860:4860::8844

    subnetList:
      - subnet: 10.45.0.0/16
        gateway: 10.45.0.1
        dnn: oranbr

    mtu: 1500

  nodeSelector:
    kubernetes.io/hostname: sm-cerise
```

O ponto fundamental é:

```yaml
hostnames:
  - open5gs-upf-pfcp
  - open5gs-upf2-pfcp
```

Isso faz o SMF gerar duas associações PFCP.

A configuração efetiva dentro do pod foi validada com:

```bash
kubectl exec -n open5gs deploy/open5gs-smf -- \
  sed -n '/^  pfcp:/,/^  gtpc:/p' \
  /opt/open5gs/etc/open5gs/smf.yaml
```

Resultado:

```yaml
pfcp:
  server:
  - dev: eth0
  client:
    upf:
    - address: open5gs-upf-pfcp
    - address: open5gs-upf2-pfcp
```

---

# 5. Template do SMF

O template utilizado foi:

```text
~/core/open5gs/charts/open5gs-smf/resources/config/smf.yaml
```

O template possui suporte a múltiplos PFCP hosts:

```yaml
client:
  upf:
  {{- if .Values.config.upf.pfcp.hostnames }}
  {{- range .Values.config.upf.pfcp.hostnames }}
  - address: {{ . }}
  {{- end }}
  {{- else }}
  - address: {{ default (printf "%s-upf-pfcp" $open5gsName) .Values.config.upf.pfcp.hostname }}
  {{- end }}
```

Foi necessário remover/reconstruir a dependência do chart para garantir que o template local contendo `hostnames` fosse utilizado.

Depois da atualização da dependência, o render passou a apresentar:

```yaml
client:
  upf:
  - address: open5gs-upf-pfcp
  - address: open5gs-upf2-pfcp
```

Validação:

```bash
grep -n -A15 -B5 'open5gs-upf2-pfcp' \
  /tmp/open5gs-poc-rendered.yaml
```

---

# 6. Configuração da UPF1

A configuração utilizada para a UPF1 foi:

```yaml
upf:
  enabled: true

  updateStrategy:
    type: Recreate

  image:
    registry: docker.io
    repository: gradiant/open5gs
    tag: "2.7.6"

  podSecurityContext:
    enabled: true
    fsGroup: 0

  containerSecurityContext:
    enabled: true
    runAsUser: 0
    privileged: true
    capabilities:
      add:
        - NET_ADMIN

  config:
    hostNetwork: false

    n3if:
      ipAddress: "10.62.101.56"

    upf:
      pfcp:
        dev: "eth0"
        advertise: "open5gs-upf-pfcp"

      gtpu:
        dev: "n3"

    subnetList:
      - subnet: 10.45.0.0/16
        gateway: 10.45.0.1
        dnn: oranbr
        dev: ogstun
        mask: 16
        createDev: true
        enableNAT: true

  nodeSelector:
    kubernetes.io/hostname: sm-cerise
```

Principais parâmetros:

```text
PFCP: eth0
GTP-U: n3
N3: 10.62.101.56
Pool: 10.45.0.0/16
Gateway: 10.45.0.1
DNN: oranbr
Interface de usuário: ogstun
NAT: habilitado
```

---

# 7. Configuração da UPF2

A UPF2 foi configurada separadamente com:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: open5gs-upf2
  namespace: open5gs
data:
  upf.yaml: |
    logger:
      file:
        path: /opt/open5gs/var/log/open5gs/upf.log

    global:

    upf:
      pfcp:
        server:
          - dev: eth0
            client:

      gtpu:
        server:
          - dev: n3
            advertise: 10.62.101.57

      session:
        - subnet: 10.45.0.0/16
          gateway: 10.45.0.1
          dnn: oranbr

      metrics:
        server:
          - dev: eth0
            port: 9090
```

A UPF2 utiliza:

```text
N3 advertise: 10.62.101.57
PFCP: eth0
GTP-U: n3
Pool: 10.45.0.0/16
Gateway: 10.45.0.1
DNN: oranbr
```

A configuração efetiva da UPF2 foi validada:

```bash
kubectl exec -n open5gs "$UPF2" -- \
  cat /opt/open5gs/etc/open5gs/upf.yaml
```

---

# 8. Problema encontrado na configuração inicial da UPF2

Durante a inicialização da UPF2 foi encontrado:

```text
[sock] ERROR: getaddrinfo(0:open5gs2-upf-pfcp:8805:0x0) failed (22:Invalid argument)
[pfcp] FATAL: ogs_pfcp_context_parse_config: Assertion `rv == OGS_OK' failed.
```

A causa estava na configuração gerada para o endereço PFCP anunciado.

Depois da correção, a UPF2 passou a escutar corretamente:

```bash
kubectl exec -n open5gs "$UPF2" -- ss -lunp | \
  grep -E '8805|2152'
```

Resultado:

```text
UNCONN 0 0 10.62.101.57:2152  0.0.0.0:* users:(("open5gs-upfd",pid=1,fd=8))
UNCONN 0 0 10.42.143.250:8805 0.0.0.0:* users:(("open5gs-upfd",pid=1,fd=7))
```

Portanto:

```text
UPF2 PFCP = 10.42.143.250:8805
UPF2 N3   = 10.62.101.57:2152
```

---

# 9. Serviços PFCP

Os serviços Kubernetes foram validados:

```bash
kubectl get endpoints -n open5gs | grep upf
```

Exemplo:

```text
open5gs-upf-gtpu    10.42.143.235:2152
open5gs-upf-pfcp    10.42.143.235:8805
open5gs-upf2-pfcp   10.42.143.250:8805
```

A resolução DNS a partir do SMF também foi validada:

```bash
kubectl exec -n open5gs deploy/open5gs-smf -- \
  getent hosts open5gs-upf-pfcp open5gs-upf2-pfcp
```

Resultado:

```text
10.43.25.154   open5gs-upf-pfcp.open5gs.svc.cluster.local
10.43.155.152  open5gs-upf2-pfcp.open5gs.svc.cluster.local
```

---

# 10. Associação PFCP

A associação da UPF2 foi confirmada nos logs:

```text
[smf] INFO: PFCP associated [10.43.155.152]:8805 [10.42.143.250]:8805
```

Na UPF2:

```text
[upf] INFO: PFCP associated [10.42.143.203]:8805
```

A UPF1 também apresentou associação:

```text
[smf] INFO: PFCP associated [10.43.25.154]:8805
```

Após a correção, o SMF ficou efetivamente configurado com as duas UPFs:

```yaml
client:
  upf:
  - address: open5gs-upf-pfcp
  - address: open5gs-upf2-pfcp
```

---

# 11. Verificação do Helm Release

Os valores efetivamente aplicados foram verificados com:

```bash
helm get values open5gs -n open5gs -a
```

E:

```bash
helm get values open5gs -n open5gs -a | \
  sed -n '/^smf:/,/^udm:/p' | \
  grep -A5 -B2 'hostnames'
```

Resultado:

```yaml
pfcp:
  hostname: ""
  hostnames:
    - open5gs-upf-pfcp
    - open5gs-upf2-pfcp
```

Isso confirmou que o Helm release estava utilizando os dois destinos PFCP.

---

# 12. Teste de conexão da UE

Após configurar a infraestrutura, a UE foi conectada à rede 5G.

O endereço atribuído à UE mudou entre sessões:

```text
10.45.0.2
10.45.0.3
10.45.0.4
...
```

Essa mudança foi observada após perda da sessão e nova conexão.

Isso é esperado no cenário testado, pois uma nova sessão pode receber outro endereço disponível no pool:

```text
10.45.0.0/16
```

Portanto, os testes de captura foram realizados preferencialmente utilizando:

```text
net 10.45.0.0/16
```

em vez de fixar um único IP de UE.

---

# 13. Identificação da UPF que estava transportando a sessão

Foi utilizado:

```bash
UPF1=$(kubectl get pod -n open5gs \
  -l app.kubernetes.io/name=upf \
  -o jsonpath='{.items[0].metadata.name}')

UPF2=$(kubectl get pod -n open5gs \
  -l app.kubernetes.io/name=upf2 \
  -o jsonpath='{.items[0].metadata.name}')
```

Depois:

```bash
kubectl logs -n open5gs "$UPF1" --since=10m | \
grep -iE 'session|PFCP|Create|Modification|Deletion|TEID'
```

Foi observado:

```text
[upf] INFO: [Added] Number of UPF-Sessions is now 1
```

Enquanto na UPF2 não havia sessão naquele momento.

Isso confirmou que o tráfego da UE estava inicialmente passando pela UPF1.

---

# 14. Validação através de tcpdump

Para observar o tráfego da UE:

```bash
kubectl exec -n open5gs "$UPF1" -- \
  tcpdump -tttt -ni any -nn 'net 10.45.0.0/16'
```

Foi observado tráfego como:

```text
10.45.0.4:39590 > 35.186.225.240:443
35.186.225.240:443 > 10.45.0.4:39590
10.45.0.4 > 8.8.8.8:443
8.8.8.8:443 > 10.45.0.4
```

Também foi observado GTP-U:

```text
10.62.101.56.2152 > 10.62.101.20.2152
```

Isso demonstrou o tráfego entre a UPF e o gNB através da interface N3.

---

# 15. Teste de failover

Foi realizado o teste de perda das UPFs através da remoção dos pods:

```bash
kubectl delete pod -n open5gs "$UPF1"
```

e:

```bash
kubectl delete pod -n open5gs "$UPF2"
```

Como as UPFs são gerenciadas por Deployments, o Kubernetes cria novos pods automaticamente.

Acompanhar a recuperação:

```bash
kubectl get pods -n open5gs -w
```

Exemplo de estado:

```text
open5gs-smf-...   1/1 Running
open5gs-upf-...   1/1 Running
open5gs-upf2-...  1/1 Running
```

---

# 16. Comportamento do SMF durante perda da UPF

Durante a interrupção da UPF2 foram observados:

```text
[smf] WARNING: Retry association with peer failed
[pfcp] WARNING: LOCAL No Reponse. Give up!
```

e:

```text
[pfcp] ERROR: invalid step[0] type[6]
[pfcp] ERROR: ogs_pfcp_xact_update_rx() failed
```

Isso demonstra que o SMF detectou a ausência de resposta PFCP e tentou novamente estabelecer a associação.

Posteriormente:

```text
[smf] INFO: PFCP associated
```

indicou a recuperação da associação.

---

# 17. Comportamento da UPF durante recuperação

Na UPF1 foi observado:

```text
[upf] INFO: pfcp_server() [10.42.143.235]:8805
```

e posteriormente:

```text
[upf] INFO: PFCP associated [10.42.143.203]:8805
```

Também foi observado:

```text
[upf] WARNING: PFCP[REQ] has already been associated
```

Esse evento ocorreu durante o processo de recuperação/reassociação PFCP.

---

# 18. Observação do tráfego externo

Durante a captura foi observado tráfego da UE para servidores externos, por exemplo:

```text
10.45.0.4:39590 > 35.186.225.240:443
35.186.225.240:443 > 10.45.0.4:39590
```

Também foram observados acessos UDP para DNS:

```text
10.45.0.4 > 8.8.8.8:443
8.8.8.8 > 10.45.0.4
```

Em outra captura foi identificado tráfego externo:

```text
201.7.184.123:443 > 10.45.0.8:41698
```

sendo encaminhado pela UPF através da interface `ogstun`.

---

# 19. GTP-U observado

A captura mostrou explicitamente:

```text
n3 Out IP 10.62.101.56.2152 > 10.62.101.20.2152: UDP
```

Isso representa o tráfego GTP-U entre:

```text
UPF1 N3 = 10.62.101.56
gNB      = 10.62.101.20
```

Portanto:

```text
Internet
    |
    v
UPF1
10.62.101.56
    |
    | GTP-U / UDP 2152
    v
10.62.101.20
    |
    v
UE
10.45.0.8
```

---

# 20. Problema com captura dentro do pod

Inicialmente foi utilizado:

```bash
kubectl exec -n open5gs "$UPF1" -- \
  tcpdump -ni any -nn -s 0 \
  -w /tmp/upf1-failover.pcap \
  'net 10.45.0.0/16'
```

A captura iniciou corretamente:

```text
tcpdump: listening on any, link-type LINUX_SLL2
```

Porém, quando o pod foi removido, o processo `tcpdump` também terminou:

```text
command terminated with exit code 137
```

Isso ocorre porque o `tcpdump` estava sendo executado dentro do container/pod que foi eliminado.

Além disso, um arquivo armazenado em `/tmp` do pod não deve ser utilizado como armazenamento persistente para esse tipo de teste.

---

# 21. Captura correta no nó Kubernetes

Para que o arquivo sobreviva à remoção da UPF, a captura deve ser executada diretamente no nó Kubernetes:

```bash
sudo tcpdump -ni any -nn -s 0 \
  -w ~/upf-failover.pcap \
  'udp port 2152'
```

O filtro:

```text
udp port 2152
```

captura o GTP-U.

Para restringir ao gNB:

```bash
sudo tcpdump -ni any -nn -s 0 \
  -w ~/upf-failover-gtpu.pcap \
  'udp port 2152 and host 10.62.101.20'
```

Essa abordagem permite:

1. iniciar a captura;
2. matar a UPF1;
3. aguardar a recuperação;
4. observar o tráfego da UPF2;
5. parar o tcpdump;
6. analisar o PCAP posteriormente.

---

# 22. Medição do tempo de indisponibilidade

O objetivo da medição é identificar:

```text
Último pacote antes da falha
             |
             v
        interrupção
             |
             v
Primeiro pacote após recuperação
```

O tempo de interrupção deve ser calculado como:

```text
tempo de recuperação =
timestamp do primeiro pacote após failover
-
timestamp do último pacote antes da falha
```

Para isso, o PCAP deve conter GTP-U (`UDP/2152`).

O PCAP analisado durante o teste anterior continha principalmente PFCP (`UDP/8805`) e, portanto, não era suficiente para calcular diretamente a interrupção do tráfego de usuário.

---

# 23. Análise PFCP x GTP-U

É importante diferenciar os dois tipos de tráfego:

### PFCP

```text
UDP/8805
```

Utilizado entre:

```text
SMF <-> UPF
```

para:

- Association;
- Session Establishment;
- Session Modification;
- Session Deletion;
- heartbeat/controle PFCP.

### GTP-U

```text
UDP/2152
```

Utilizado para transportar o tráfego de usuário:

```text
gNB <-> UPF
```

Portanto:

- logs PFCP mostram o **estado de controle**;
- GTP-U mostra o **tráfego efetivo da UE**.

Para medir indisponibilidade percebida pelo usuário, GTP-U é a evidência principal.

---

# 24. Comandos úteis para diagnóstico

## Pods

```bash
kubectl get pods -n open5gs -o wide
```

## UPFs

```bash
kubectl get pods -n open5gs -o wide | grep upf
```

## Endpoints

```bash
kubectl get endpoints -n open5gs | grep upf
```

## Configuração efetiva do SMF

```bash
kubectl exec -n open5gs deploy/open5gs-smf -- \
  sed -n '/^  pfcp:/,/^  gtpc:/p' \
  /opt/open5gs/etc/open5gs/smf.yaml
```

## Logs do SMF

```bash
kubectl logs -n open5gs deploy/open5gs-smf --since=10m | \
  grep -iE 'PFCP|associated|Retry association|No Reponse'
```

## Logs da UPF1

```bash
kubectl logs -n open5gs "$UPF1" --since=10m | \
  grep -iE 'PFCP|associate|session|error|fatal'
```

## Logs da UPF2

```bash
kubectl logs -n open5gs "$UPF2" --since=10m | \
  grep -iE 'PFCP|associate|session|error|fatal'
```

## Portas PFCP/GTP-U

```bash
kubectl exec -n open5gs "$UPF1" -- \
  ss -lunp | grep -E '8805|2152'
```

```bash
kubectl exec -n open5gs "$UPF2" -- \
  ss -lunp | grep -E '8805|2152'
```

---

# 25. Resultado dos testes

Até o ponto registrado neste documento, foi validado que:

- [x] SMF configurado para múltiplas UPFs;
- [x] `open5gs-upf-pfcp` configurado no SMF;
- [x] `open5gs-upf2-pfcp` configurado no SMF;
- [x] resolução DNS dos dois serviços PFCP;
- [x] endpoints Kubernetes das duas UPFs;
- [x] UPF1 escutando PFCP;
- [x] UPF2 escutando PFCP;
- [x] associação PFCP com UPF1;
- [x] associação PFCP com UPF2;
- [x] UE conectada à rede 5G;
- [x] tráfego da UE observado;
- [x] GTP-U observado na interface N3;
- [x] sessão da UE observada na UPF;
- [x] perda de UPF simulada através da remoção do pod;
- [x] recuperação automática do pod pelo Kubernetes;
- [x] tentativas de reassociação PFCP observadas;
- [x] recuperação da associação PFCP observada;
- [x] mudança de endereço da UE entre novas sessões observada;
- [x] captura PFCP realizada;
- [ ] medição final do tempo de indisponibilidade através de GTP-U ainda deve ser realizada com PCAP capturado no nó Kubernetes.

---

# 26. Próximo teste recomendado

Para obter a métrica final de failover:

### 1. Iniciar captura no nó

```bash
sudo tcpdump -ni any -nn -s 0 \
  -w ~/upf-failover-gtpu.pcap \
  'udp port 2152'
```

### 2. Manter tráfego contínuo da UE

Por exemplo, realizar tráfego HTTPS contínuo.

### 3. Identificar a UPF atual

```bash
kubectl get pods -n open5gs -o wide | grep upf
```

### 4. Remover a UPF ativa

```bash
kubectl delete pod -n open5gs "$UPF1"
```

### 5. Acompanhar o Kubernetes

```bash
kubectl get pods -n open5gs -w
```

### 6. Acompanhar o SMF

```bash
kubectl logs -n open5gs deploy/open5gs-smf -f | \
  grep -iE 'PFCP|associated|Retry|No Reponse'
```

### 7. Aguardar o retorno do tráfego

Quando o tráfego voltar, interromper:

```text
Ctrl+C
```

### 8. Analisar o PCAP

```bash
tcpdump -tttt -nn -r ~/upf-failover-gtpu.pcap \
  'udp port 2152'
```

A partir desses timestamps será possível determinar o **tempo de interrupção do tráfego de usuário durante o failover da UPF**.

---

# 27. Arquitetura final do POC

```text
                         +----------------+
                         |       UE       |
                         |   10.45.0.x    |
                         +-------+--------+
                                 |
                                 | 5G / GTP-U
                                 |
                         +-------v--------+
                         |      gNB       |
                         | 10.62.101.20   |
                         +-------+--------+
                                 |
                         +-------+-------+
                         |               |
                         |      N3       |
                         |               |
                +--------v--+       +---v---------+
                |   UPF1    |       |    UPF2     |
                | 10.62.101.56      | 10.62.101.57|
                | PFCP/eth0 |       | PFCP/eth0   |
                +-----+-----+       +------+------+
                      |                     |
                      | PFCP                | PFCP
                      |                     |
                      +----------+----------+
                                 |
                         +-------v--------+
                         |      SMF       |
                         |  10.42.143.203 |
                         +----------------+
```

O SMF mantém os dois destinos PFCP:

```text
open5gs-upf-pfcp
open5gs-upf2-pfcp
```

permitindo que o ambiente seja utilizado para os experimentos de múltiplas UPFs e recuperação após falha.

---

## Conclusão

O POC demonstrou a configuração de um ambiente Open5GS com duas UPFs, associação PFCP simultânea, estabelecimento de sessão de UE, transporte GTP-U e testes de perda/recuperação de UPF.

A principal métrica ainda pendente é o **tempo efetivo de interrupção do plano de usuário**, que deve ser obtido a partir de uma captura GTP-U realizada no nó Kubernetes, evitando executar o `tcpdump` dentro do pod que será posteriormente removido.
