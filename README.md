# jenkins-k8s-trino-pipeline
Pipeline to build Trino Docker image through Jenkins on Kubernetes.

![Alt text](jenkins-k8s-trino-pipeline.png?raw=true)

Build a multi-architecture Trino Docker image (amd64, arm64): https://github.com/mrdominguez/multiarch-trino-docker

Trino images are pushed to https://hub.docker.com/repository/docker/mrdom/trino/tags

## Install Jenkins Helm chart
```
core@core-10920x:~/jenkins-k8s-trino-pipeline$ ./install_jenkins_k8s_local.sh
"jenkins" has been added to your repositories
storageclass.storage.k8s.io/local-storage created
storageclass.storage.k8s.io/local-storage patched
persistentvolume/local-pv-jenkins created
NAME: jenkins
LAST DEPLOYED: Sat Aug 23 18:58:14 2025
NAMESPACE: jenkins
STATUS: deployed
REVISION: 1
NOTES:
1. Get your 'admin' user password by running:
  kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
2. Get the Jenkins URL to visit by running these commands in the same shell:
  echo http://127.0.0.1:8080
  kubectl --namespace jenkins port-forward svc/jenkins 8080:8080

3. Login with the password from step 1 and the username: admin
4. Configure security realm and authorization strategy
5. Use Jenkins Configuration as Code by specifying configScripts in your values.yaml file, see documentation: http://127.0.0.1:8080/configuration-as-code and examples: https://github.com/jenkinsci/configuration-as-code-plugin/tree/master/demos

For more information on running Jenkins on Kubernetes, visit:
https://cloud.google.com/solutions/jenkins-on-container-engine

For more information about Jenkins Configuration as Code, visit:
https://jenkins.io/projects/jcasc/


NOTE: Consider using a custom image with pre-installed plugins
```
After successful deployment:
```
core@core-10920x:~$ kubectl get all -n jenkins
NAME            READY   STATUS    RESTARTS   AGE
pod/jenkins-0   2/2     Running   0          17m

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
service/jenkins         ClusterIP   10.109.81.124   <none>        8080/TCP    17m
service/jenkins-agent   ClusterIP   10.103.254.24   <none>        50000/TCP   17m

NAME                       READY   AGE
statefulset.apps/jenkins   1/1     17m
```

## Build custom Docker-in-Docker (DinD) image
https://hub.docker.com/repository/docker/mrdom/docker/general
```
core@core-10920x:~/jenkins-k8s-trino-pipeline$ cat Dockerfile
FROM docker:dind

RUN \
   apk update && \
   apk add bash curl && \
   mkdir -p /etc/docker && \
   echo '{"features": {"containerd-snapshotter": true}}' > /etc/docker/daemon.json

ENTRYPOINT ["dockerd"]
```
```
core@core-10920x:~/jenkins-k8s-trino-pipeline$ docker build -t docker:dind .
[+] Building 9.4s (7/7) FINISHED                                                                                                                                    docker:default
 => [internal] load build definition from Dockerfile                                                                                                                          0.1s
 => => transferring dockerfile: 244B                                                                                                                                          0.0s
 => [internal] load metadata for docker.io/library/docker:dind                                                                                                                0.7s
 => [auth] library/docker:pull token for registry-1.docker.io                                                                                                                 0.0s
 => [internal] load .dockerignore                                                                                                                                             0.0s
 => => transferring context: 2B                                                                                                                                               0.0s
 => [1/2] FROM docker.io/library/docker:dind@sha256:c0872aae4791ff427e6eda52769afa04f17b5cf756f8267e0d52774c99d5c9de                                                          6.1s
 => => resolve docker.io/library/docker:dind@sha256:c0872aae4791ff427e6eda52769afa04f17b5cf756f8267e0d52774c99d5c9de                                                          0.0s
 => => sha256:acf2e2d09cedf21fa8f27bb0962674e33e159c744c152b248f1f7f43623ccd82 4.00kB / 4.00kB                                                                                0.0s
 ...
 => => extracting sha256:d2ae60b320044d4dddd57522c6c3ddcd806948664e3b77e4b4f3dfdbcbb154bb                                                                                     0.0s
 => [2/2] RUN    apk update &&    apk add bash curl &&    mkdir -p /etc/docker &&    echo '{"features": {"containerd-snapshotter": true}}' > /etc/docker/daemon.json          2.2s
 => exporting to image                                                                                                                                                        0.1s
 => => exporting layers                                                                                                                                                       0.1s
 => => writing image sha256:2a8b234fdb103d4598a25c376e3dae46c526278ace8de05adda833e2dac005f5                                                                                  0.0s
 => => naming to docker.io/library/docker:dind                                                                                                                                0.0s
```
```
core@core-10920x:~/jenkins-k8s-trino-pipeline$ docker images
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
docker       dind      2a8b234fdb10   13 seconds ago   413MB
```
The `dind` image is used as the container in the Jenkins Kubernetes agent pod defined by `dind-pod.yaml`.
```
core@core-10920x:~/jenkins-k8s-trino-pipeline$ cat dind-pod.yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: docker
    image: mrdom/docker:dind
    imagePullPolicy: Always
    #command:
    #- "dockerd"
    tty: true
    securityContext:
      privileged: true
```

## Create `Pipeline` in Jenkins
Jenkins > Create a job > Enter an item name: `trino`, Select an item type: `Pipeline` > OK

**Configure**

General > Description: `Build Trino Docker image`

Pipeline >

- Definition: `Pipeline script from SCM`
- SCM: `Git`
- Repository URL: `https://github.com/mrdominguez/jenkins-k8s-trino-pipeline`
- Credentials: `- none -`
- Branches to build > Branch Specifier: `main`
- Script Path: `Jenkinsfile`

## Add Docker Hub credentials

Manage Jenkins > Security > Credentials > System > Global credentials (unrestricted) > + Add Credentials

- Kind: `Username with password`
- Username: `<username>`
- Password: `<password>`
- ID: `dockerhub`

## Build Trino
Click on the `trino` pipeline > Build Now

Click on the running Build job > Console Output
