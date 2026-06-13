apiVersion: v1
kind: Service
metadata:
  name: litellm
  namespace: litellm-gateway
  annotations:
    service.beta.kubernetes.io/linode-loadbalancer-firewall-acl: |
      {
        "allowList": {
          "ipv4": ["${LAPTOP_CIDR}"]
        }
      }
    service.beta.kubernetes.io/linode-loadbalancer-tags: "distributed-inference,akamai-summit"
    service.beta.kubernetes.io/linode-loadbalancer-throttle: "20"
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  loadBalancerSourceRanges:
    - ${LAPTOP_CIDR}
  selector:
    app: litellm
  ports:
    - port: 80
      targetPort: 4000
      protocol: TCP
      name: http
