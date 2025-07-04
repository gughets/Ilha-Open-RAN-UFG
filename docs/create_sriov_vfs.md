# Create Virtual Functions Interfaces (VFs) with SR-IOV

## Create and Configure VFs to 5GC:

### VFs:

- N2/AMF: interface between RAN and AMF/NGC
- N3/UPF: interface between RAN and UPF/NGU
- N6/UPF: interface between UPF and internet/DNN (not used)

```sh
## Configure envs
export IF_NAME=ens2f0
export MAX_RING_BUFFER_SIZE=4096
export MTU=9100
export NUM_VFS=5

## Create VFs
sudo ethtool -G $IF_NAME rx $MAX_RING_BUFFER_SIZE tx $MAX_RING_BUFFER_SIZE

sudo modprobe iavf
sudo sh -c "echo 0 > /sys/class/net/$IF_NAME/device/sriov_numvfs"
sudo sh -c "echo $NUM_VFS > /sys/class/net/$IF_NAME/device/sriov_numvfs"

# Set MTU for each VF
for (( i=0; i<$NUM_VFS; i++ )); do
    VF_IF="${IF_NAME}v$i"
    echo "Configuring $VF_IF"
    # Set MTU
    sudo ip link set dev "$VF_IF" mtu $MTU
done
```