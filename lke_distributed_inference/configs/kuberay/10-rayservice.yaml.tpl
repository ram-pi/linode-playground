apiVersion: ray.io/v1
kind: RayService
metadata:
  name: llm-serve
  namespace: llm-inference
  labels:
    app.kubernetes.io/name: llm-serve
    app.kubernetes.io/part-of: distributed-inference-demo
spec:
  serviceUnhealthySecondThreshold: 300
  deploymentUnhealthySecondThreshold: 300
  serveConfigV2: |
    applications:
      - name: llm
        route_prefix: /
        import_path: ray.serve.llm:build_openai_app
        args:
          llm_configs:
            - model_loading_config:
                model_id: mistralai/Mistral-7B-Instruct-v0.2
              engine_kwargs:
                max_model_len: 4096
                gpu_memory_utilization: 0.88
                tensor_parallel_size: 1
                trust_remote_code: false
              deployment_config:
                autoscaling_config:
                  min_replicas: 1
                  max_replicas: 1
  rayClusterConfig:
    rayVersion: "2.52.0"
    headGroupSpec:
      serviceType: ClusterIP
      rayStartParams:
        dashboard-host: "0.0.0.0"
      template:
        metadata:
          labels:
            ray.io/node-type: head
        spec:
          containers:
            - name: ray-head
              image: rayproject/ray-llm:2.52.0-py311-cu128
              imagePullPolicy: IfNotPresent
              ports:
                - containerPort: 6379
                  name: gcs
                - containerPort: 8265
                  name: dashboard
                - containerPort: 8000
                  name: serve
              env:
                - name: HUGGING_FACE_HUB_TOKEN
                  valueFrom:
                    secretKeyRef:
                      name: hf-token
                      key: HF_TOKEN
              resources:
                requests:
                  cpu: "1"
                  memory: "4Gi"
                limits:
                  cpu: "2"
                  memory: "6Gi"
    workerGroupSpecs:
      - groupName: gpu-workers
        replicas: 1
        minReplicas: 1
        maxReplicas: 1
        rayStartParams: {}
        template:
          metadata:
            labels:
              ray.io/node-type: worker
          spec:
            nodeSelector:
              pool: gpu
            tolerations:
              - key: "nvidia.com/gpu"
                operator: "Exists"
                effect: "NoSchedule"
            containers:
              - name: ray-worker
                image: rayproject/ray-llm:2.52.0-py311-cu128
                imagePullPolicy: IfNotPresent
                env:
                  - name: HUGGING_FACE_HUB_TOKEN
                    valueFrom:
                      secretKeyRef:
                        name: hf-token
                        key: HF_TOKEN
                resources:
                  requests:
                    cpu: "4"
                    memory: "18Gi"
                    nvidia.com/gpu: "1"
                  limits:
                    cpu: "6"
                    memory: "24Gi"
                    nvidia.com/gpu: "1"
