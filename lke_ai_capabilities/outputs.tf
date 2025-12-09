locals {
  kubeconfig_string = base64decode(linode_lke_cluster.main.kubeconfig)
  kubeconfig        = yamldecode(local.kubeconfig_string)
  storage_uri_v1    = "s3://${linode_object_storage_object.model-v1.id}"
  storage_uri_v2    = "s3://${linode_object_storage_object.model-v2.id}"
}

output "lke_kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}

output "obj_addition_apl_helm" {
  value = <<-EOT
    obj:
      provider:
        type: linode
        linode:
          region: ${linode_object_storage_bucket.apl-gitea.region}
          accessKeyId: ${linode_object_storage_key.rw-models-access-key.access_key}
          secretAccessKey: ${linode_object_storage_key.rw-models-access-key.secret_key}
          buckets:
            cnpg: ${linode_object_storage_bucket.apl-cnpg.label}
            gitea: ${linode_object_storage_bucket.apl-gitea.label}
            harbor: ${linode_object_storage_bucket.apl-harbor.label}
            loki: ${linode_object_storage_bucket.apl-loki.label}

  EOT

  sensitive = true
}

output "kserve_inference_service_yaml" {
  value = <<-EOT
    apiVersion: v1
    kind: Secret
    metadata:
      name: object-storage-secret
      namespace: kserve-test
      annotations:
        # ---------------------------------------------------------
        # KServe Storage Annotations for Linode
        # ---------------------------------------------------------
        # Linode Endpoint format: [region].linodeobjects.com
        # Common Regions:
        #   Newark: us-east-1.linodeobjects.com
        #   Frankfurt: eu-central-1.linodeobjects.com
        #   Singapore: ap-south-1.linodeobjects.com
        serving.kserve.io/s3-endpoint: "${linode_object_storage_bucket.models.s3_endpoint}"

        # This must match the region prefix in your endpoint above
        serving.kserve.io/s3-region: "${linode_object_storage_bucket.models.cluster}"

        # Linode supports HTTPS, so keep this enabled
        serving.kserve.io/s3-usehttps: "1"

        # Optional: If you are using a private/custom Linode setup without valid SSL
        # serving.kserve.io/s3-verifyssl: "0"
    type: Opaque
    stringData:
      # Use your Linode Object Storage Access Key and Secret Key here
      AWS_ACCESS_KEY_ID: "${linode_object_storage_key.rw-models-access-key.access_key}"
      AWS_SECRET_ACCESS_KEY: "${linode_object_storage_key.rw-models-access-key.secret_key}"
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: kserve-inference-sa
      namespace: kserve-test
    secrets:
      - name: object-storage-secret
    ---
    apiVersion: "serving.kserve.io/v1beta1"
    kind: "InferenceService"
    metadata:
      name: "sentiment-analyzer-v1"
      namespace: kserve-test
      annotations:
        # ---------------------------------------------------------
        # BYPASS KNATIVE (Raw Deployment Mode)
        # This uses standard K8s Deployments + Services + Ingress
        # instead of Knative Serverless functions.
        # ---------------------------------------------------------
        serving.kserve.io/deploymentMode: "RawDeployment"
    spec:
      predictor:
        # References the ServiceAccount defined in the secret above
        serviceAccountName: kserve-inference-sa
        model:
          modelFormat:
            name: sklearn
          storageUri: "${local.storage_uri_v1}"
          resources:
            requests:
              cpu: "100m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
    ---
    apiVersion: "serving.kserve.io/v1beta1"
    kind: "InferenceService"
    metadata:
      name: "sentiment-analyzer-v2"
      namespace: kserve-test
      annotations:
        # ---------------------------------------------------------
        # BYPASS KNATIVE (Raw Deployment Mode)
        # This uses standard K8s Deployments + Services + Ingress
        # instead of Knative Serverless functions.
        # ---------------------------------------------------------
        serving.kserve.io/deploymentMode: "RawDeployment"
    spec:
      predictor:
        # References the ServiceAccount defined in the secret above
        serviceAccountName: kserve-inference-sa
        model:
          modelFormat:
            name: sklearn
          storageUri: "${local.storage_uri_v2}"
          resources:
            requests:
              cpu: "100m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
  EOT

  sensitive = true
}
