apiVersion: v1
kind: PersistentVolume
metadata:
  name: linode-bucket-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ''
  claimRef:
    name: linode-bucket-pvc
    namespace: default
  mountOptions:
    - allow-delete
    - --memory-limit 1000
    - --dir-mode 0777
    - --file-mode 0666
  csi:
    driver: ru.yandex.s3.csi
    volumeHandle: linode-bucket-pv
    volumeAttributes:
      bucket: ${LINODE_BUCKET}
      mounter: geesefs
    nodeStageSecretRef:
      name: csi-s3-secret
      namespace: default
    nodePublishSecretRef:
      name: csi-s3-secret
      namespace: default
