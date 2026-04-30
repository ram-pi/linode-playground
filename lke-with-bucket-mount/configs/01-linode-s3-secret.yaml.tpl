apiVersion: v1
kind: Secret
metadata:
  name: csi-s3-secret
  namespace: default
type: Opaque
stringData:
  accessKeyID: ${LINODE_ACCESS_KEY}
  secretAccessKey: ${LINODE_SECRET_KEY}
  # Must be a full URL, e.g. https://it-mil-1.linodeobjects.com
  endpoint: ${LINODE_ENDPOINT}
