apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: lvs-vip-share-dr-vlan
  namespace: kube-system
  labels:
    app: lvs-vip-share-dr-vlan
spec:
  selector:
    matchLabels:
      app: lvs-vip-share-dr-vlan
  template:
    metadata:
      labels:
        app: lvs-vip-share-dr-vlan
    spec:
      hostNetwork: true
      hostPID: true
      tolerations:
        - operator: Exists
      containers:
        - name: lvs-vip-share-dr-vlan
          image: alpine:3.20
          securityContext:
            privileged: true
          command:
            - /bin/sh
            - -c
            - |
              set -e
              apk add --no-cache iproute2

              # Configure ARP suppression for LVS DR mode
              # This ensures the backend nodes do not respond to ARP requests for the VIP on their VLAN interfaces
              sysctl -w net.ipv4.conf.all.arp_ignore=1
              sysctl -w net.ipv4.conf.all.arp_announce=2
              sysctl -w net.ipv4.conf.lo.arp_ignore=1
              sysctl -w net.ipv4.conf.lo.arp_announce=2

              # Configure the VIP on the loopback interface (lo) so it accepts the DR packets
              echo "Adding VIP ${LVS_VIP}/32 to lo..."
              if ! ip -4 addr show dev lo | grep -q "${LVS_VIP}/32"; then
                ip addr add ${LVS_VIP}/32 dev lo
                echo "Successfully added VIP to lo."
              else
                echo "VIP ${LVS_VIP}/32 is already on lo."
              fi

              sleep infinity