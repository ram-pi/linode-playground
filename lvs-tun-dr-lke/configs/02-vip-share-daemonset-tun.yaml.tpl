apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: lvs-vip-share
  namespace: kube-system
  labels:
    app: lvs-vip-share
spec:
  selector:
    matchLabels:
      app: lvs-vip-share
  template:
    metadata:
      labels:
        app: lvs-vip-share
    spec:
      hostNetwork: true
      hostPID: true
      tolerations:
        - operator: Exists
      containers:
        - name: lvs-vip-share
          image: alpine:3.20
          securityContext:
            privileged: true
          command:
            - /bin/sh
            - -c
            - |
              set -e
              apk add --no-cache iproute2 iptables

              # Ensure IPIP tunnel module is loaded for LVS TUN mode
              nsenter -t 1 -m -u -n -i modprobe ipip || true
              
              # Allow ipencap in iptables before Calico drops it
              iptables -I INPUT 1 -p ipencap -j ACCEPT || true
              
              # Set tunnel interfaces up and configure ARP suppression
              ip link set tunl0 up || true
              
              sysctl -w net.ipv4.conf.all.arp_ignore=1
              sysctl -w net.ipv4.conf.all.arp_announce=2
              sysctl -w net.ipv4.conf.lo.arp_ignore=1
              sysctl -w net.ipv4.conf.lo.arp_announce=2
              sysctl -w net.ipv4.conf.tunl0.arp_ignore=1 || true
              sysctl -w net.ipv4.conf.tunl0.arp_announce=2 || true

              # Configure the VIP on the loopback interface (lo) so it accepts the decapsulated packets
              # We avoid putting it on tunl0 because Calico manages tunl0 and might remove unknown IPs.
              echo "Adding VIP ${LVS_VIP}/32 to lo..."
              if ! ip -4 addr show dev lo | grep -q "${LVS_VIP}/32"; then
                ip addr add ${LVS_VIP}/32 dev lo
                echo "Successfully added VIP to lo."
              else
                echo "VIP ${LVS_VIP}/32 is already on lo."
              fi

              sleep infinity
