FROM docker:dind

RUN \
   apk update && \
   apk add bash curl && \
   mkdir -p /etc/docker && \
   echo '{"features": {"containerd-snapshotter": true}}' > /etc/docker/daemon.json

ENTRYPOINT ["dockerd"]
