# Template — apply with envsubst before kubectl apply:
#   envsubst < configs/02-frpc-configmap.yaml.tpl | kubectl apply -f -
#
# Required environment variables (all exported in MANUAL_DEPLOYMENT.md Step 1):
#   FRP_SERVER_ADDR  — plain VLAN IP of frps VM  (tofu output -raw frp_server_vlan_ip)
#   FRP_SERVER_PORT  — frp bind port              (default: 7000)
#   FRP_TOKEN        — shared auth token          (tofu output -raw frp_token)
#   FRP_REMOTE_PORT  — remote port on frps        (default: 8080)
apiVersion: v1
kind: ConfigMap
metadata:
  name: frpc-config
  namespace: frp
data:
  frpc.toml: |
    serverAddr = "${FRP_SERVER_ADDR}"
    serverPort = ${FRP_SERVER_PORT}

    auth.method = "token"
    auth.token  = "${FRP_TOKEN}"

    log.to    = "/dev/stdout"
    log.level = "info"

    [[proxies]]
    name       = "dummy-nginx"
    type       = "tcp"
    localIP    = "dummy-nginx.frp.svc.cluster.local"
    localPort  = 80
    remotePort = ${FRP_REMOTE_PORT}
