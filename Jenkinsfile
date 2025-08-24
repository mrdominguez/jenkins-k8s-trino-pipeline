pipeline {
    agent {
        kubernetes {
            yamlFile 'dind-pod.yaml'
        }
    }
    parameters {
        choice(name: 'ARCH', choices: ['amd64', 'arm64', 'ppc64le'], description: 'Architecture')
        string(name: 'PACKAGE', defaultValue: 'trino-server-core', description: 'Server package (artifact id), for example: trino-server')
        string(name: 'IMAGE_NAME', defaultValue: 'trino', description: 'Image tag name')
        string(name: 'TRINO_VERSION', defaultValue: '476', description: 'Trino release version')
        booleanParam(name: 'MULTIARCH', defaultValue: false, description: 'Build multi-platform image (amd64 <> arm64), ignores ARCH')
    }
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub') 
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: '', url: 'https://github.com/mrdominguez/multiarch-trino-docker.git'
            }
        }
        stage('Build') {
            steps {
                container('docker') {
                    script {
                        def BUILD_CMD = "./build.sh -x -p ${params.PACKAGE} -r ${params.TRINO_VERSION}"
                        def TAG = params.TRINO_VERSION
                        def MULTIARCH = params.MULTIARCH
                        if (MULTIARCH) {
                            echo "MULTIARCH is enabled."
                            BUILD_CMD += " -m"
                        } else {
                            echo "MULTIARCH is disabled."
                            BUILD_CMD += " -a ${params.ARCH}"
                            TAG += "-${params.ARCH}"
                        }
                        sh """
                            # Docker Hub login
                            echo '${DOCKERHUB_CREDENTIALS_PSW}' | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin
                            # Enable multi-architecture support
                            docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                            # Execute build script
                            eval "${BUILD_CMD}"
                            docker image ls
                            # Tag image
                            docker tag ${params.IMAGE_NAME}:${TAG} $DOCKERHUB_CREDENTIALS_USR/${params.IMAGE_NAME}:${TAG}
                            # Push image
                            docker push ${DOCKERHUB_CREDENTIALS_USR}/${params.IMAGE_NAME}:${TAG}
                        """
                    }
                }
            }
        }
    }
}
