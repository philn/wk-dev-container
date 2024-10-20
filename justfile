
tag := "wk-dev:f41"
default_registry := "ghcr.io/philn"
default_archive := "wk-dev-container.tar"

build:
  podman pull registry.fedoraproject.org/fedora-toolbox:41
  podman build -t {{tag}} --security-opt seccomp=unconfined .

push registry=default_registry:
  podman push {{tag}} {{registry}}/{{tag}}

pull registry=default_registry:
  podman pull {{registry}}/{{tag}}
  ./wk-bx -u --image {{registry}}
  podman image prune -a -f

export archive=default_archive: build
  podman save --format=oci-archive -o {{archive}} {{tag}}

import archive=default_archive:
  podman load < {{archive}}
