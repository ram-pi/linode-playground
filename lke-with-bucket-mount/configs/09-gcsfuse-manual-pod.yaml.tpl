apiVersion: v1
kind: Pod
metadata:
  name: gcs-bucket-manual
  labels:
    app: gcs-bucket-manual
spec:
  containers:
    - name: gcsfuse
      image: ubuntu:22.04
      securityContext:
        privileged: true
        capabilities:
          add:
            - SYS_ADMIN
      command:
        - /bin/bash
        - -c
        - |
          set -eux
          apt-get update
          apt-get install -y ca-certificates curl gnupg lsb-release fuse

          install -m 0755 -d /etc/apt/keyrings
          curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg
          chmod a+r /etc/apt/keyrings/cloud.google.gpg

          echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt gcsfuse-jammy main" > /etc/apt/sources.list.d/gcsfuse.list
          apt-get update
          apt-get install -y gcsfuse

          mkdir -p /mnt/gcs-bucket
          # gcsfuse attaches the bucket at this path inside the container.
          gcsfuse --foreground --implicit-dirs --key-file /var/secrets/gcs/key.json "${GCS_BUCKET}" /mnt/gcs-bucket
      volumeMounts:
        - name: gcs-key
          mountPath: /var/secrets/gcs
          readOnly: true
        # Optional in this single-container demo; useful when sharing this path with other containers in the pod
        # and when you need Kubernetes mount options (for example mountPropagation) on the same directory.
        - name: gcs-bucket
          mountPath: /mnt/gcs-bucket
          mountPropagation: Bidirectional
        - name: dev-fuse
          mountPath: /dev/fuse
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 1Gi
  volumes:
    - name: gcs-key
      secret:
        secretName: gcs-sa-key
        defaultMode: 0400
    - name: gcs-bucket
      emptyDir: {}
    - name: dev-fuse
      hostPath:
        path: /dev/fuse
        type: CharDevice
