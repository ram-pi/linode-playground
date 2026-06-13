apiVersion: v1
kind: ConfigMap
metadata:
  name: llm-api-gateway-nginx
  namespace: llm-inference
data:
  nginx.conf: |
    events {}

    http {
      server {
        listen 8080;

        add_header X-Serving-Region '${SERVING_REGION}' always;
        add_header X-Serving-Cluster '${SERVING_CLUSTER}' always;

        # Keep expected API key in a variable to avoid fragile inline comparisons.
        set $expected_api_key '${INFERENCE_API_KEY}';

        location /healthz {
          return 200 'ok';
          add_header Content-Type text/plain;
        }

        location / {
          set $api_key_valid 0;

          if ($http_x_api_key = $expected_api_key) {
            set $api_key_valid 1;
          }

          if ($http_authorization = "Bearer ${INFERENCE_API_KEY}") {
            set $api_key_valid 1;
          }

          if ($api_key_valid != 1) {
            return 401;
          }

          # Use a variable for proxy_pass so NGINX resolves it at request time
          # (not at startup), allowing the gateway to start before the Ray serve
          # service is ready.
          set $ray_upstream "llm-serve-serve-svc.llm-inference.svc.cluster.local";
          resolver kube-dns.kube-system.svc.cluster.local valid=30s;

          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Serving-Region '${SERVING_REGION}';
          proxy_set_header X-Serving-Cluster '${SERVING_CLUSTER}';
          proxy_pass http://$ray_upstream:8000;
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-api-gateway
  namespace: llm-inference
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llm-api-gateway
  template:
    metadata:
      labels:
        app: llm-api-gateway
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
              name: http
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 15
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: nginx-config
          configMap:
            name: llm-api-gateway-nginx
---
apiVersion: v1
kind: Service
metadata:
  name: llm-api-gateway
  namespace: llm-inference
  annotations:
    service.beta.kubernetes.io/linode-loadbalancer-firewall-acl: |
      {
        "allowList": {
          "ipv4": [${REGIONAL_GATEWAY_FIREWALL_ALLOWLIST}]
        }
      }
    service.beta.kubernetes.io/linode-loadbalancer-tags: "distributed-inference,akamai-summit"
    service.beta.kubernetes.io/linode-loadbalancer-throttle: "20"
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  loadBalancerSourceRanges:
${REGIONAL_GATEWAY_SOURCE_RANGES}
  selector:
    app: llm-api-gateway
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
      name: http
