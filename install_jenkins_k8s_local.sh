#!/bin/bash
# https://github.com/mrdominguez/jenkins-k8s-trino-pipeline

PV_JENKINS=/mnt/vol/jenkins
sudo mkdir -p $PV_JENKINS || exit
HOSTNAME_SELECTOR=$(kubectl get nodes -o jsonpath='{.items[].metadata.labels.kubernetes\.io/hostname}')

helm repo add jenkins https://charts.jenkins.io

cat > localStorageClass.yaml << EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

cat > pvJenkins.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-jenkins
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: PV_JENKINS
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - HOSTNAME_SELECTOR
EOF

sed -i "s|PV_JENKINS|${PV_JENKINS}|;s|HOSTNAME_SELECTOR|${HOSTNAME_SELECTOR}|" pvJenkins.yaml

kubectl create -f localStorageClass.yaml
kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl create -f pvJenkins.yaml

helm install jenkins jenkins/jenkins -n jenkins --create-namespace
