apiVersion: v1
kind: Namespace
metadata:
  name: hello
  labels:
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/warn: privileged
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: hello
  namespace: hello
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: hello
  template:
    metadata:
      labels:
        app.kubernetes.io/name: hello
    spec:
      automountServiceAccountToken: false
      dnsPolicy: ClusterFirstWithHostNet
      hostNetwork: true
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: hello
          image: traefik/whoami:v1.11.0
          args:
            - --port=8080
            - --name=hello-from-lke-enterprise
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 2
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              cpu: 25m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 128Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Service
metadata:
  name: hello
  namespace: hello
  labels:
    external-dns: enabled
  annotations:
    external-dns.kubernetes.io/access: private
    external-dns.kubernetes.io/hostname: ${SERVICE_FQDN}
    external-dns.kubernetes.io/ttl: "60"
spec:
  type: NodePort
  externalTrafficPolicy: Local
  selector:
    app.kubernetes.io/name: hello
  ports:
    - name: http
      port: 80
      targetPort: http
      nodePort: ${NODE_PORT}
      protocol: TCP
